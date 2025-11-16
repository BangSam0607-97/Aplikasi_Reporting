import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data'; // jika belum di-import

class LaporanFormScreen extends StatefulWidget {
  /// LaporanFormScreen: form untuk membuat laporan pekerjaan baru oleh teknisi.
  ///
  /// Fields: judul, lokasi, tanggal, deskripsi. Saat submit akan menyimpan baris
  /// baru ke tabel `reports` dengan status 'tertunda' dan teknisi_id current user.
  const LaporanFormScreen({Key? key}) : super(key: key);

  @override
  State<LaporanFormScreen> createState() => _LaporanFormScreenState();
}

class _LaporanFormScreenState extends State<LaporanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  // Image picker state
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _pickedImages = [];

  /// Storage approach for photos:
  /// true = normalized (insert each photo as row in report_photos table)
  /// false = simple (store array of URLs in foto_urls jsonb column)
  /// Change this constant to switch approaches.
  static const bool _useReportPhotosTable = true;

  @override
  void dispose() {
    // Dispose semua controller untuk menghindari memory leak.
    _judulController.dispose();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked != null) {
        setState(() {
          if (_pickedImages.length < 6) _pickedImages.add(picked);
        });
      }
    } catch (e) {
      debugPrint('Pick gallery error: $e');
    }
  }

  Future<void> _captureFromCamera() async {
    try {
      final XFile? captured = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (captured != null) {
        setState(() {
          if (_pickedImages.length < 6) _pickedImages.add(captured);
        });
      }
    } catch (e) {
      debugPrint('Capture camera error: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  String? _validateField(String? value, String fieldName) {
    // Validasi sederhana untuk field form.
    // Input: value (String?) dan fieldName (untuk pesan error).
    // Output: null jika valid, String pesan error jika kosong.
    if (value == null || value.trim().isEmpty) {
      return 'Mohon isi $fieldName';
    }
    return null;
  }

  Future<void> _selectDate(BuildContext context) async {
    // Menampilkan date picker dan menyimpan tanggal yang dipilih di _selectedDate.
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    // Menangani submit form:
    // 1. Validasi form.
    // 2. Ambil current user id (harus login).
    // 3. Insert record ke tabel `reports` dengan fields dari form.
    // 4. Tampilkan SnackBar sukses atau error.
    // Error modes:
    // - User tidak terautentikasi: lempar Exception.
    // - PostgrestException: tampilkan pesan DB.
    // - Exception lain: tampilkan pesan generik.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User tidak terautentikasi');
      }

      // Upload photos to Supabase Storage (bucket: 'reports') and collect public URLs + file paths
      final List<String> fotoUrls = [];
      final List<Map<String, String>> fotoMetadata = [];
      if (_pickedImages.isNotEmpty) {
        for (final img in _pickedImages) {
          try {
            // Read bytes directly from XFile - works for mobile and web
            final fileBytes = await img.readAsBytes();
            if (fileBytes.isEmpty) continue;

            final fileName =
                '${DateTime.now().millisecondsSinceEpoch}_${img.name}';
            final storagePath = 'reports/$userId/$fileName';

            // Upload file bytes to Supabase Storage
            await Supabase.instance.client.storage
                .from('reports')
                .uploadBinary(storagePath, fileBytes);

            // Get public URL for the uploaded file. SDK return shape may vary.
            final dynamic publicUrlRes = Supabase.instance.client.storage
                .from('reports')
                .getPublicUrl(storagePath);
            String publicUrlStr = '';
            if (publicUrlRes is String) {
              publicUrlStr = publicUrlRes;
            } else if (publicUrlRes is Map &&
                publicUrlRes['publicUrl'] != null) {
              publicUrlStr = publicUrlRes['publicUrl'].toString();
            } else {
              publicUrlStr = (publicUrlRes?.toString() ?? '');
            }
            if (publicUrlStr.isNotEmpty) {
              fotoUrls.add(publicUrlStr);
              fotoMetadata.add({
                'photo_url': publicUrlStr,
                'file_path': storagePath,
              });
            }
          } catch (e) {
            debugPrint('Upload foto gagal: $e');
          }
        }
      }

      // Insert report row
      final Map<String, dynamic> insertPayload = {
        'judul_pekerjaan': _judulController.text.trim(),
        'lokasi_pekerjaan': _lokasiController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'tanggal_pekerjaan': _selectedDate.toIso8601String(),
        'status': 'tertunda',
        'teknisi_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Add foto_urls for simple approach
      if (!_useReportPhotosTable && fotoUrls.isNotEmpty) {
        insertPayload['foto_urls'] = fotoUrls;
      }

      final reportResponse = await Supabase.instance.client
          .from('reports')
          .insert(insertPayload)
          .select()
          .single();
      final reportId = reportResponse['id'] as String;

      // If using report_photos table, insert each photo separately
      if (_useReportPhotosTable && fotoMetadata.isNotEmpty) {
        for (final metadata in fotoMetadata) {
          try {
            await Supabase.instance.client.from('report_photos').insert({
              'report_id': reportId,
              'photo_url': metadata['photo_url'],
              'file_path': metadata['file_path'],
            });
          } catch (e) {
            debugPrint('Insert report_photos gagal: $e');
          }
        }
      }

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      // Tangani kesalahan PostgREST (constraint/db error) dan tampilkan pesan yang
      // jelas kepada pengguna.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database Error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Tangani error umum.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Membangun UI form laporan. Termasuk:
    // - Field input (judul, lokasi, tanggal, deskripsi)
    // - Validasi sederhana pada setiap field
    // - Tombol submit yang memanggil _submitForm
    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Laporan Baru'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: const InputDecoration(
                  labelText: 'Judul Pekerjaan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                validator: (value) => _validateField(value, 'judul pekerjaan'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _lokasiController,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Pekerjaan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) => _validateField(value, 'lokasi pekerjaan'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Pekerjaan',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat(
                          'dd MMMM yyyy',
                          'id_ID',
                        ).format(_selectedDate),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _deskripsiController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Pekerjaan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    _validateField(value, 'deskripsi pekerjaan'),
                textInputAction: TextInputAction.done,
              ),
              // Foto upload section
              const SizedBox(height: 16),
              const Text(
                'Foto (opsional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _captureFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_pickedImages.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pickedImages.length,
                    itemBuilder: (context, index) {
                      final img = _pickedImages[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: FutureBuilder<Uint8List>(
                                future: img
                                    .readAsBytes(), // XFile.readAsBytes() works on mobile & web
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError ||
                                      snapshot.data == null) {
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.broken_image),
                                    );
                                  }
                                  final bytes = snapshot.data!;
                                  return Image.memory(
                                    bytes,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  disabledBackgroundColor: Colors.blue.withOpacity(0.6),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isLoading ? 'Menyimpan...' : 'Simpan Laporan',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
