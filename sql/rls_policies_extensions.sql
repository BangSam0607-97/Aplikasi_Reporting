-- SQL: RLS Policy Extensions untuk report_photos
-- Gunakan script ini jika ingin menambah akses supervisor atau role lain

-- ============================================================================
-- POLICY EXTENSION: Supervisor Access (jika kolom supervisor_id ada di users)
-- ============================================================================
-- Jalankan HANYA jika tabel users memiliki kolom supervisor_id

-- CREATE POLICY "Supervisors can view their technician's photos" ON report_photos
--   FOR SELECT
--   USING (
--     report_id IN (
--       SELECT reports.id FROM reports
--       JOIN users ON reports.teknisi_id = users.id
--       WHERE users.supervisor_id = auth.uid()
--     )
--   );

-- ============================================================================
-- POLICY EXTENSION: Admin Access (allow admin to see all photos)
-- ============================================================================
-- Jalankan jika ada role 'admin' di users table

-- CREATE POLICY "Admins can view all photos" ON report_photos
--   FOR SELECT
--   USING (
--     EXISTS (
--       SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'
--     )
--   );

-- ============================================================================
-- POLICY EXTENSION: Public View (untuk sharing link public)
-- ============================================================================
-- Jalankan jika ingin foto bisa dilihat dengan shareable link (anonymous access)

-- CREATE POLICY "Public can view shared photos via share_token" ON report_photos
--   FOR SELECT
--   USING (
--     EXISTS (
--       SELECT 1 FROM report_shares 
--       WHERE report_id = report_photos.report_id 
--       AND share_token = current_setting('app.share_token')
--       AND expires_at > now()
--     )
--   );

-- ============================================================================
-- POLICY EXTENSION: Soft Delete (prevent DELETE, use status instead)
-- ============================================================================
-- Alternatif: daripada DELETE, ubah status menjadi 'deleted'

-- ALTER TABLE report_photos ADD COLUMN IF NOT EXISTS is_deleted boolean DEFAULT false;

-- DROP POLICY IF EXISTS "Users can delete their own photos" ON report_photos;

-- CREATE POLICY "Users can soft-delete their own photos" ON report_photos
--   FOR UPDATE
--   USING (
--     report_id IN (
--       SELECT id FROM reports WHERE teknisi_id = auth.uid()
--     )
--   )
--   WITH CHECK (
--     report_id IN (
--       SELECT id FROM reports WHERE teknisi_id = auth.uid()
--     )
--   );

-- ============================================================================
-- DEBUGGING: Check current policies
-- ============================================================================

-- SELECT tablename, policyname, qual, with_check 
-- FROM pg_policies 
-- WHERE tablename = 'report_photos';

-- ============================================================================
-- DEBUGGING: Check if RLS is enabled
-- ============================================================================

-- SELECT tablename, rowsecurity 
-- FROM pg_tables 
-- WHERE tablename = 'report_photos';

-- ============================================================================
-- NOTES
-- ============================================================================
-- 1. Policies dimulai dengan "CREATE POLICY" atau "ALTER POLICY"
-- 2. Urutan policy penting: policies evaluated dalam order yang dibuat
-- 3. auth.uid() returns current user's UUID (dari Supabase auth)
-- 4. Jika user_id tidak match, SELECT/INSERT/UPDATE/DELETE akan return 0 rows
-- 5. Supervisors: tambahkan kolom supervisor_id ke users table terlebih dahulu
-- 6. Admin role: pastikan tabel users punya kolom 'role' dengan nilai 'admin'/'teknisi'/'supervisor'
