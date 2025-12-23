class Appointment {
  final String id;
  final String userId;
  final String conselorId;
  final String date;
  final String time;
  final String? status;
  final String? counselorName;

  Appointment({
    required this.id,
    required this.userId,
    required this.conselorId,
    required this.date,
    required this.time,
    this.status,
    this.counselorName,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'].toString(),
      userId: json['user_id'].toString(),
      conselorId: json['conselor_id'] is Map
          ? (json['conselor_id']['id']).toString()
          : json['conselor_id'].toString(),
      date: json['date'] as String,
      time: json['time'] as String,
      status: json['status'] != null ? json['status'] as String : null,
      counselorName: json['conselor_id'] is Map
          ? json['conselor_id']['name'] as String
          : 'Unknown',
    );
  }
}

