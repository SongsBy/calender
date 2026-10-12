import 'package:flutter/material.dart';

import '../../shared/appearance_menu.dart';
import '../../shared/widgets.dart';

/// Two-column auth layout: logo panel on wide screens, form + footer on
/// the right.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final form = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [AppearanceButton()],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AutofillGroup(child: child),
              ),
            ),
          ),
        ),
        const AppFooter(),
      ],
    );

    if (!isWide) {
      return Scaffold(body: SafeArea(child: form));
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF18181B) : theme.colorScheme.secondary,
              alignment: Alignment.center,
              child: const AppLogo(height: 64),
            ),
          ),
          Expanded(child: form),
        ],
      ),
    );
  }
}

/// Heading used at the top of each auth form.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

/// "Don't have an account? Sign up" style footer line.
class AuthLinkLine extends StatelessWidget {
  const AuthLinkLine({
    super.key,
    required this.text,
    required this.linkText,
    required this.onTap,
  });

  final String text;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(text, style: style),
        InkWell(
          onTap: onTap,
          child: Text(
            linkText,
            style: style?.copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}
