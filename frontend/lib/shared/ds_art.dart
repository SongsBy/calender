import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

Widget _svg(
  String body,
  double w,
  double h, {
  String? label,
}) => SvgPicture.string(
  '<svg xmlns="http://www.w3.org/2000/svg" width="$w" height="$h" $body</svg>',
  width: w,
  height: h,
  semanticsLabel: label,
  excludeFromSemantics: label == null,
);

/// 로고 마크 · 기본 168×120 — 서로를 바라보는 두 얼굴과 겹치는 하루.
class DsLogo extends StatelessWidget {
  const DsLogo({super.key, this.width = 168});
  final double width;

  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 168 120">'
    '<defs><clipPath id="lg-lens"><circle cx="104" cy="62" r="42"/></clipPath></defs>'
    '<circle cx="64" cy="62" r="46" fill="#FFFDF8" stroke="#EFE2C8" stroke-width="1.5"/>'
    '<circle cx="104" cy="62" r="46" fill="#FFFDF8" stroke="#EFE2C8" stroke-width="1.5"/>'
    '<circle cx="104" cy="62" r="42" fill="#FFC9D4"/>'
    '<circle cx="64" cy="62" r="42" fill="#F6C445"/>'
    '<circle cx="64" cy="62" r="42" fill="#F9BE8A" clip-path="url(#lg-lens)"/>'
    '<ellipse cx="46" cy="40" rx="12" ry="6.5" fill="#FFFDF8" opacity=".45" transform="rotate(-32 46 40)"/>'
    '<ellipse cx="122" cy="40" rx="12" ry="6.5" fill="#FFFDF8" opacity=".55" transform="rotate(32 122 40)"/>'
    '<circle cx="42" cy="58" r="3.2" fill="#3F2616"/><circle cx="56" cy="56" r="3.2" fill="#3F2616"/>'
    '<path d="M41 69q8 11 16 2" fill="none" stroke="#3F2616" stroke-width="2.8" stroke-linecap="round"/>'
    '<circle cx="34" cy="69" r="3.4" fill="#F39BB0" opacity=".85"/>'
    '<circle cx="112" cy="56" r="3.2" fill="#3F2616"/><circle cx="126" cy="58" r="3.2" fill="#3F2616"/>'
    '<path d="M111 71q8 9 16-2" fill="none" stroke="#3F2616" stroke-width="2.8" stroke-linecap="round"/>'
    '<circle cx="134" cy="69" r="3.4" fill="#E8869E" opacity=".85"/>'
    '<path d="M84 50l2.7 7.3 7.3 2.7-7.3 2.7L84 70l-2.7-7.3L74 60l7.3-2.7z" fill="#FFFDF8"/>',
    width,
    width * 120 / 168,
    label: 'CC 로고: 서로를 바라보는 두 얼굴과 겹치는 하루',
  );
}

/// 로고 마크 · 축약 52×36 (테·볼터치·바깥 스파클 없음).
class DsLogoSmall extends StatelessWidget {
  const DsLogoSmall({super.key, this.width = 52});
  final double width;

  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 52 36">'
    '<defs><clipPath id="lg-lens-s"><circle cx="33" cy="18" r="14"/></clipPath></defs>'
    '<circle cx="33" cy="18" r="14" fill="#FFC9D4"/>'
    '<circle cx="19" cy="18" r="14" fill="#F6C445"/>'
    '<circle cx="19" cy="18" r="14" fill="#F9BE8A" clip-path="url(#lg-lens-s)"/>'
    '<circle cx="11" cy="17" r="1.5" fill="#3F2616"/><circle cx="16.5" cy="16.5" r="1.5" fill="#3F2616"/>'
    '<path d="M11 21.5q4 5 7.5 1" fill="none" stroke="#3F2616" stroke-width="1.6" stroke-linecap="round"/>'
    '<circle cx="35.5" cy="16.5" r="1.5" fill="#3F2616"/><circle cx="41" cy="17" r="1.5" fill="#3F2616"/>'
    '<path d="M33.5 22.5q4 4 7.5-1" fill="none" stroke="#3F2616" stroke-width="1.6" stroke-linecap="round"/>'
    '<path d="M26 13.5l1.2 3.3 3.3 1.2-3.3 1.2-1.2 3.3-1.2-3.3-3.3-1.2 3.3-1.2z" fill="#FFFDF8"/>',
    width,
    width * 36 / 52,
    label: 'CC 로고',
  );
}

/// 미소 (단일) · 44~64px · 앱바 로고 · 안내 화면 · 아바타.
class DsSmile extends StatelessWidget {
  const DsSmile({
    super.key,
    this.size = 64,
    this.color = AppColors.butter,
    this.flat = false,
    this.blush = false,
  });
  final double size;
  final Color color;

  /// 입을 일자로 — ‘찾지 못했어요’ 류의 갸웃한 표정.
  final bool flat;

  /// 볼터치 (계정 아바타).
  final bool blush;

  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 44 44">'
    '<circle cx="22" cy="22" r="20" fill="${_hex(color)}"/>'
    '<circle cx="15.5" cy="19" r="1.9" fill="#3F2616"/><circle cx="28.5" cy="19" r="1.9" fill="#3F2616"/>'
    '${flat ? '<path d="M16 27h12" fill="none" stroke="#3F2616" stroke-width="2" stroke-linecap="round"/>' : '<path d="M15 25.5c2 3 4.4 4.5 7 4.5s5-1.5 7-4.5" fill="none" stroke="#3F2616" stroke-width="2" stroke-linecap="round"/>'}'
    '${blush ? '<circle cx="11" cy="25" r="1.8" fill="#F39BB0"/><circle cx="33" cy="25" r="1.8" fill="#F39BB0"/>' : ''}',
    size,
    size,
    label: '웃는 얼굴',
  );
}

