import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  await Supabase.initialize(
    url: 'https://etvexypswbstgpywxjis.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0dmV4eXBzd2JzdGdweXd4amlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDM4MjI1ODMsImV4cCI6MjAxOTM5ODU4M30.Lxdr3eZ8kVhJI3lvTZwFnpxUDeVgGBlbM5bj6bYTZRM',
  );

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
        useMaterial3: true, // Enable Material 3
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
