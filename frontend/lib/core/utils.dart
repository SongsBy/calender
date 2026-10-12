/// Up to two initials from a display name, e.g. "Jane Doe" -> "JD".
String getInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.take(2).map((w) => w[0]).join().toUpperCase();
}
