import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment.dart';

final supabase = Supabase.instance.client;

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Appointment> _historyAppointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistoryAppointments();
  }

  Future<void> _fetchHistoryAppointments() async {

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to view history')),
      );
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final DateTime now = DateTime.now();
      final String todayString =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final response = await supabase
          .from('appointment')
          .select('id, status, date, time, conselor_id(name)')
          .eq('user_id', user.id)
          .lt('date', todayString)
          .order('date', ascending: false);

      final appointments = (response as List<dynamic>)
          .map((item) => Appointment.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() => _historyAppointments = appointments);
    } catch (e) {
      print('Error fetching history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load history: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAppointment(Appointment appointment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: Text(
            'Are you sure you want to delete this appointment with '
                '${appointment.counselorName ?? 'counselor'} '
                'on ${appointment.date} at ${appointment.time}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isLoading = true);

      await supabase
          .from('appointment')
          .delete()
          .eq('id', appointment.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment deleted from history')),
      );

      _fetchHistoryAppointments();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appointment History')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _historyAppointments.isEmpty
            ? const Center(
          child: Text(
            'No past appointments',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
            : ListView.builder(
          itemCount: _historyAppointments.length,
          itemBuilder: (context, index) {
            final appt = _historyAppointments[index];
            return Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          appt.counselorName ?? 'Unknown Counselor',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: appt.status == 'cancelled'
                                ? Colors.red.shade100
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            appt.status?.toUpperCase() ?? 'UNKNOWN',
                            style: TextStyle(
                              color: appt.status == 'cancelled'
                                  ? Colors.red.shade800
                                  : Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 16),
                            const SizedBox(width: 8),
                            Text(appt.date,
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 8),
                            Text(appt.time,
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _deleteAppointment(appt),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

