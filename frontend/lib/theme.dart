import 'package:flutter/material.dart';

/// 디자인 토큰 — "우리의 하루" 디자인 시스템 (DS-Tokens 보드)의 값을 그대로 옮겼습니다.
/// 모든 값은 px(logical pixel) 기준입니다.
class AppColors {
  AppColors._();

  // 배경 · 표면
  static const cream = Color(
    0xFFFFFFFF,
  ); // scaffoldBackground / surface (화이트로 변경)
  static const surface = Color(0xFFFFFDF8); // 카드 Surface
  static const fillDisabled = Color(0xFFF3EADA); // 비활성 입력 배경
  static const skeleton = Color(0xFFF1E6D2);
  static const codeBackground = Color(0xFFF7EEDC);
  static const keyboardArea = Color(0xFFF7EFDF);
  static const outline = Color(0xFFE6D6BA); // 입력·보조 버튼 1.5px
  static const outlineVariant = Color(0xFFF1E4CC); // 카드 1px / 구분선
  static const ring = Color(0xFFEFE2C8); // 로고 크림 테

  // 버터 (Primary)
  static const butter = Color(0xFFF6C445);
  static const butterPressed = Color(0xFFE3AF2E);
  static const butterDeep = Color(0xFFD99A1E); // 포커스 테두리 · accent · 스파클
  static const butterContainer = Color(0xFFFFF0BF); // ‘나’ 칩 배경
  static const me = Color(0xFFE9A823); // 참여자 · 나
  static const onButterContainer = Color(0xFF5A3D0E);

  // 핑크 (Secondary)
  static const pink = Color(0xFFFFC9D4);
  static const pinkContainer = Color(0xFFFFE0E7); // ‘상대’ 칩 배경
  static const partner = Color(0xFFD4617E); // 참여자 · 상대
  static const onPinkContainer = Color(0xFF7A2E42);
  static const blush = Color(0xFFF39BB0);
  static const wordmark = Color(0xFFE99CBC); // 로고 핑크
  static const blushPartner = Color(0xFFE8869E);
  static const peach = Color(0xFFF9BE8A);
  static const dashed = Color(0xFFD9C5A3);

  // 브라운 (텍스트)
  static const brown900 = Color(0xFF3F2616); // onSurface
  static const brown700 = Color(0xFF5C3D2B); // onSurfaceVariant
  static const brown500 = Color(0xFF7A5A47); // 캡션
  static const placeholder = Color(0xFF8A6E5C);
  static const disabledText = Color(0xFF8A7260);
  static const otherMonth = Color(0xFFB9A58F);

  // 위험 (Error)
  static const error = Color(0xFFB8432F);
  static const errorPressed = Color(0xFF9A3524);
  static const errorText = Color(0xFF9A3524);
  static const errorContainer = Color(0xFFFDE8E4);
  static const errorBorder = Color(0xFFF5C9C0);
  static const onErrorContainer = Color(0xFF8F2E1E);

  // 성공 · 주의
  static const success = Color(0xFF3E8E62);
  static const successContainer = Color(0xFFE3F3E9);
  static const successBorder = Color(0xFFBFE3CD);
  static const onSuccessContainer = Color(0xFF245B3D);
  static const warnContainer = Color(0xFFFFF3CF);
  static const warnBorder = Color(0xFFF3DD9A);
  static const onWarnContainer = Color(0xFF5A3D0E);

  // 기타
  static const secondaryPressed = Color(0xFFF5EBD6);
  static const scrim = Color(0x663F2616); // rgba(63,38,22,.40)
  static const focusRing = Color(0x61F6C445); // rgba(246,196,69,.38)
  static const errorRing = Color(0x24B8432F); // rgba(184,67,47,.14)
  static const cardShadow = Color(0x147A5A47); // rgba(122,90,71,.08)
  static const floatShadow = Color(0x2E7A5A47); // rgba(122,90,71,.18)
  static const snackShadow = Color(0x403F2616); // rgba(63,38,22,.25)
}

