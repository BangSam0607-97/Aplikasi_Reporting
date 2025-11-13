import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';

class DashboardSupervisorScreen extends StatefulWidget {
  const DashboardSupervisorScreen({Key? key}) : super(key: key);

  @override
  State<DashboardSupervisorScreen> createState() =>
      _DashboardSupervisorScreenState();
}

class _DashboardSupervisorScreenState extends State<DashboardSupervisorScreen> {
  bool _loading = true;
  String? _error;
  int _totalTertunda = 0;
  int _totalDiproses = 0;
  int _totalSelesai = 0;
  List<Map<String, dynamic>> _teknisiStats = [];
  List<Map<String, dynamic>> _filteredReports = [];
  String? _selectedFilter; // 'tertunda', 'diproses', 'selesai', or null

  // cache laporan per teknisi
  final Map<String, List<Map<String, dynamic>>> _reportsByTeknisi = {};
  final Set<String> _loadingReportIds = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final reportsQuery = await supabase
          .from('reports')
          .select('''
            id,
            status,
            teknisi_id,
            users!reports_teknisi_id_fkey (
              id,
              full_name,
              role
            )
          ''')
          .eq('users.role', 'teknisi');

      final reports = reportsQuery as List<dynamic>;

      final Map<String, Map<String, dynamic>> teknisiMap = {};
      int tertunda = 0, diproses = 0, selesai = 0;

      for (final report in reports) {
        final status = (report['status'] ?? '').toString();
        final teknisi = report['users'] as Map<String, dynamic>;
        final teknisiId = teknisi['id'].toString();

        if (status == 'tertunda') tertunda++;
        if (status == 'diproses') diproses++;
        if (status == 'selesai') selesai++;

        if (!teknisiMap.containsKey(teknisiId)) {
          teknisiMap[teknisiId] = {
            'id': teknisiId,
            'name': teknisi['full_name'] ?? '—',
            'tertunda': 0,
            'diproses': 0,
            'selesai': 0,
            'total': 0,
          };
        }

        teknisiMap[teknisiId]![status] =
            (teknisiMap[teknisiId]![status] ?? 0) + 1;
        teknisiMap[teknisiId]!['total'] =
            (teknisiMap[teknisiId]!['total'] ?? 0) + 1;
      }

