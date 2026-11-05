import 'package:flutter/material.dart';

class LoadingHelper {
  static DialogRoute<void>? _route;
  static NavigatorState? _navigator;

  static void show(BuildContext context, {String message = 'Memproses...'}) {
    if (_route != null) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    _route = route;
    _navigator = navigator;
    navigator.push(route).whenComplete(() {
      if (identical(_route, route)) {
        _route = null;
        _navigator = null;
      }
    });
  }

  static void hide(BuildContext context) {
    final route = _route;
    final navigator = _navigator;
    _route = null;
    _navigator = null;
    if (route != null &&
        route.isActive &&
        navigator != null &&
        navigator.mounted) {
      navigator.removeRoute(route);
    }
  }
}
