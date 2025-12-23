import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment.dart';

final supabase = Supabase.instance.client;

class Counselor {
  final String id;
  final String name;

  Counselor({required this.id, required this.name});

  factory Counselor.fromJson(Map<String, dynamic> json) {
    return Counselor(
      id: json['id'].toString(),
      name: json['name'] as String,
    );
  }
}

class EditBookingPage extends StatefulWidget {
  final Appointment appointment;

  const EditBookingPage({super.key, required this.appointment});

  @override
  State<EditBookingPage> createState() => _EditBookingPageState();
}

class _EditBookingPageState extends State<EditBookingPage> {
  Appointment? _selectedAppointment;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  List<Counselor> counselors = [];
  Counselor? selectedCounselor;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedAppointment = widget.appointment;


    final dateParts = _selectedAppointment!.date.split('-');
    selectedDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );


    final timeParts = _selectedAppointment!.time.split(':');
    selectedTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    _loadCounselors();
  }

  Future<void> _loadCounselors() async {
    try {
      final response = await supabase.from('counselors').select('id, name');

      counselors = (response as List)
          .map((c) => Counselor.fromJson(c))
          .toList();

      selectedCounselor = counselors.firstWhere(
            (c) => c.id == _selectedAppointment!.conselorId,
        orElse: () => counselors.first,
      );

      setState(() {});
    } catch (e) {
      print('Error fetching counselors: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load counselors: $e')),
      );
    }
  }

  List<TimeOfDay> generateTimeSlots() {
    List<TimeOfDay> slots = [];
    for (int hour = 9; hour <= 17; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      slots.add(TimeOfDay(hour: hour, minute: 30));
    }
    return slots;
  }

  Future<void> _updateAppointment() async {
    if (selectedDate == null || selectedTime == null || selectedCounselor == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateString =
          '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      final timeString =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

      await supabase.from('appointment').update({
        'date': dateString,
        'time': timeString,
        'conselor_id': selectedCounselor!.id,
      }).eq('id', _selectedAppointment!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment updated successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAppointment() async {
    try {
      setState(() => _isLoading = true);

      await supabase
          .from('appointment')
          .delete()
          .eq('id', _selectedAppointment!.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment deleted')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Counselor:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            DropdownButton<Counselor>(
              isExpanded: true,
              value: selectedCounselor,
              hint: const Text('Select Counselor'),
              items: counselors.map((c) {
                return DropdownMenuItem(
                  value: c,
                  child: Text(c.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedCounselor = val),
            ),
            const SizedBox(height: 24),

            const Text('Date:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate!,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) setState(() => selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 18, color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Time:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: timeSlots.map((t) {
                final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                return ChoiceChip(
                  label: Text(timeStr),
                  selected: selectedTime == t,
                  onSelected: (_) => setState(() => selectedTime = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateAppointment,
                  child: const Text('Update'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _deleteAppointment,
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

