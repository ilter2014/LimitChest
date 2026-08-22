/* ============================================================
   LimitChest — paylaşılan altyapı
   Supabase auth + navbar + reveal animasyonu
   Sayfalara eklenme sırası:
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="js/config.js"></script>
     <script src="js/app.js"></script>
   ============================================================ */

const sb = supabase.createClient(LIMITCHEST_CONFIG.SUPABASE_URL, LIMITCHEST_CONFIG.SUPABASE_ANON_KEY);

/* ---------- Auth yardımcıları ---------- */
let _session = null;
let _profile = null;

async function getSession() {
  if (_session) return _session;
  const { data } = await sb.auth.getSession();
  _session = data.session;
  return _session;
}

async function getProfile(force = false) {
  const s = await getSession();
  if (!s) return null;
  if (_profile && !force) return _profile;
  const { data } = await sb.from('profiles').select('*').eq('id', s.user.id).single();
  _profile = data;
  return data;
}

async function logout() {
  await sb.auth.signOut();
  location.href = 'index.html';
}

/* Deneme/abonelik hâlâ geçerli mi? */
function accessActive(profile) {
  if (!profile) return false;
  const now = Date.now();
  if (profile.subscription_ends_at && new Date(profile.subscription_ends_at) > now) return true;
  if (profile.trial_ends_at && new Date(profile.trial_ends_at) > now && profile.plan !== 'none') return true;
  return false;
}

/* Kalan gün sayısı (tamsayı, en az 0) */
function daysLeft(dateStr) {
  if (!dateStr) return 0;
  const ms = new Date(dateStr) - Date.now();
  return Math.max(0, Math.ceil(ms / 86400000));
}

/* Giriş zorunluluğu: oturum yoksa login'e yönlendir */
async function requireAuth() {
  const s = await getSession();
  if (!s) { location.href = 'login.html'; return null; }
  return s;
}

/* Admin değilse ana sayfaya yönlendir; admin ise profil döner */
async function requireAdmin() {
  const p = await getProfile(true);
  if (!p || p.role !== 'admin') { location.href = 'index.html'; return null; }
  return p;
}

/* Durum metni + CSS sınıfı (dashboard/admin ortak kullanır) */
function planStatus(profile) {
  if (!profile) return { text: 'Bilinmiyor', cls: 'status-expired' };
  if (profile.subscription_ends_at && new Date(profile.subscription_ends_at) > Date.now()) {
    return { text: `Abone · ${daysLeft(profile.subscription_ends_at)} gün kaldı`, cls: 'status-active' };
  }
  if (accessActive(profile)) {
    return { text: `Deneme · ${daysLeft(profile.trial_ends_at)} gün kaldı`, cls: 'status-trial' };
  }
  return { text: 'Süresi doldu', cls: 'status-expired' };
}

/* Kopyala düğmesi için yardımcı */
function copyText(txt, btn) {
  navigator.clipboard.writeText(txt).then(() => {
    const old = btn.textContent;
    btn.textContent = 'Kopyalandı ✓';
    setTimeout(() => btn.textContent = old, 1600);
  });
}

/* Türkçe tarih biçimi */
function fmtDate(d) {
  return d ? new Date(d).toLocaleString('tr-TR', { dateStyle: 'medium', timeStyle: 'short' }) : '—';
}

/* ---------- Navbar oturum alanı ---------- */
async function renderNavAuth() {
  const el = document.getElementById('nav-auth-area');
  if (!el) return;

  if (_session) {
    const p = await getProfile();
    const adminLink = (p && p.role === 'admin')
      ? '<a href="admin.html" style="color:var(--amber-dark); font-weight:700;">Admin</a>' : '';
    el.innerHTML = `${adminLink}
      <a href="dashboard.html" class="btn btn-primary btn-sm">Panelim</a>
      <button onclick="logout()" class="nav-logout">Çıkış</button>
    `;
  } else {
    el.innerHTML = `
      <a href="login.html" class="nav-link-login">Giriş</a>
      <a href="register.html" class="btn btn-primary btn-sm">Ücretsiz Dene</a>
    `;
  }
}

getSession().then(renderNavAuth);
sb.auth.onAuthStateChange((_e, s) => { _session = s; renderNavAuth(); });

/* ---------- Reveal animasyonu (data-delay) ---------- */
document.addEventListener('DOMContentLoaded', () => {
  // Mobil menü: linke tıklanınca menüyü kapat
  document.querySelectorAll('.nav-links a').forEach(a =>
    a.addEventListener('click', () => document.querySelector('.nav-links')?.classList.remove('open')));

  // Navbar scroll gölgesi
  const nav = document.querySelector('.navbar');
  window.addEventListener('scroll', () => {
    nav?.classList.toggle('scrolled', window.scrollY > 10);
  }, { passive: true });

  const els = document.querySelectorAll('[data-delay]');
  const obs = new IntersectionObserver((entries) => {
    entries.forEach(en => {
      if (en.isIntersecting) {
        setTimeout(() => en.target.classList.add('visible'),
          parseInt(en.target.dataset.delay || 0));
        obs.unobserve(en.target);
      }
    });
  }, { threshold: 0.12 });
  els.forEach(el => obs.observe(el));
});
