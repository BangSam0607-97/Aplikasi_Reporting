import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/login_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Program entry point and initial configuration.
///
/// This file performs minimal app bootstrap:
/// - Initialize Flutter bindings
/// - Initialize locale-specific date formatting (used by `intl`)
/// - Initialize Supabase client
/// - Launch the root widget `MyApp`
///
/// Security note: the anonKey used below is intended for client-side
/// (browser/mobile) usage. Do NOT commit service_role keys or other
/// sensitive secrets to a public repository.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);

  await Supabase.initialize(
    url: 'https://plixjozypuontjqdkdhi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsaXhqb3p5cHVvbnRqcWRrZGhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0Mjk1MTUsImV4cCI6MjA3ODAwNTUxNX0.0jxzH7iDfDAlgPk7kThnpaFSeKLaHQ-IwyLtBRN2TAE',
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
