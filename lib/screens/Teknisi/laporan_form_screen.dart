import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void dispose() {
    // Dispose semua controller untuk menghindari memory leak.
    _judulController.dispose();
    _deskripsiController.dispose();
    _lokasiController.dispose();
    super.dispose();
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

      // Updated Supabase insert without execute()
      await Supabase.instance.client.from('reports').insert({
        'judul_pekerjaan': _judulController.text.trim(),
        'lokasi_pekerjaan': _lokasiController.text.trim(),
        'deskripsi': _deskripsiController.text.trim(),
        'tanggal_pekerjaan': _selectedDate.toIso8601String(),
        'status': 'tertunda',
        'teknisi_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

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
              const SizedBox(height: 24),

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
