import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'laporan_form_screen.dart';
import '../auth/login_screen.dart';

class DashboardTeknisiScreen extends StatefulWidget {
  /// DashboardTeknisiScreen: tampilan utama untuk user dengan role Teknisi.
  ///
  /// Menampilkan ringkasan laporan milik teknisi (tertunda/diproses/selesai), daftar
  /// laporan, dan tombol untuk membuat laporan baru. Menyediakan aksi untuk
  /// menandai laporan sebagai selesai dan logout.
  const DashboardTeknisiScreen({Key? key}) : super(key: key);

  @override
  State<DashboardTeknisiScreen> createState() => _DashboardTeknisiScreenState();
}

class _DashboardTeknisiScreenState extends State<DashboardTeknisiScreen> {
  bool _loading = true;
  int _laporanTertunda = 0;
  int _laporanDiproses = 0;
  int _laporanSelesai = 0;
  List<Map<String, dynamic>> _laporanList = [];
  String? _userName = '';
  final Set<String> _updatingReportIds = {};

  @override
  void initState() {
    super.initState();
    // Inisialisasi state dan mulai memuat data awal (nama user + daftar laporan).
    _loadData();
  }

  Future<void> _loadData() async {
    // Load user profile (full_name) and reports belonging to current user.
    // Outputs: updates _userName, _laporanTertunda/_laporanDiproses/_laporanSelesai,
    // and _laporanList. Errors are shown via SnackBar and _loading toggled off.
    setState(() => _loading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Ambil nama user
      final userResp = await Supabase.instance.client
          .from('users')
          .select('full_name')
          .eq('id', userId)
          .single();
      final userName =
          (userResp as Map<String, dynamic>)['full_name'] as String?;

      // Ambil laporan milik teknisi (terbaru dulu)
      final reportsResp = await Supabase.instance.client
          .from('reports')
          .select()
          .eq('teknisi_id', userId)
          .order('created_at', ascending: false);

      final reports = reportsResp as List<dynamic>;

      int tertunda = 0, diproses = 0, selesai = 0;
      for (final r in reports) {
        final status = (r['status'] ?? '').toString();
        if (status == 'tertunda') tertunda++;
        if (status == 'diproses') diproses++;
        if (status == 'selesai') selesai++;
      }

      if (!mounted) return;

      setState(() {
        _userName = userName;
        _laporanTertunda = tertunda;
        _laporanDiproses = diproses;
        _laporanSelesai = selesai;
        _laporanList = reports
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Log singkat untuk debugging, tampilkan SnackBar agar user tahu.
      debugPrint('Error loading data: $e');
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _logout() async {
    // Tampilkan konfirmasi logout; jika dikonfirmasi, panggil Supabase signOut
    // dan navigasi kembali ke LoginScreen.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, int count, Color color) {
    // Kartu ringkasan kecil menampilkan jumlah per status (digunakan di header).
    return Expanded(
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markReportDone(String reportId) async {
    // Tandai laporan milik current user sebagai 'selesai'.
    // - Mencegah duplikasi request menggunakan _updatingReportIds.
    // - Memeriksa bahwa user saat ini terautentikasi.
    // - Update hanya ketika teknisi_id cocok dengan current user (menghindari RLS error).
    if (_updatingReportIds.contains(reportId)) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User belum terautentikasi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    debugPrint('TAPPED _markReportDone: $reportId by $userId');
    setState(() => _updatingReportIds.add(reportId));
    try {
      // Hanya update jika teknisi_id cocok (untuk menghindari penolakan oleh RLS)
      final resp = await Supabase.instance.client
          .from('reports')
          .update({'status': 'selesai'})
          .eq('id', reportId)
          .eq('teknisi_id', userId)
          .select();

      // Supabase SDK bisa mengembalikan List atau Map; anggap berhasil jika non-empty
      final updated = resp is List ? resp.isNotEmpty : resp != null;

      if (!updated) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mengupdate: tidak ditemukan atau tidak diizinkan',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Reload data lokal setelah sukses
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan ditandai selesai'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error _markReportDone: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _updatingReportIds.remove(reportId));
    }
  }

  Widget _buildLaporanItem(Map<String, dynamic> laporan) {
    // Membangun card untuk satu laporan.
    // Menentukan warna status, mengecek apakah user saat ini pemilik (teknisi yang sama),
    // dan menampilkan aksi untuk menandai selesai jika owner dan status belum selesai.
    final status = (laporan['status'] ?? '').toString();
    final statusColor = status == 'tertunda'
        ? Colors.orange
        : status == 'diproses'
        ? Colors.blue
        : Colors.green;
    final id = (laporan['id'] ?? '').toString();
    final teknisiId = (laporan['teknisi_id'] ?? '').toString();
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwner = currentUserId != null && currentUserId == teknisiId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(laporan['judul_pekerjaan'] ?? 'Untitled'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Lokasi: ${laporan['lokasi_pekerjaan'] ?? '—'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Tanggal: ${laporan['tanggal_pekerjaan'] ?? '—'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              label: Text(status.toUpperCase()),
              backgroundColor: statusColor.withOpacity(0.2),
              labelStyle: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            if (status != 'selesai' && isOwner)
              _updatingReportIds.contains(id)
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Tandai Selesai',
                      onPressed: () => _markReportDone(id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
            if (status == 'selesai' && isOwner)
              const Icon(Icons.check_circle, color: Colors.green, size: 28),
            if (!isOwner && status != 'selesai')
              const Tooltip(
                message: 'Bukan pekerjaan Anda',
                child: Icon(Icons.lock, color: Colors.grey, size: 24),
              ),
          ],
        ),
        onTap: () {
          // optional: open detail / edit
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bangun UI dashboard teknisi. Tampilan berubah berdasarkan _loading dan
    // isi _laporanList.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Teknisi'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome section
                    Text(
                      'Halo, $_userName!',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status Cards
                    Row(
                      children: [
                        _buildStatusCard(
                          'Tertunda',
                          _laporanTertunda,
                          Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusCard(
                          'Diproses',
                          _laporanDiproses,
                          Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildStatusCard(
                          'Selesai',
                          _laporanSelesai,
                          Colors.green,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Create New Report Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LaporanFormScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                      ),
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      label: const Text(
                        'Buat Laporan Baru',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Daftar Laporan
                    const Text(
                      'Daftar Laporan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    _laporanList.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text('Belum ada laporan'),
                            ),
                          )
                        : Column(
                            children: _laporanList
                                .map((lap) => _buildLaporanItem(lap))
                                .toList(),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