/// 간격 토큰 (4px 기본 단위).
class AppSpace {
  AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double card = 18;
  static const double screen = 24;
  static const double appBar = 56;
}

/// 모서리 토큰 — 바깥 요소가 안쪽 요소보다 항상 더 둥글게.
class AppRadius {
  AppRadius._();
  static const double small = 12;
  static const double input = 16;
  static const double button = 18;
  static const double eventCard = 18;
  static const double tile = 22;
  static const double card = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

FontWeight _weight(int w) => switch (w) {
  <= 100 => FontWeight.w100,
  <= 200 => FontWeight.w200,
  <= 300 => FontWeight.w300,
  <= 400 => FontWeight.w400,
  <= 500 => FontWeight.w500,
  <= 600 => FontWeight.w600,
  <= 700 => FontWeight.w700,
  <= 800 => FontWeight.w800,
  _ => FontWeight.w900,
};

/// Pretendard(가변 폰트) 텍스트 스타일. `weight`는 45–920 wght 축 값입니다.
TextStyle ds(
  double size, {
  int weight = 400,
  Color color = AppColors.brown900,
  double? height,
  double letterSpacing = 0,
  bool tabular = false,
}) => TextStyle(
  fontFamily: 'Pretendard',
  fontSize: size,
  fontWeight: _weight(weight),
  fontVariations: [FontVariation('wght', weight.toDouble())],
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
);

/// 디자인 시스템의 타이포 스케일.
class AppText {
  AppText._();

  /// Display · 30/38 · 800 · 자간 −1 · 로그인 워드마크
  static TextStyle get display =>
      ds(30, weight: 800, letterSpacing: -1, height: 38 / 30);

  /// Headline · 26/34 · 700 · 메인 인사말
  static TextStyle get headline =>
      ds(26, weight: 700, letterSpacing: -0.4, height: 34 / 26);

  /// Title · 20/26 · 700 · 앱바·카드 제목·월 표시
  static TextStyle get title =>
      ds(20, weight: 700, letterSpacing: -0.4, height: 26 / 20);

  /// Body Strong · 16/22 · 600 · 일정 제목, 버튼
  static TextStyle get bodyStrong => ds(16, weight: 600, height: 22 / 16);

  /// Body · 16/24 · 400 · 입력값
  static TextStyle get body => ds(16, height: 1.5);

  /// Body Small · 14.5/22 · 다이얼로그 본문
  static TextStyle get bodySmall =>
      ds(14.5, color: AppColors.brown700, height: 22 / 14.5);

  /// Calendar Number · 14/18 · 500 · tabular
  static TextStyle get calendarNumber =>
      ds(14, weight: 500, height: 18 / 14, tabular: true);

  /// Label · 13/18 · 600 · #5C3D2B
  static TextStyle get label =>
      ds(13, weight: 600, color: AppColors.brown700, height: 18 / 13);

  /// Caption · 12.5/18 · 400 · #7A5A47
  static TextStyle get caption =>
      ds(12.5, color: AppColors.brown500, height: 1.45);

  /// 워드마크 · Yellowtail(브러시 스크립트) · 로그인 로고 아래 앱 이름
  static TextStyle get wordmark => const TextStyle(
    fontFamily: 'Yellowtail',
    fontSize: 52,
    height: 1.1,
    color: AppColors.wordmark,
  );

  /// Accent · 15 · 500 · 로그인 하단 한 줄
  static TextStyle get accent =>
      ds(15, weight: 500, color: AppColors.brown500, letterSpacing: -0.2);
}

/// 크림 바탕 위 버터 옐로 + 브라운 본문의 라이트 테마.
class AppTheme {
  AppTheme._();

