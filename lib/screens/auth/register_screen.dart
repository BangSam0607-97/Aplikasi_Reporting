import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  /// RegisterScreen: layar pendaftaran pengguna.
  ///
  /// Menyediakan form nama, email, password, dan pemilihan role (teknisi/supervisor).
  /// Setelah pendaftaran, akan memanggil RPC `create_user_profile` untuk membuat profil
  /// (nama, email, role) di database, lalu menampilkan notifikasi dan kembali ke layar login.
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _selectedRole = 'teknisi';
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    // Dispose controller untuk mencegah memory leak saat widget dibuang.
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    // Menangani alur pendaftaran pengguna menggunakan Supabase.
    // Input: field form (nama, email, password, role).
    // Langkah:
    // 1. Validasi form.
    // 2. Panggil Supabase.auth.signUp untuk membuat akun (email/password).
    // 3. Jika user dibuat, panggil RPC 'create_user_profile' untuk menyimpan profil tambahan
    //    (user_id, email, full_name, role) di database.
    // 4. Tampilkan SnackBar sukses dan kembali ke layar sebelumnya.
    // Penanganan error:
    // - AuthException: tampilkan pesan dari Supabase.
    // - Error lain: tampilkan pesan generik dan log ke konsol.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final name = _nameCtrl.text.trim();

      // Sign up
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cek email untuk verifikasi akun'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        return;
      }

      // Create profile via RPC
      await Supabase.instance.client.rpc(
        'create_user_profile',
        params: {
          'user_id': userId,
          'user_email': email,
          'user_full_name': name,
          'user_role': _selectedRole,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun berhasil dibuat! Silakan login.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      // Tangani kesalahan autentikasi (mis. email sudah terdaftar, password lemah)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auth error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // Log error untuk debugging lokal. Jangan ekspos detail sensitif ke user.
      print('Register error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Akun')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      (v?.trim().isEmpty ?? true) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  // Validator: cek kosong dan format sederhana (mengandung '@').
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Email wajib diisi';
                    if (!v!.contains('@')) return 'Email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 karakter)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  // Validator password: minimal 6 karakter.
                  validator: (v) {
                    if (v?.isEmpty ?? true) return 'Password wajib diisi';
                    if (v!.length < 6) return 'Minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Daftar Sebagai',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'teknisi', child: Text('Teknisi')),
                    DropdownMenuItem(
                      value: 'supervisor',
                      child: Text('Supervisor'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedRole = v ?? 'teknisi'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Daftar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
