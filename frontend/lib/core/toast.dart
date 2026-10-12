import 'package:flutter/material.dart';

/// Success / error toasts built on SnackBar.
class Toast {
  Toast._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(String description) {
    _show('Success!', description, isError: false);
  }

  static void error(String description) {
    _show('Something went wrong!', description, isError: true);
  }

  static void _show(String title, String description, {required bool isError}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    final context = messenger.context;
    final scheme = Theme.of(context).colorScheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError ? scheme.errorContainer : scheme.inverseSurface,
          showCloseIcon: true,
          closeIconColor:
              isError ? scheme.onErrorContainer : scheme.onInverseSurface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onInverseSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: isError
                      ? scheme.onErrorContainer
                      : scheme.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      );
  }
}
