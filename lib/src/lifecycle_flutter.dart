import 'package:flutter/widgets.dart';

void listenToLifecycle({void Function()? onBackground, void Function()? onForeground}) {
  final binding = WidgetsBinding.instance;
  binding.addObserver(_CountlyLifecycleObserver(onBackground, onForeground));
}

class _CountlyLifecycleObserver extends WidgetsBindingObserver {
  final void Function()? onBackground;
  final void Function()? onForeground;
  _CountlyLifecycleObserver(this.onBackground, this.onForeground);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onBackground?.call();
        break;
      case AppLifecycleState.resumed:
        onForeground?.call();
        break;
    }
  }
}
