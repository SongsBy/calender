class CalendarMember {
  const CalendarMember({
    required this.id,
    required this.name,
    required this.role,
    required this.slot,
    this.username,
  });
  final String id;

  /// 표시 이름 — 서버의 full_name, 없으면 아이디, 그것도 없으면 '사용자 N'.
  final String name;
  final String role;
  final int slot;
  final String? username;
  bool get isOwner => role == 'owner';
  factory CalendarMember.fromJson(Map<String, dynamic> json) {
    final fullName = (json['full_name'] as String?)?.trim();
    final username = (json['username'] as String?)?.trim();
    return CalendarMember(
      id: json['id'] as String,
      name: fullName?.isNotEmpty == true
          ? fullName!
          : username?.isNotEmpty == true
          ? username!
          : '사용자 ${json['slot']}',
      role: json['role'] as String,
      slot: json['slot'] as int,
      username: username,
    );
  }
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
  CalendarMember? member(String userId) {
    for (final m in members) {
      if (m.id == userId) return m;
    }
    return null;
  }

  CalendarMember? partnerOf(String userId) {
    for (final m in members) {
      if (m.id != userId) return m;
    }
    return null;
  }

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

  /// 'ABCD-EFGH-2345' — 복사용.
  String get displayCode =>
      '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8)}';

  /// ['ABCD', 'EFGH', '2345'] — 화면 표시용 3묶음.
  List<String> get groups => [
    code.substring(0, 4),
    code.substring(4, 8),
    code.substring(8),
  ];
  factory CalendarInvitation.fromJson(Map<String, dynamic> json) =>
      CalendarInvitation(
        code: json['code'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
