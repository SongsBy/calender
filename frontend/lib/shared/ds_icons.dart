import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// 24px 선형 아이콘 (stroke 1.8~2, round). 디자인 시안의 SVG 패스를 그대로 사용합니다.
class DsIcon extends StatelessWidget {
  const DsIcon(
    this.paths, {
    super.key,
    this.size = 24,
    this.color = AppColors.brown900,
    this.stroke = 2,
    this.semanticLabel,
  });

  final String paths;
  final double size;
  final Color color;
  final double stroke;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
    'viewBox="0 0 24 24" fill="none" stroke="${_hex(color)}" '
    'stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">'
    '$paths</svg>',
    width: size,
    height: size,
    semanticsLabel: semanticLabel,
    excludeFromSemantics: semanticLabel == null,
  );
}

/// 디자인 시안에서 쓰인 아이콘 패스 모음.
class DsIcons {
  DsIcons._();

  static const back = '<path d="M15 5l-7 7 7 7"/>';
  static const forward = '<path d="M9 5l7 7-7 7"/>';
  static const close = '<path d="M6 6l12 12M18 6L6 18"/>';
  static const refresh =
      '<path d="M20 12a8 8 0 1 1-2.3-5.7"/><path d="M20 4v5h-5"/>';
  static const person =
      '<circle cx="12" cy="8.5" r="3.8"/>'
      '<path d="M4.5 20c0-3.9 3.4-6.5 7.5-6.5s7.5 2.6 7.5 6.5"/>';
  static const plus = '<path d="M12 5v14M5 12h14"/>';
  static const link =
      '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/>'
      '<path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>';
  static const eye =
      '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6S2 12 2 12z"/>'
      '<circle cx="12" cy="12" r="3"/>';
  static const eyeOff = '$eye<path d="M4 4l16 16"/>';
  static const calendar =
      '<rect x="3" y="5" width="18" height="16" rx="3"/>'
      '<path d="M3 10h18M8 3v4M16 3v4"/>';
  static const clock = '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>';
  static const folder =
      '<path d="M4 7a2 2 0 0 1 2-2h5l2 2h5a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/>';
  static const trash = '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>';
  static const edit =
      '<path d="M4 20h4l10-10-4-4L4 16z"/><path d="M12.5 7.5l4 4"/>';
  static const copy =
      '<rect x="9" y="9" width="11" height="11" rx="2.5"/>'
      '<path d="M15 9V6.5A2.5 2.5 0 0 0 12.5 4h-6A2.5 2.5 0 0 0 4 6.5v6A2.5 2.5 0 0 0 6.5 15H9"/>';
  static const import =
      '<rect x="5" y="3" width="14" height="18" rx="3"/>'
      '<path d="M12 8v7M9 12l3 3 3-3"/>';
  static const logout =
      '<path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4"/>'
      '<path d="M14 8l4 4-4 4M18 12H9"/>';
  static const check = '<path d="M5 12l5 5L20 7"/>';
  static const checkCircle =
      '<circle cx="12" cy="12" r="9.5"/><path d="M7.8 12.4l2.9 2.9 5.5-5.9"/>';
  static const externalLink =
      '<path d="M14 4h6v6"/><path d="M20 4l-9 9"/>'
      '<path d="M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"/>';
  static const warning =
      '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.2v.1"/>';
  static const wifiOff =
      '<path d="M12 20h.01"/><path d="M8.5 16.4a5 5 0 0 1 7 0"/>'
      '<path d="M5 12.9a10 10 0 0 1 5.2-2.7"/><path d="M19 12.9a10 10 0 0 0-2-1.5"/>'
      '<path d="M2 8.8a15 15 0 0 1 4.2-2.6"/><path d="M22 8.8a15 15 0 0 0-11.3-3.7"/>'
      '<path d="M2 2l20 20"/>';
  static const offline =
      '<path d="M5 12.5a9 9 0 0 1 14 0M8.5 16a4.5 4.5 0 0 1 7 0M12 19.5v.3"/>'
      '<path d="M4 4l16 16"/>';
  static const arrowUp = '<path d="M12 19V5M6 11l6-6 6 6"/>';
  static const infoCircle =
      '<circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5"/><path d="M12 16.5h.01"/>';
}

/// 16px 붉은 원 안의 느낌표 — 오류 메시지 앞 아이콘.
class DsErrorIcon extends StatelessWidget {
  const DsErrorIcon({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
    '<circle cx="8" cy="8" r="7" fill="#B8432F"/>'
    '<path d="M8 4.5v4M8 11.2v.3" stroke="#FFF" stroke-width="1.8" stroke-linecap="round"/>'
    '</svg>',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// 버터 원 안의 i — 주의 배너(정보) 아이콘.
class DsInfoIcon extends StatelessWidget {
  const DsInfoIcon({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) => SvgPicture.string(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
    '<circle cx="8" cy="8" r="7" fill="#D99A1E"/>'
    '<path d="M8 7.2v4M8 4.6v.3" stroke="#5A3D0E" stroke-width="1.8" stroke-linecap="round"/>'
    '</svg>',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}
