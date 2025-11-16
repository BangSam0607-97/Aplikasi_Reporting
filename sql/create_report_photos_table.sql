-- SQL: Buat tabel report_photos untuk normalisasi foto laporan
-- Pendekatan advanced: simpan setiap foto sebagai row terpisah di tabel report_photos
-- Keuntungan: normalisasi database, mudah query per-foto, reusable storage structure
-- Kerugian: perlu join untuk membaca semua foto 1 laporan, sedikit lebih complex

BEGIN;

-- Create report_photos table
CREATE TABLE IF NOT EXISTS report_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  photo_url text NOT NULL,
  file_path text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now()
);

-- Add column comments (PostgreSQL syntax)
COMMENT ON COLUMN report_photos.file_path IS 'Path dalam Supabase Storage (bucket: reports)';
COMMENT ON COLUMN report_photos.photo_url IS 'Public URL untuk foto (dari Supabase Storage getPublicUrl)';
COMMENT ON COLUMN report_photos.report_id IS 'Foreign key reference ke tabel reports';

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_report_photos_report_id ON report_photos(report_id);
CREATE INDEX IF NOT EXISTS idx_report_photos_created_at ON report_photos(created_at);

-- Enable RLS if you want to secure access
ALTER TABLE report_photos ENABLE ROW LEVEL SECURITY;

-- Optional RLS Policy: Allow users to view photos of their own reports
-- (Simplified: only teknisi who created the report can view their photos)
CREATE POLICY "Users can view photos of their reports" ON report_photos
  FOR SELECT
  USING (
    report_id IN (
      SELECT id FROM reports WHERE teknisi_id = auth.uid()
    )
  );

-- Optional RLS Policy: Allow users to insert photos for their reports
CREATE POLICY "Users can insert photos for their reports" ON report_photos
  FOR INSERT
  WITH CHECK (
    report_id IN (
      SELECT id FROM reports WHERE teknisi_id = auth.uid()
    )
  );

-- Optional RLS Policy: Allow users to delete their own photos
CREATE POLICY "Users can delete their own photos" ON report_photos
  FOR DELETE
  USING (
    report_id IN (
      SELECT id FROM reports WHERE teknisi_id = auth.uid()
    )
  );

-- Create a view to easily get reports with photo counts
CREATE OR REPLACE VIEW reports_with_photo_count AS
SELECT
  r.id,
  r.judul_pekerjaan,
  r.lokasi_pekerjaan,
  r.deskripsi,
  r.tanggal_pekerjaan,
  r.status,
  r.teknisi_id,
  r.created_at,
  r.updated_at,
  COALESCE(COUNT(rp.id), 0) AS photo_count,
  ARRAY_AGG(rp.photo_url) FILTER (WHERE rp.id IS NOT NULL) AS photo_urls
FROM reports r
LEFT JOIN report_photos rp ON r.id = rp.report_id
GROUP BY r.id;

COMMIT;