  static const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.butter,
    onPrimary: AppColors.brown900,
    primaryContainer: AppColors.butterContainer,
    onPrimaryContainer: AppColors.onButterContainer,
    secondary: AppColors.pink,
    onSecondary: AppColors.brown900,
    secondaryContainer: AppColors.pinkContainer,
    onSecondaryContainer: AppColors.onPinkContainer,
    tertiary: AppColors.success,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.successContainer,
    onTertiaryContainer: AppColors.onSuccessContainer,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.cream,
    onSurface: AppColors.brown900,
    onSurfaceVariant: AppColors.brown700,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.cream,
    surfaceContainerHigh: AppColors.fillDisabled,
    surfaceContainerHighest: AppColors.skeleton,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    shadow: AppColors.brown900,
    scrim: AppColors.scrim,
    inverseSurface: AppColors.brown900,
    onInverseSurface: AppColors.cream,
    inversePrimary: AppColors.butter,
    surfaceTint: Colors.transparent,
  );

  static ThemeData light() {
    final textTheme = TextTheme(
      displaySmall: AppText.display,
      headlineSmall: AppText.headline,
      headlineMedium: ds(28, weight: 700, letterSpacing: -0.4, height: 1.3),
      titleLarge: AppText.title,
      titleMedium: AppText.bodyStrong,
      titleSmall: ds(15, weight: 600, height: 1.35),
      bodyLarge: AppText.body,
      bodyMedium: AppText.bodySmall,
      bodySmall: AppText.caption,
      labelLarge: AppText.calendarNumber,
      labelMedium: AppText.label,
      labelSmall: ds(12, weight: 600, color: AppColors.brown500),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      fontFamily: 'Pretendard',
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,
      dividerColor: AppColors.outlineVariant,
      splashFactory: NoSplash.splashFactory,
      highlightColor: AppColors.secondaryPressed,
      splashColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.brown900, size: 24),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.brown900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(AppText.bodyStrong),
          foregroundColor: const WidgetStatePropertyAll(AppColors.brown900),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? AppColors.butterPressed
                : AppColors.butter,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(AppText.bodyStrong),
          foregroundColor: const WidgetStatePropertyAll(AppColors.brown900),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline, width: 1.5),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? AppColors.secondaryPressed
                : AppColors.surface,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          shape: WidgetStatePropertyAll(buttonShape),
          textStyle: WidgetStatePropertyAll(AppText.bodyStrong),
          foregroundColor: const WidgetStatePropertyAll(AppColors.brown700),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? AppColors.secondaryPressed
                : Colors.transparent,
          ),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: AppText.body.copyWith(color: AppColors.placeholder),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outline, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.butterDeep, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        titleTextStyle: ds(21, weight: 700, height: 1.3),
        contentTextStyle: AppText.bodySmall,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brown900,
        contentTextStyle: ds(14, color: AppColors.cream),
        actionTextColor: AppColors.butter,
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.butter
              : AppColors.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.butter
              : AppColors.surface,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.brown900),
        side: const BorderSide(color: AppColors.dashed, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.butterDeep
              : AppColors.dashed,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.butterContainer,
        headerForegroundColor: AppColors.brown900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.cream
              : AppColors.brown900,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.brown900
              : Colors.transparent,
        ),
        todayForegroundColor: const WidgetStatePropertyAll(AppColors.brown900),
        todayBackgroundColor: const WidgetStatePropertyAll(AppColors.butter),
        todayBorder: BorderSide.none,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.butterContainer
              : AppColors.cream,
        ),
        hourMinuteTextColor: AppColors.brown900,
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.butter
              : AppColors.cream,
        ),
        dayPeriodTextColor: AppColors.brown900,
        dialHandColor: AppColors.butter,
        dialBackgroundColor: AppColors.cream,
        dialTextColor: AppColors.brown900,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brown900,
        linearTrackColor: AppColors.skeleton,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.brown900,
        iconColor: AppColors.brown700,
      ),
    );
  }
}