      final teknisiList = teknisiMap.values.toList()
        ..sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      if (!mounted) return;
      setState(() {
        _totalTertunda = tertunda;
        _totalDiproses = diproses;
        _totalSelesai = selesai;
        _teknisiStats = teknisiList;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadReportsByStatus(String status) async {
    try {
      final resp = await Supabase.instance.client
          .from('reports')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false);

      final List reports = resp as List<dynamic>;
      if (!mounted) return;

      setState(() {
        _filteredReports = reports
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        _selectedFilter = status;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat laporan: ${e.toString()}')),
      );
    }
  }

  Future<void> _fetchReportsForTeknisi(String teknisiId) async {
    if (_reportsByTeknisi.containsKey(teknisiId)) return;
    try {
      final resp = await Supabase.instance.client
          .from('reports')
          .select()
          .eq('teknisi_id', teknisiId)
          .order('created_at', ascending: false);
      final List reports = resp as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _reportsByTeknisi[teknisiId] = reports
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat laporan: ${e.toString()}')),
      );
    }
  }

  Future<void> _approveReport(String reportId, String teknisiId) async {
    if (_loadingReportIds.contains(reportId)) return;
    setState(() => _loadingReportIds.add(reportId));
    try {
      await Supabase.instance.client
          .from('reports')
          .update({'status': 'diproses'})
          .eq('id', reportId)
          .select();

      _reportsByTeknisi.remove(teknisiId);
      await _fetchReportsForTeknisi(teknisiId);

      // Reload filtered reports if tertunda is selected
      if (_selectedFilter == 'tertunda') {
        await _loadReportsByStatus('tertunda');
      }

      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan disetujui dan pindah ke Diproses'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyetujui: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingReportIds.remove(reportId));
    }
  }

  // Tambahan: fungsi untuk menandai laporan selesai (dipanggil dari daftar diproses)
  Future<void> _completeReport(String reportId) async {
    if (_loadingReportIds.contains(reportId)) return;
    setState(() => _loadingReportIds.add(reportId));
    try {
      await Supabase.instance.client
          .from('reports')
          .update({'status': 'selesai'})
          .eq('id', reportId)
          .select();

      // Refresh current filtered view jika perlu
      if (_selectedFilter == 'diproses') {
        await _loadReportsByStatus('diproses');
      }
      await _loadStats();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Laporan dipindahkan ke Selesai'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal update: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loadingReportIds.remove(reportId));
    }
  }

  // Tambahan: fungsi logout
  Future<void> _logout() async {
    final doLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (doLogout == true) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  Widget _statusCard(String label, int count, Color color, String filterKey) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _loadReportsByStatus(filterKey),
        child: Card(
          elevation: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: _selectedFilter == filterKey
                  ? Border.all(color: color, width: 2)
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilteredReportsList() {
    if (_filteredReports.isEmpty) {
      return const Center(child: Text('Tidak ada laporan untuk filter ini'));
    }

    return ListView.builder(
      itemCount: _filteredReports.length,
      itemBuilder: (context, index) {
        final r = _filteredReports[index];
        final status = (r['status'] ?? '').toString();
        final jid = (r['id'] ?? '').toString();
        final judul = r['judul_pekerjaan'] ?? '-';
        final lokasi = r['lokasi_pekerjaan'] ?? '-';
        final deskripsi = r['deskripsi'] ?? '-';
        final tanggal = r['tanggal_pekerjaan'] ?? '-';
        final teknisiId = (r['teknisi_id'] ?? '').toString();

        Color statusColor = Colors.grey;
        if (status == 'tertunda') statusColor = Colors.orange;
        if (status == 'diproses') statusColor = Colors.blue;
        if (status == 'selesai') statusColor = Colors.green;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: ListTile(
            isThreeLine: true,
            title: Text(
              judul,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Lokasi: $lokasi', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text('Tanggal: $tanggal', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  deskripsi,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: SizedBox(
              width: 120,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: const TextStyle(fontSize: 9),
                    ),
                    backgroundColor: statusColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_loadingReportIds.contains(jid))
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (status == 'diproses')
                    IconButton(
                      icon: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                      tooltip: 'Selesai',
                      onPressed: () => _completeReport(jid),
                      padding: EdgeInsets.zero,
                    )
                  else if (status == 'tertunda')
                    IconButton(
                      icon: const Icon(
                        Icons.thumb_up,
                        color: Colors.blue,
                        size: 20,
                      ),
                      tooltip: 'Setujui',
                      onPressed: () => _approveReport(jid, teknisiId),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(judul),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Status: $status',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Lokasi: $lokasi'),
                        const SizedBox(height: 8),
                        Text('Tanggal: $tanggal'),
                        const SizedBox(height: 8),
                        const Text(
                          'Deskripsi:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(deskripsi),
                      ],
                    ),
                  ),
                  actions: [
                    if (status == 'tertunda')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveReport(jid, teknisiId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text(
                          'Setujui',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Tutup'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTeknisiRow(Map<String, dynamic> item) {
    final teknisiId = item['id'] as String;
    final name = item['name'] ?? 'Unknown';
    final total = item['total'] ?? 0;
    final tertunda = item['tertunda'] ?? 0;
    final diproses = item['diproses'] ?? 0;
    final selesai = item['selesai'] ?? 0;

    final reports = _reportsByTeknisi[teknisiId];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: ExpansionTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            Chip(
              label: Text('Total: $total'),
              backgroundColor: Colors.grey.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              labelStyle: const TextStyle(fontSize: 9),
            ),
            Chip(
              label: Text('Tertunda: $tertunda'),
              backgroundColor: Colors.orange.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              labelStyle: const TextStyle(fontSize: 9, color: Colors.orange),
            ),
            Chip(
              label: Text('Diproses: $diproses'),
              backgroundColor: Colors.blue.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              labelStyle: const TextStyle(fontSize: 9, color: Colors.blue),
            ),
            Chip(
              label: Text('Selesai: $selesai'),
              backgroundColor: Colors.green.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              labelStyle: const TextStyle(fontSize: 9, color: Colors.green),
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded) _fetchReportsForTeknisi(teknisiId);
        },
        children: [
          if (reports == null)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('Belum ada laporan'),
            )
          else
            Column(
              children: reports.map((r) {
                final status = (r['status'] ?? '').toString();
                final jid = (r['id'] ?? '').toString();
                final judul = r['judul_pekerjaan'] ?? '-';
                final lokasi = r['lokasi_pekerjaan'] ?? '-';
                final deskripsi = r['deskripsi'] ?? '-';
                final tanggal = r['tanggal_pekerjaan'] ?? '-';
                Color statusColor = Colors.grey;
                if (status == 'tertunda') statusColor = Colors.orange;
                if (status == 'diproses') statusColor = Colors.blue;
                if (status == 'selesai') statusColor = Colors.green;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    isThreeLine: true,
                    title: Text(
                      judul,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Lokasi: $lokasi',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal: $tanggal',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Deskripsi: $deskripsi',
                          style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Chip(
                            label: Text(
                              status.toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: statusColor.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(judul),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Status: $status',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('Lokasi: $lokasi'),
                                const SizedBox(height: 8),
                                Text('Tanggal: $tanggal'),
                                const SizedBox(height: 8),
                                const Text(
                                  'Deskripsi:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(deskripsi),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Tutup'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Supervisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                )
              : _selectedFilter == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _statusCard(
                          'Tertunda',
                          _totalTertunda,
                          Colors.orange,
                          'tertunda',
                        ),
                        const SizedBox(width: 8),
                        _statusCard(
                          'Diproses',
                          _totalDiproses,
                          Colors.blue,
                          'diproses',
                        ),
                        const SizedBox(width: 8),
                        _statusCard(
                          'Selesai',
                          _totalSelesai,
                          Colors.green,
                          'selesai',
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Statistik per Teknisi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _teknisiStats.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada teknisi atau laporan',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _teknisiStats.length,
                              itemBuilder: (context, index) {
                                return _buildTeknisiRow(_teknisiStats[index]);
                              },
                            ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _statusCard(
                          'Tertunda',
                          _totalTertunda,
                          Colors.orange,
                          'tertunda',
                        ),
                        const SizedBox(width: 8),
                        _statusCard(
                          'Diproses',
                          _totalDiproses,
                          Colors.blue,
                          'diproses',
                        ),
                        const SizedBox(width: 8),
                        _statusCard(
                          'Selesai',
                          _totalSelesai,
                          Colors.green,
                          'selesai',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Text(
                            'Laporan: $_selectedFilter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedFilter = null),
                            child: const Text('Kembali'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildFilteredReportsList()),
                  ],
                ),
        ),
      ),
    );
  }
}
