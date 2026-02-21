import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

typedef _LifecycleCallback = void Function();

final List<_LifecycleCallback> _backgroundListeners = [];
final List<_LifecycleCallback> _foregroundListeners = [];

/// Returns a dispose function that removes the observer and callbacks.
void Function() listenToLifecycle({void Function()? onBackground, void Function()? onForeground}) {
  final binding = WidgetsBinding.instance;
  final observer = _CountlyLifecycleObserver(onBackground, onForeground);
  binding.addObserver(observer);
  if (onBackground != null) _backgroundListeners.add(onBackground);
  if (onForeground != null) _foregroundListeners.add(onForeground);

  return () {
    binding.removeObserver(observer);
    if (onBackground != null) _backgroundListeners.remove(onBackground);
    if (onForeground != null) _foregroundListeners.remove(onForeground);
  };
}

/// Test-only: simulate app moving to background.
@visibleForTesting
void simulateBackground() {
  for (final cb in List<_LifecycleCallback>.from(_backgroundListeners)) {
    try {
      cb();
    } catch (_) {}
  }
}

/// Test-only: simulate app moving to foreground.
@visibleForTesting
void simulateForeground() {
  for (final cb in List<_LifecycleCallback>.from(_foregroundListeners)) {
    try {
      cb();
    } catch (_) {}
  }
}

/// Test-only: clear any registered lifecycle listeners.
@visibleForTesting
void clearLifecycleListeners() {
  _backgroundListeners.clear();
  _foregroundListeners.clear();
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
