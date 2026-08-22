-- ============================================================
-- LimitChest — Supabase şeması
-- Çalıştırma: Supabase SQL Editor'a yapıştırın ve çalıştırın.
-- ============================================================

-- ------------------------------------------------------------
-- 1) profiles: auth.users ile birebir eşlenen genişletilmiş tablo
--    Kayıt anında trigger ile otomatik doldurulur.
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'user',          -- 'user' | 'admin'
  -- Deneme ve abonelik durumu
  plan text not null default 'trial',         -- 'trial' | 'active' | 'expired' | 'none'
  trial_started_at timestamptz default now(),
  trial_ends_at timestamptz default (now() + interval '3 days'),
  subscription_ends_at timestamptz,           -- ödeme onaylandığında dolar
  payment_status text not null default 'unpaid', -- 'unpaid' | 'pending' | 'paid'
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Otomatik updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 2) Yeni kullanıcı kaydolunca profile otomatik oluştur
--    Admin e-postası otomatik role='admin' alır.
-- ------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, email, display_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    case when new.email = 'ilter9047@gmail.com' then 'admin' else 'user' end
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_new_user on auth.users;
create trigger trg_new_user
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------
-- 3) support_tickets: kullanıcıların açtığı destek talepleri
-- ------------------------------------------------------------
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  category text not null default 'genel', -- genel | fatura | teknik | hesap | diger
  message text not null,
  status text not null default 'open',     -- 'open' | 'answered' | 'closed'
  admin_reply text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

drop trigger if exists trg_tickets_updated on public.support_tickets;
create trigger trg_tickets_updated
  before update on public.support_tickets
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------
-- 4) community_posts: topluluk yorumları (herkes yazabilir)
--    badge_label: gönderi oluşturulurken tetikleyici ile damgalanır
--    (RLS yüzünden diğer kullanıcıların profili okunamadığı için
--     abone etiketi gönderiye yazılır)
-- ------------------------------------------------------------
create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  author_name text,
  body text not null,
  badge_label text,
  created_at timestamptz default now()
);

-- Abone/deneme kullanıcısına 'X gündür kullanıyor' etiketi damgala
create or replace function public.stamp_post_badge()
returns trigger as $$
declare p record;
begin
  if new.user_id is not null then
    select * into p from public.profiles where id = new.user_id;
    if found and p.plan in ('trial','active') then
      new.badge_label := '✦ LimitChest kullanıcısı · ' ||
        greatest(0, floor(
          extract(epoch from (now() - coalesce(p.trial_started_at, p.created_at))) / 86400
        ))::int || ' gündür kullanıyor';
    end if;
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_post_badge on public.community_posts;
create trigger trg_post_badge
  before insert on public.community_posts
  for each row execute function public.stamp_post_badge();

-- ------------------------------------------------------------
-- 5) payment_notifications: kullanıcı 'ödeme yaptım' dediğinde
-- ------------------------------------------------------------
create table if not exists public.payment_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  amount numeric not null default 500,
  note text,
  status text not null default 'pending',   -- 'pending' | 'approved' | 'rejected'
  created_at timestamptz default now()
);

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================
alter table public.profiles enable row level security;
alter table public.support_tickets enable row level security;
alter table public.community_posts enable row level security;
alter table public.payment_notifications enable row level security;

-- profiles: kullanıcı kendi profilini görür; admin hepsini
create policy "profiles_select_self_or_admin"
  on public.profiles for select
  using (auth.uid() = id or public.is_admin());

create policy "profiles_update_self"
  on public.profiles for update
  using (auth.uid() = id);

-- support_tickets: sahibi görür/yazar; admin hepsini
create policy "tickets_select_self_or_admin"
  on public.support_tickets for select
  using (auth.uid() = user_id or public.is_admin());

create policy "tickets_insert_self"
  on public.support_tickets for insert
  with check (auth.uid() = user_id);

create policy "tickets_update_admin"
  on public.support_tickets for update
  using (public.is_admin());

-- community_posts: herkes okur; girişli kullanıcı yazar
create policy "posts_select_all"
  on public.community_posts for select using (true);

create policy "posts_insert_auth"
  on public.community_posts for insert
  with check (auth.uid() is not null);

-- payment_notifications: sahibi görür; admin hepsini
create policy "pay_select_self_or_admin"
  on public.payment_notifications for select
  using (auth.uid() = user_id or public.is_admin());

create policy "pay_insert_self"
  on public.payment_notifications for insert
  with check (auth.uid() = user_id);

create policy "pay_update_admin"
  on public.payment_notifications for update
  using (public.is_admin());

-- ============================================================
-- Yardımcı: mevcut kullanıcı admin mi?
-- ============================================================
create or replace function public.is_admin()
returns boolean as $$
begin
  return exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
end;
$$ language plpgsql security definer;
