class CalendarMember {
  const CalendarMember({
    required this.id,
    required this.name,
    required this.role,
    required this.slot,
  });
  final String id;
  final String name;
  final String role;
  final int slot;
  factory CalendarMember.fromJson(Map<String, dynamic> json) => CalendarMember(
    id: json['id'] as String,
    name: (json['full_name'] as String?)?.trim().isNotEmpty == true
        ? json['full_name'] as String
        : '사용자 ${json['slot']}',
    role: json['role'] as String,
    slot: json['slot'] as int,
  );
}

class SharedCalendar {
  const SharedCalendar({
    required this.id,
    required this.name,
    required this.timezone,
    required this.members,
  });
  final String id;
  final String name;
  final String timezone;
  final List<CalendarMember> members;
  bool get isConnected => members.length == 2;
  bool isOwner(String userId) =>
      members.any((m) => m.id == userId && m.role == 'owner');
  factory SharedCalendar.fromJson(Map<String, dynamic> json) => SharedCalendar(
    id: json['id'] as String,
    name: json['name'] as String,
    timezone: json['timezone'] as String,
    members: (json['members'] as List)
        .map((m) => CalendarMember.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class CalendarInvitation {
  const CalendarInvitation({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
  String get displayCode =>
      '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8)}';
  factory CalendarInvitation.fromJson(Map<String, dynamic> json) =>
      CalendarInvitation(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
