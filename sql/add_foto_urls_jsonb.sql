-- SQL: Tambahkan kolom foto_urls (jsonb) ke tabel reports
-- Pendekatan sederhana: simpan array of public URLs langsung di row reports
-- Keuntungan: cepat, simple, tidak perlu join
-- Kerugian: sulit query per-foto, duplikasi data jika foto shared antar reports

BEGIN;

-- Add the foto_urls column if it doesn't exist
ALTER TABLE reports
ADD COLUMN IF NOT EXISTS foto_urls jsonb DEFAULT NULL;

-- Optional: Add a comment
COMMENT ON COLUMN reports.foto_urls IS 'Array of public URLs to photos stored in Supabase Storage (reports bucket)';

-- Optional: Add an index for better query performance
CREATE INDEX IF NOT EXISTS idx_reports_foto_urls ON reports USING gin (foto_urls);

COMMIT;
