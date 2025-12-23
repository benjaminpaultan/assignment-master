import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking.dart';
import 'calendar_page.dart';
import 'logic/mood_controller.dart';
import 'auth/auth_gate.dart';
import 'profile/profile_page.dart';




const String supabaseUrl = 'https://ujcedgkwtpxmclcsjtxv.supabase.co';
const String supabaseKey = 'sb_publishable_0lj82seIArgLvM1XtbSF2Q_Q9VhN9ME';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(
    // Added Provider so MoodController works across your pages
    ChangeNotifierProvider(
      create: (context) => MoodController()..loadMoods(),
      child: const MyApp(),
    ),
  );
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Health Care App',
      debugShowCheckedModeBanner: false, // Cleaner UI
      theme: ThemeData(
        useMaterial3: true,
        // Fixed: Added ColorScheme before .fromSeed
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthGate(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 2; // Default to Home

  // Logic remains the same, but index 1 is now your CalendarPage
  final List<Widget> _pages = [
    const Placeholder(), // Module 1
    const CalendarPage(), // REPLACED: Your Journey Page
    const Placeholder(), // Home
    const BookingPage(), // Booking
    const ProfilePage(), // Profile
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar from here if your CalendarPage has its own header
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Module1'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Journey'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online), label: 'Booking'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}