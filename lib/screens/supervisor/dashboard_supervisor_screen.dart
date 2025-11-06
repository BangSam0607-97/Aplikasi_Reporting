import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // Updated query execution and error handling
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

      // Process data
      final Map<String, Map<String, dynamic>> teknisiMap = {};
      int tertunda = 0, diproses = 0, selesai = 0;

      for (final report in reports) {
        final status = report['status'] as String;
        final teknisi = report['users'] as Map<String, dynamic>;
        final teknisiId = teknisi['id'] as String;

        // Update total counts
        if (status == 'tertunda') tertunda++;
        if (status == 'diproses') diproses++;
        if (status == 'selesai') selesai++;

        // Initialize or update teknisi stats
        if (!teknisiMap.containsKey(teknisiId)) {
          teknisiMap[teknisiId] = {
            'id': teknisiId,
            'name': teknisi['full_name'],
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

      // Convert to list and sort
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

  Widget _statusCard(String label, int count, Color color) {
    return Expanded(
      child: Card(
        elevation: 2,
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
    );
  }

  Widget _buildTeknisiRow(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: ExpansionTile(
        title: Text(
          item['name'] ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('Total: ${item['total']} laporan'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statusChip('Tertunda', item['tertunda'] ?? 0, Colors.orange),
                _statusChip('Diproses', item['diproses'] ?? 0, Colors.blue),
                _statusChip('Selesai', item['selesai'] ?? 0, Colors.green),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, int count, Color color) {
    return Chip(
      label: Text(
        '$label: $count',
        style: TextStyle(
          color: color is MaterialColor ? color.shade900 : color,
        ),
      ),
      backgroundColor: color.withOpacity(0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Supervisor'),
        actions: [
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _statusCard('Tertunda', _totalTertunda, Colors.orange),
                        const SizedBox(width: 8),
                        _statusCard('Diproses', _totalDiproses, Colors.blue),
                        const SizedBox(width: 8),
                        _statusCard('Selesai', _totalSelesai, Colors.green),
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
                ),
        ),
      ),
    );
  }
}
