import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  List<Counselor> counselors = [];
  bool isLoadingCounselors = true;
  bool isBooking = false;

  Counselor? selectedCounselor;
  DateTime selectedDate = DateTime.now();
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    fetchCounselors();
  }

  Future<void> fetchCounselors() async {
    try {
      final response = await supabase.from('counselors').select('id, name');

      setState(() {
        counselors = (response as List<dynamic>)
            .map((c) => Counselor.fromJson(c as Map<String, dynamic>))
            .toList();
        isLoadingCounselors = false;
      });
    } catch (e) {
      print('Error fetching counselors: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load counselors: $e')),
        );
        setState(() => isLoadingCounselors = false);
      }
    }
  }

  Future<bool> checkAvailability(String counselorId, DateTime date, TimeOfDay time) async {
    final appointmentDate = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final appointmentTime = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    try {
      // Check for approved OR pending appointments (both block the slot)
      // Only rejected appointments don't block the slot
      final response = await supabase
          .from('appointment')
          .select('id, status')
          .eq('conselor_id', counselorId)
          .eq('date', appointmentDate)
          .eq('time', appointmentTime)
          .inFilter('status', ['pending', 'approved'])
          .limit(1);

      // Slot is available only if no pending or approved appointments exist
      return (response as List).isEmpty;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  Future<void> bookAppointment() async {

    if (selectedCounselor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a counselor')),
      );
      return;
    }
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot')),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to book an appointment')),
      );
      return;
    }

    setState(() => isBooking = true);


    final bool available = await checkAvailability(
      selectedCounselor!.id,
      selectedDate,
      selectedTime!,
    );

    if (!available) {
      setState(() => isBooking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This time slot is no longer available')),
      );
      return;
    }
    final appointmentDate = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final appointmentTime = '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

    try {
      await supabase.from('appointment').insert({
        'user_id': user.id,
        'conselor_id': selectedCounselor!.id,
        'date': appointmentDate,
        'time': appointmentTime,
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment booked successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  List<TimeOfDay> generateTimeSlots() {
    List<TimeOfDay> slots = [];
    for (int hour = 9; hour <= 17; hour++) {
      slots.add(TimeOfDay(hour: hour, minute: 0));
      if (hour < 17) slots.add(TimeOfDay(hour: hour, minute: 30));
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    final timeSlots = generateTimeSlots();

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoadingCounselors
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Counselor:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButton<Counselor>(
                isExpanded: true,
                value: selectedCounselor,
                hint: const Text('Choose a counselor'),
                items: counselors.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c.name));
                }).toList(),
                onChanged: (val) => setState(() => selectedCounselor = val),
              ),

              const SizedBox(height: 24),
              const Text('Select Date:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('Select Time:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: timeSlots.map((t) {
                  final timeStr = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                  return ChoiceChip(
                    label: Text(timeStr),
                    selected: selectedTime == t,
                    onSelected: (selected) {
                      if (selected) setState(() => selectedTime = t);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isBooking ? null : bookAppointment,
                    child: isBooking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Book Appointment', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
