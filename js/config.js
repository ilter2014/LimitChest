/* ============================================================
   LimitChest — Yapılandırma
   ⚠️ Buraya Supabase bilgilerinizi girin (Settings → API):
   ============================================================ */

const LIMITCHEST_CONFIG = {
  SUPABASE_URL:  'https://uvyaerffhnorwxzkcvup.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV2eWFlcmZmaG5vcnd4emtjdnVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODczOTk1NDksImV4cCI6MjEwMjk3NTU0OX0.Z-ohCaVn3qVxMTCXcefz37h7TeBDvTMEQGymxiyynfs',

  // Ürün ayarları
  TRIAL_DAYS: 3,
  PRICE_MONTHLY: 500,
  CURRENCY: 'TL',

  // IBAN bilgileri (ödeme sayfasında gösterilir)
  IBAN: {
    holder: 'LIMITCHEST YAZILIM',
    iban:   'TR00 0000 0000 0000 0000 0000 00', // ← gerçek IBAN'ı yazın
    bank:   'Banka Adı'
  },

  // İletişim / destek
  CONTACT_EMAIL: 'destek@limitchest.com'
};
