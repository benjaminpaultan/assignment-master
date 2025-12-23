import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'booking.dart';
import 'diary_mood_page.dart';
import 'view_booking.dart';
import 'calendar_page.dart';
import 'profile/profile_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToBooking;

  const HomePage({super.key, this.onNavigateToBooking});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  String _username = '';
  bool _isLoading = true;
  int _upcomingAppointmentsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadUpcomingAppointments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUpcomingAppointments(); // Refresh when app comes to foreground
    }
  }

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();

      setState(() {
        _username = profile['username'] ?? 'User';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _username = 'User';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUpcomingAppointments() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('appointment')
          .select('id')
          .eq('user_id', user.id)
          .inFilter('status', ['pending', 'approved'])
          .gte('date', DateTime.now().toIso8601String().split('T')[0]);

      setState(() {
        _upcomingAppointmentsCount = (response as List).length;
      });
    } catch (e) {
      // Ignore errors
    }
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isLoading
                  ? 'Hi there,'
                  : 'Hi there, ${_capitalizeWords(_username)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'How are you feeling today?',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.book_online,
                    label: 'Book Session',
                    color: Colors.deepPurple,
                    onTap: () {
                      if (widget.onNavigateToBooking != null) {
                        widget.onNavigateToBooking!();
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BookingPage()),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.mood,
                    label: 'Track Mood',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DiaryMoodPage(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            Text(
              'Today\'s Summary',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                children: [
                  _InfoTile(
                    icon: Icons.event_available,
                    title: 'Upcoming appointment',
                    subtitle: _upcomingAppointmentsCount == 0
                        ? 'No sessions booked yet'
                        : '$_upcomingAppointmentsCount appointment${_upcomingAppointmentsCount > 1 ? 's' : ''} scheduled',
                    onTap: () {
                      // Navigate to ViewBooking page
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ViewBooking()),
                      ).then((_) => _loadUpcomingAppointments()); // Refresh count when returning
                    },
                  ),
                  _InfoTile(
                    icon: Icons.calendar_today,
                    title: 'Your journey',
                    subtitle: 'Check your calendar for past activities',
                    onTap: () {
                      // Navigate to journey tab (index 1 - CalendarPage)
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CalendarPage()),
                      );
                    },
                  ),
                  _InfoTile(
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Update your personal details',
                    onTap: () {
                      // Navigate to profile tab (index 4)
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: color.withValues(alpha: 0.1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurple),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
            : null,
      ),
    );
  }
}