/// 계정 시트 아바타 (버터 원 + 볼터치 얼굴, 52px).
class DsAvatar extends StatelessWidget {
  const DsAvatar({super.key, this.size = 52});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: AppColors.butter,
      shape: BoxShape.circle,
    ),
    alignment: Alignment.center,
    child: _svg(
      'viewBox="0 0 30 30">'
      '<circle cx="10.5" cy="12" r="1.9" fill="#3F2616"/><circle cx="19.5" cy="12" r="1.9" fill="#3F2616"/>'
      '<path d="M10 17.5c1.6 2.6 3.3 3.9 5 3.9s3.4-1.3 5-3.9" fill="none" stroke="#3F2616" stroke-width="2" stroke-linecap="round"/>'
      '<circle cx="6.5" cy="17" r="1.6" fill="#F39BB0"/><circle cx="23.5" cy="17" r="1.6" fill="#F39BB0"/>',
      size * 30 / 52,
      size * 30 / 52,
    ),
  );
}

/// 빈 화면 일러스트 168×128 — 웃는 두 얼굴과 빈 달력. `sad`면 한 얼굴만 갸웃.
class DsEmptyCalendarArt extends StatelessWidget {
  const DsEmptyCalendarArt({super.key, this.width = 168, this.sad = false});
  final double width;
  final bool sad;

  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 168 128">'
    '<rect x="34" y="30" width="100" height="84" rx="18" fill="#FFFDF8" stroke="#E6D6BA" stroke-width="2"/>'
    '<rect x="34" y="30" width="100" height="22" rx="18" fill="#F6C445"/>'
    '<rect x="34" y="42" width="100" height="10" fill="#F6C445"/>'
    '<path d="M52 62h12M78 62h12M104 62h12M52 80h12M78 80h12M104 80h12M52 98h12M78 98h12" stroke="#EADCC4" stroke-width="5" stroke-linecap="round"/>'
    '<circle cx="30" cy="96" r="24" fill="#F6C445"/>'
    '<circle cx="22" cy="92" r="2.2" fill="#3F2616"/><circle cx="38" cy="92" r="2.2" fill="#3F2616"/>'
    '${sad ? '<path d="M24 102h12" fill="none" stroke="#3F2616" stroke-width="2.2" stroke-linecap="round"/>' : '<path d="M23 100c2.2 3.2 4.6 4.8 7 4.8s4.8-1.6 7-4.8" fill="none" stroke="#3F2616" stroke-width="2.2" stroke-linecap="round"/>'
              '<circle cx="138" cy="96" r="24" fill="#FFC9D4"/>'
              '<circle cx="130" cy="92" r="2.2" fill="#3F2616"/><circle cx="146" cy="92" r="2.2" fill="#3F2616"/>'
              '<path d="M131 100c2.2 3.2 4.6 4.8 7 4.8s4.8-1.6 7-4.8" fill="none" stroke="#3F2616" stroke-width="2.2" stroke-linecap="round"/>'}',
    width,
    width * 128 / 168,
    label: sad ? '비어 있는 달력과 고개를 갸웃하는 얼굴' : '웃는 두 얼굴과 빈 달력',
  );
}

/// 가져오기 안내 일러스트 140×100 — 휴대폰의 일정이 달력으로 복사되는 그림.
class DsImportArt extends StatelessWidget {
  const DsImportArt({super.key, this.width = 140});
  final double width;
  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 140 100">'
    '<rect x="10" y="12" width="38" height="76" rx="10" fill="#FFFDF8" stroke="#3F2616" stroke-width="2.5"/>'
    '<path d="M24 20h10" fill="none" stroke="#3F2616" stroke-width="2" stroke-linecap="round"/>'
    '<path d="M19 38h20M19 52h20M19 66h12" fill="none" stroke="#F6C445" stroke-width="5" stroke-linecap="round"/>'
    '<path d="M58 50h22M73 41l9 9-9 9" fill="none" stroke="#3F2616" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>'
    '<rect x="90" y="24" width="42" height="56" rx="10" fill="#FFFDF8"/>'
    '<path d="M90 38v-4a10 10 0 0 1 10-10h22a10 10 0 0 1 10 10v4z" fill="#FFC9D4"/>'
    '<rect x="90" y="24" width="42" height="56" rx="10" fill="none" stroke="#3F2616" stroke-width="2.5"/>'
    '<path d="M90 38h42" fill="none" stroke="#3F2616" stroke-width="2"/>'
    '<path d="M100 19v8M122 19v8" fill="none" stroke="#3F2616" stroke-width="2.5" stroke-linecap="round"/>'
    '<circle cx="111" cy="59" r="10" fill="#F6C445"/>'
    '<path d="M106 59l3.6 3.6 6.4-7" fill="none" stroke="#3F2616" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    width,
    width * 100 / 140,
    label: '휴대폰의 일정이 달력으로 복사되는 그림',
  );
}

/// 물결선 96×10 — 구분선 대용.
class DsWave extends StatelessWidget {
  const DsWave({super.key, this.width = 96});
  final double width;
  @override
  Widget build(BuildContext context) => _svg(
    'viewBox="0 0 96 10">'
    '<path d="M2 5c6-5 10 5 16 0s10 5 16 0 10 5 16 0 10 5 16 0 10 5 14 0" fill="none" stroke="#E9A823" stroke-width="2" stroke-linecap="round"/>',
    width,
    width * 10 / 96,
  );
}
