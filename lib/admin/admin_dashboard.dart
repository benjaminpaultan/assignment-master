import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../appointment.dart';
import '../notifications/notification_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.library_books), text: 'Guides'),
            Tab(icon: Icon(Icons.book_online), text: 'Appointments'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await supabase.auth.signOut();
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _GuidesModerationTab(),
          _AppointmentsModerationTab(),
        ],
      ),
    );
  }
}

// --- GUIDES MODERATION TAB ---
class _GuidesModerationTab extends StatefulWidget {
  const _GuidesModerationTab();

  @override
  State<_GuidesModerationTab> createState() => _GuidesModerationTabState();
}

class _GuidesModerationTabState extends State<_GuidesModerationTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingGuides = [];
  List<Map<String, dynamic>> _approvedGuides = [];
  List<Map<String, dynamic>> _rejectedGuides = [];
  bool _isLoading = true;
  String _selectedFilter = 'Pending';

  @override
  void initState() {
    super.initState();
    _fetchGuides();
  }

  Future<void> _fetchGuides() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('guides')
          .select('*, profiles!left(username)')
          .order('created_at', ascending: false);

      final guides = (response as List).cast<Map<String, dynamic>>();

      setState(() {
        _pendingGuides = guides
            .where((g) => (g['status'] as String? ?? 'pending') == 'pending')
            .toList();
        _approvedGuides = guides
            .where((g) => (g['status'] as String?) == 'approved')
            .toList();
        _rejectedGuides = guides
            .where((g) => (g['status'] as String?) == 'rejected')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching guides: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading guides: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGuideStatus(int guideId, String status) async {
    try {
      await supabase
          .from('guides')
          .update({'status': status})
          .eq('id', guideId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guide ${status == 'approved' ? 'approved' : 'rejected'}'),
          ),
        );
      }
      _fetchGuides();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating guide: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _currentList {
    switch (_selectedFilter) {
      case 'Approved':
        return _approvedGuides;
      case 'Rejected':
        return _rejectedGuides;
      default:
        return _pendingGuides;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter buttons
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: ['Pending', 'Approved', 'Rejected'].map((filter) {
              final isSelected = _selectedFilter == filter;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // List of guides
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentList.isEmpty
                  ? Center(
                      child: Text(
                        'No ${_selectedFilter.toLowerCase()} guides',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchGuides,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _currentList.length,
                        itemBuilder: (context, index) {
                          final guide = _currentList[index];
                          final profile = guide['profiles'] as Map<String, dynamic>?;
                          final username = profile?['username'] ?? 'Unknown';
                          final title = guide['title'] ?? 'No Title';
                          final category = guide['category'] ?? 'General';
                          final content = guide['content'] ?? '';
                          final createdAt = guide['created_at'] as String;
                          final guideId = guide['id'] as int;
                          final isPending = _selectedFilter == 'Pending';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'By $username • $category',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              'Created: ${createdAt.split('T')[0]}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isPending)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'PENDING',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    content.length > 100
                                        ? '${content.substring(0, 100)}...'
                                        : content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () async {
                                            await _updateGuideStatus(
                                                guideId, 'rejected');
                                          },
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          label: const Text('Reject',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _updateGuideStatus(
                                                guideId, 'approved');
                                          },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// --- APPOINTMENTS MODERATION TAB ---
class _AppointmentsModerationTab extends StatefulWidget {
  const _AppointmentsModerationTab();

  @override
  State<_AppointmentsModerationTab> createState() =>
      _AppointmentsModerationTabState();
}

class _AppointmentsModerationTabState
    extends State<_AppointmentsModerationTab> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allAppointments = [];
  List<Map<String, dynamic>> _filteredAppointments = [];
  bool _isLoading = true;
  String _selectedFilter = 'Pending';
  String _searchQuery = '';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoading = true);
    try {
      // Fetch appointments with user info and counselor info
      final response = await supabase
          .from('appointment')
          .select('*, conselor_id(name), profiles!appointment_user_id_fkey(username, email)')
          .order('date', ascending: false);

      setState(() {
        _allAppointments = (response as List).cast<Map<String, dynamic>>();
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching appointments: $e');
      // Try without user profile join if foreign key doesn't exist
      try {
        final response = await supabase
            .from('appointment')
            .select('*, conselor_id(name)')
            .order('date', ascending: false);

        // Manually fetch user profiles
        final appointments = (response as List).cast<Map<String, dynamic>>();
        for (var appt in appointments) {
          try {
            final userId = appt['user_id'] as String;
            final userProfile = await supabase
                .from('profiles')
                .select('username, email')
                .eq('id', userId)
                .single();
            appt['profiles'] = userProfile;
          } catch (_) {
            appt['profiles'] = {'username': 'Unknown', 'email': ''};
          }
        }

        setState(() {
          _allAppointments = appointments;
          _applyFilters();
          _isLoading = false;
        });
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading appointments: $e2')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAppointments = _allAppointments.where((appt) {
        // Status filter
        final status = appt['status'] as String? ?? 'pending';
        final matchesStatus = _selectedFilter == 'Pending'
            ? status == 'pending'
            : _selectedFilter == 'Approved'
                ? status == 'approved'
                : status == 'rejected';

        // Username search
        final profiles = appt['profiles'] as Map<String, dynamic>?;
        final username = (profiles?['username'] as String? ?? '').toLowerCase();
        final email = (profiles?['email'] as String? ?? '').toLowerCase();
        final matchesSearch = _searchQuery.isEmpty ||
            username.contains(_searchQuery.toLowerCase()) ||
            email.contains(_searchQuery.toLowerCase());

        // Date filter
        final matchesDate = _selectedDate == null ||
            appt['date'] ==
                '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

        return matchesStatus && matchesSearch && matchesDate;
      }).toList();
    });
  }

  Future<void> _updateAppointmentStatus(String appointmentId, String status) async {
    try {
      // Get appointment details before updating
      final appointmentResponse = await supabase
          .from('appointment')
          .select('user_id, date, time, conselor_id(name)')
          .eq('id', appointmentId)
          .single();

      final appointment = appointmentResponse as Map<String, dynamic>;
      final userId = appointment['user_id'] as String;
      final counselor = appointment['conselor_id'] as Map<String, dynamic>?;
      final counselorName = counselor?['name'] as String? ?? 'Unknown Counselor';
      final date = appointment['date'] as String;
      final time = appointment['time'] as String;

      // Update appointment status
      await supabase
          .from('appointment')
          .update({'status': status})
          .eq('id', appointmentId);

      // Create notification for the user
      await NotificationService.createAppointmentNotification(
        userId: userId,
        appointmentId: appointmentId,
        status: status,
        counselorName: counselorName,
        date: date,
        time: time,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Appointment ${status == 'approved' ? 'approved' : 'rejected'}'),
          ),
        );
      }
      _fetchAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating appointment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter section
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by username or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _applyFilters();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 8),
              // Date filter and status filter row
              Row(
                children: [
                  // Date filter button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _applyFilters();
                          });
                        } else {
                          setState(() {
                            _selectedDate = null;
                            _applyFilters();
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _selectedDate == null
                            ? 'Filter by date'
                            : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (_selectedDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                          _applyFilters();
                        });
                      },
                      tooltip: 'Clear date filter',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Status filter chips
              Row(
                children: ['Pending', 'Approved', 'Rejected'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedFilter = filter;
                              _applyFilters();
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        // List of appointments
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAppointments.isEmpty
                  ? Center(
                      child: Text(
                        'No ${_selectedFilter.toLowerCase()} appointments found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchAppointments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filteredAppointments.length,
                        itemBuilder: (context, index) {
                          final appt = _filteredAppointments[index];
                          final counselor = appt['conselor_id'] as Map<String, dynamic>?;
                          final counselorName = counselor?['name'] as String? ?? 'Unknown';
                          final profiles = appt['profiles'] as Map<String, dynamic>?;
                          final username = profiles?['username'] as String? ?? 'Unknown User';
                          final email = profiles?['email'] as String? ?? '';
                          final status = appt['status'] as String? ?? 'pending';
                          final isPending = _selectedFilter == 'Pending';
                          final appointmentId = appt['id'].toString();
                          final date = appt['date'] as String;
                          final time = appt['time'] as String;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              counselorName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            // Show who booked the appointment
                                            Row(
                                              children: [
                                                const Icon(Icons.person,
                                                    size: 14,
                                                    color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Booked by: $username',
                                                  style: TextStyle(
                                                    color: Colors.blue[700],
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (email.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                email,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today,
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  date,
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                ),
                                                const SizedBox(width: 16),
                                                const Icon(Icons.access_time,
                                                    size: 14),
                                                const SizedBox(width: 4),
                                                Text(
                                                  time,
                                                  style: TextStyle(
                                                      color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: status == 'pending'
                                              ? Colors.orange.shade100
                                              : status == 'approved'
                                                  ? Colors.green.shade100
                                                  : Colors.red.shade100,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: status == 'pending'
                                                ? Colors.orange.shade800
                                                : status == 'approved'
                                                    ? Colors.green.shade800
                                                    : Colors.red.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isPending) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () async {
                                            await _updateAppointmentStatus(
                                                appointmentId, 'rejected');
                                          },
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          label: const Text('Reject',
                                              style:
                                                  TextStyle(color: Colors.red)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _updateAppointmentStatus(
                                                appointmentId, 'approved');
                                          },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
