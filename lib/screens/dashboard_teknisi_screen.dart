import 'package:flutter/material.dart';
import 'package:aplikasi_reporting/screens/laporan_form_screen.dart';

class DashboardTeknisiScreen extends StatefulWidget {
  const DashboardTeknisiScreen({Key? key}) : super(key: key);

  @override
  State<DashboardTeknisiScreen> createState() => _DashboardTeknisiScreenState();
}

class _DashboardTeknisiScreenState extends State<DashboardTeknisiScreen> {
  // Dummy data untuk contoh
  final int _laporanTertunda = 5;
  final int _laporanDiproses = 3;
  final int _laporanSelesai = 10;

  Widget _buildStatusCard(String title, int count, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            // Status Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              children: [
                _buildStatusCard(
                  'Laporan Tertunda',
                  _laporanTertunda,
                  Colors.orange,
                ),
                _buildStatusCard(
                  'Sedang Diproses',
                  _laporanDiproses,
                  Colors.blue,
                ),
                _buildStatusCard(
                  'Laporan Selesai',
                  _laporanSelesai,
                  Colors.green,
                ),
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 40,
                            color: Colors.blue,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Buat Laporan\nBaru',
                            textAlign: TextAlign.center,
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

            const SizedBox(height: 24),

            // Recent Reports Section
            const Text(
              'Laporan Terbaru',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.work, color: Colors.white),
                      ),
                      title: Text('Laporan #${index + 1}'),
                      subtitle: Text('Deskripsi laporan ${index + 1}'),
                      trailing: _getStatusChip(index),
                    ),
                  );
                },
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
