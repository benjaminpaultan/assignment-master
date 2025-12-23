import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking.dart';
import 'calendar_page.dart';
import 'home_page.dart';
import 'logic/mood_controller.dart';
import 'auth/auth_gate.dart';
import 'profile/profile_page.dart';
import 'view_booking.dart';
import 'guide.dart';
import 'notifications/notification_service.dart';




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
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    // Refresh notification count periodically
    _startNotificationListener();
  }

  void _startNotificationListener() {
    // Refresh every 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _loadUnreadCount();
        _startNotificationListener();
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() => _unreadNotifications = count);
    }
  }

  // Merged: GuidePage at index 0, HomePage at index 2, ViewBooking at index 3
  List<Widget> get _pages => [
    const GuidePage(), // Wellness Community Guides
    const CalendarPage(), // Journey Page
    HomePage(onNavigateToBooking: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingPage()),
      );
    }), // Home
    ViewBooking(onNotificationsRead: _loadUnreadCount), // Booking
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
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Refresh notification count when booking tab is selected
          if (index == 3) {
            _loadUnreadCount();
          }
        },
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Guides'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: 'Journey'),
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.book_online),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Booking',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}