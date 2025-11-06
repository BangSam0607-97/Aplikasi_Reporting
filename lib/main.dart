import 'package:flutter/material.dart';
import 'package:aplikasi_reporting/screens/dashboard_teknisi_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplikasi Reporting',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DashboardTeknisiScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
