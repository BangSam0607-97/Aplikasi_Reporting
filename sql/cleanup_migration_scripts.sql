-- SQL: Cleanup / Rollback Scripts untuk Foto Storage
-- Gunakan hanya jika perlu revert atau migrate antar pendekatan

-- ============================================================================
-- CLEANUP SIMPLE APPROACH (foto_urls)
-- ============================================================================
-- Hapus kolom foto_urls dan index-nya jika tidak lagi digunakan
-- Jalankan HANYA jika sudah migrate ke report_photos atau tidak butuh foto sama sekali

-- BEGIN;
-- DROP INDEX IF EXISTS idx_reports_foto_urls;
-- ALTER TABLE reports DROP COLUMN IF EXISTS foto_urls;
-- COMMIT;

-- ============================================================================
-- CLEANUP NORMALIZED APPROACH (report_photos)
-- ============================================================================
-- Hapus tabel report_photos dan view-nya jika tidak lagi digunakan

-- BEGIN;
-- -- Drop policies first (RLS)
-- DROP POLICY IF EXISTS "Users can delete their own photos" ON report_photos;
-- DROP POLICY IF EXISTS "Users can insert photos for their reports" ON report_photos;
-- DROP POLICY IF EXISTS "Users can view photos of their reports" ON report_photos;
-- 
-- -- Drop view
-- DROP VIEW IF EXISTS reports_with_photo_count;
-- 
-- -- Drop table (cascade akan delete semua referenced rows)
-- DROP TABLE IF EXISTS report_photos;
-- COMMIT;

-- ============================================================================
-- MIGRATION: Simple → Normalized
-- ============================================================================
-- Pindahkan foto dari foto_urls (array) ke report_photos (rows)
-- 1. Pastikan report_photos table sudah ada (jalankan create_report_photos_table.sql)
-- 2. Jalankan script dibawah
-- 3. Update Flutter ke _useReportPhotosTable = true
-- 4. (Optional) Cleanup kolom foto_urls dengan script dibawah

-- BEGIN;
-- INSERT INTO report_photos (report_id, photo_url, file_path)
-- SELECT 
--   r.id,
--   jsonb_array_elements_text(r.foto_urls) as photo_url,
--   'migrated/' || r.id || '/' || md5(jsonb_array_elements_text(r.foto_urls)) as file_path
-- FROM reports r
-- WHERE r.foto_urls IS NOT NULL AND jsonb_array_length(r.foto_urls) > 0
-- ON CONFLICT DO NOTHING;
-- COMMIT;

-- ============================================================================
-- MIGRATION: Normalized → Simple
-- ============================================================================
-- Pindahkan foto dari report_photos (rows) ke foto_urls (array)
-- 1. Pastikan kolom foto_urls sudah ada (jalankan add_foto_urls_jsonb.sql)
-- 2. Jalankan script dibawah
-- 3. Update Flutter ke _useReportPhotosTable = false
-- 4. (Optional) Cleanup tabel report_photos dengan script dibawah

-- BEGIN;
-- UPDATE reports r
-- SET foto_urls = (
--   SELECT jsonb_agg(photo_url ORDER BY created_at)
--   FROM report_photos
--   WHERE report_id = r.id
-- )
-- WHERE EXISTS (
--   SELECT 1 FROM report_photos WHERE report_id = r.id
-- );
-- COMMIT;

-- ============================================================================
-- SAFETY CHECKS
-- ============================================================================
-- Jalankan untuk verifikasi struktur sebelum cleanup

-- Check jika kolom foto_urls ada
-- SELECT column_name FROM information_schema.columns 
-- WHERE table_name='reports' AND column_name='foto_urls';

-- Check jika tabel report_photos ada
-- SELECT table_name FROM information_schema.tables 
-- WHERE table_schema='public' AND table_name='report_photos';

-- Count foto di simple approach
-- SELECT COUNT(*), SUM(jsonb_array_length(foto_urls)) as total_fotos 
-- FROM reports WHERE foto_urls IS NOT NULL;

-- Count foto di normalized approach
-- SELECT COUNT(*) FROM report_photos;
