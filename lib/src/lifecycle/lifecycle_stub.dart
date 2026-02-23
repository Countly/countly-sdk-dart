import 'package:meta/meta.dart';

// Pure dart stub with test hooks
typedef _LifecycleCallback = void Function();

final List<_LifecycleCallback> _backgroundListeners = [];
final List<_LifecycleCallback> _foregroundListeners = [];

/// Returns a dispose function that removes the callbacks.
void Function() listenToLifecycle({void Function()? onBackground, void Function()? onForeground}) {
  if (onBackground != null) _backgroundListeners.add(onBackground);
  if (onForeground != null) _foregroundListeners.add(onForeground);

  return () {
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
