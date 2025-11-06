import 'package:flutter/material.dart';
import 'package:aplikasi_reporting/screens/Teknisi/laporan_form_screen.dart';

class DashboardTeknisiScreen extends StatefulWidget {
  const DashboardTeknisiScreen({Key? key}) : super(key: key);

  @override
  State<DashboardTeknisiScreen> createState() => _DashboardTeknisiScreenState();
}

class _DashboardTeknisiScreenState extends State<DashboardTeknisiScreen> {
  // Initialize counters as zero
  final int _laporanTertunda = 0;
  final int _laporanDiproses = 0;
  final int _laporanSelesai = 0;

  Widget _buildStatusCard(String title, int count, Color color) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Teknisi'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Cards in horizontal row
            Row(
              children: [
                _buildStatusCard(
                  'Laporan\nTertunda',
                  _laporanTertunda,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildStatusCard(
                  'Sedang\nDiproses',
                  _laporanDiproses,
                  Colors.blue,
                ),
                const SizedBox(width: 8),
                _buildStatusCard(
                  'Laporan\nSelesai',
                  _laporanSelesai,
                  Colors.green,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Create New Report Card
            Card(
              elevation: 4,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LaporanFormScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 24,
                        color: Colors.blue,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Buat Laporan Baru',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusChip(int index) {
    if (index == 0) {
      return const Chip(
        label: Text('Tertunda'),
        backgroundColor: Colors.orange,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else if (index == 1) {
      return const Chip(
        label: Text('Diproses'),
        backgroundColor: Colors.blue,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else {
      return const Chip(
        label: Text('Selesai'),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    }
  }
}
