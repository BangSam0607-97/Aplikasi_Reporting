# Panduan: Penyimpanan Foto Laporan (Dua Pendekatan)

Aplikasi kini mendukung **dua pendekatan** untuk menyimpan foto laporan. Anda bisa memilih salah satu atau switch antar keduanya sesuai kebutuhan.

---

## Pendekatan 1: Simple (foto_urls JSONB)

**File SQL:** `sql/add_foto_urls_jsonb.sql`

### Deskripsi
Menyimpan array URL foto langsung di kolom `foto_urls` (jsonb) pada tabel `reports`.

### Keuntungan
- ✅ Sederhana dan cepat
- ✅ Tidak perlu join saat query laporan
- ✅ Cocok untuk laporan dengan jumlah foto terbatas (misal ≤20 foto)

### Kerugian
- ❌ Sulit query individual foto
- ❌ Duplikasi data jika foto di-reuse antar laporan
- ❌ Tidak normalized

### Setup
1. Jalankan SQL di Supabase SQL Editor:
   ```sql
   -- Buka sql/add_foto_urls_jsonb.sql dan copy-paste ke SQL Editor
   ```
2. Di Flutter, pastikan konstanta di `laporan_form_screen.dart` set ke:
   ```dart
   static const bool _useReportPhotosTable = false;
   ```
3. Build & run

### Query Contoh (SQL)
```sql
-- Ambil semua laporan dengan foto
SELECT id, judul_pekerjaan, foto_urls FROM reports WHERE foto_urls IS NOT NULL;

-- Cek jumlah foto per laporan (menggunakan jsonb_array_length)
SELECT id, judul_pekerjaan, jsonb_array_length(foto_urls) as foto_count FROM reports;
```

---

## Pendekatan 2: Normalized (report_photos Table)

**File SQL:** `sql/create_report_photos_table.sql`

### Deskripsi
Setiap foto disimpan sebagai row terpisah di tabel `report_photos`, yang meref ke `reports` via foreign key. Tabel ini include RLS policies dan view `reports_with_photo_count` untuk kemudahan query.

### Keuntungan
- ✅ Database normalized (proper relationships)
- ✅ Mudah query individual foto dan metadata per-foto
- ✅ Reusable struktur (bisa extend dengan date, size, etc)
- ✅ Scalable untuk laporan dengan banyak foto
- ✅ RLS policies built-in untuk security

### Kerugian
- ❌ Perlu join/aggregasi saat query semua foto per laporan
- ❌ Sedikit lebih complex
- ❌ Query pemula mungkin lebih rumit

### Setup
1. Jalankan SQL di Supabase SQL Editor:
   ```sql
   -- Buka sql/create_report_photos_table.sql dan copy-paste ke SQL Editor
   ```
2. Di Flutter, pastikan konstanta di `laporan_form_screen.dart` set ke:
   ```dart
   static const bool _useReportPhotosTable = true;
   ```
3. Build & run

### Query Contoh (SQL)
```sql
-- Ambil laporan dengan foto count (gunakan view)
SELECT id, judul_pekerjaan, photo_count, photo_urls FROM reports_with_photo_count;

-- Ambil foto spesifik
SELECT * FROM report_photos WHERE report_id = '<report-id>';

-- Delete foto spesifik (cascade akan handle)
DELETE FROM report_photos WHERE id = '<photo-id>';

-- Add metadata ke foto (misal: updated_at)
-- (Struktur sudah ada, tinggal query/update)
```

---

## Bagaimana Cara Pilih?

| Aspek | Simple (foto_urls) | Normalized (report_photos) |
|-------|------------------|--------------------------|
| Kompleksitas setup | ⭐ Mudah | ⭐⭐⭐ Lebih rumit |
| Query foto individual | ❌ Sulit | ✅ Mudah |
| Skalabilitas | ⭐⭐ Baik untuk <50 foto/laporan | ⭐⭐⭐ Baik untuk unlimited |
| JOIN complexity | ❌ Tidak perlu (faster for simple reads) | ✅ Perlu JOIN (slower, lebih powerful) |
| Best use case | MVP, jumlah foto terbatas | Production, analytics, detail foto |

**Rekomendasi:**
- **Mulai dengan Simple** jika baru develop dan ingin MVP cepat.
- **Switch ke Normalized** jika perlu tracking detail foto, analytics, atau laporan dengan banyak foto.

---

## Cara Switch Antar Pendekatan

### Dari Simple ke Normalized
1. Buat tabel baru dengan `create_report_photos_table.sql`
2. Ubah konstanta di Flutter:
   ```dart
   static const bool _useReportPhotosTable = true;
   ```
3. (Optional) Migrate data lama dengan script:
   ```sql
   INSERT INTO report_photos (report_id, photo_url, file_path)
   SELECT id, jsonb_array_elements_text(foto_urls), 'unknown'
   FROM reports
   WHERE foto_urls IS NOT NULL;
   ```
4. Rebuild & test
5. (Optional) Cleanup tua kolom `foto_urls` jika tidak perlu

### Dari Normalized ke Simple
1. Ubah konstanta di Flutter:
   ```dart
   static const bool _useReportPhotosTable = false;
   ```
2. (Optional) Migrate data dengan aggregasi:
   ```sql
   UPDATE reports
   SET foto_urls = (
     SELECT jsonb_agg(photo_url)
     FROM report_photos
     WHERE report_id = reports.id
   )
   WHERE EXISTS (
     SELECT 1 FROM report_photos WHERE report_id = reports.id
   );
   ```
3. (Optional) Drop tabel jika tidak perlu: `DROP TABLE report_photos;`
4. Rebuild & test

---

## Testing

### Dengan Simple Approach
```dart
// Buka laporan form, pilih beberapa foto, submit
// Periksa di Supabase: SELECT * FROM reports;
// Kolom foto_urls harus berisi array URL
```

### Dengan Normalized Approach
```dart
// Buka laporan form, pilih beberapa foto, submit
// Periksa di Supabase:
//   SELECT * FROM reports;  (report_id diisi)
//   SELECT * FROM report_photos;  (rows foto terpisah)
//   SELECT * FROM reports_with_photo_count;  (view aggregasi)
```

---

## Troubleshooting

**Q: Insert gagal dengan "column foto_urls does not exist"**
- A: Jalankan `add_foto_urls_jsonb.sql` dulu jika pakai Simple approach.

**Q: Insert ke report_photos gagal dengan "table report_photos does not exist"**
- A: Jalankan `create_report_photos_table.sql` dulu jika pakai Normalized.

**Q: RLS policy error pada insert**
- A: Pastikan user terautentikasi dan user ID matching. Cek `auth.uid()` dan permission di policies.

**Q: getPublicUrl() returns null**
- A: Pastikan bucket `reports` publik atau set permission agar files accessible. Check bucket policies di Supabase.

---

## Next Steps

- [ ] Pilih satu pendekatan dan jalankan SQL yang sesuai
- [ ] Update konstanta `_useReportPhotosTable` di Flutter
- [ ] Test upload foto end-to-end (form → Supabase Storage → DB)
- [ ] (Optional) Buat UI untuk menampilkan foto (FotoGalleryScreen) yang query dari DB sesuai pendekatan
- [ ] Monitor RLS policies dan performance saat live

---

**Dibuat:** 16 Nov 2025  
**Status:** Ready to deploy (kedua SQL files siap, Flutter code mendukung kedua approach)
