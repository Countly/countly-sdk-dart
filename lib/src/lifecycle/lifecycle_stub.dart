import 'package:meta/meta.dart';

// Pure dart stub with test hooks
typedef _LifecycleCallback = void Function();

final List<_LifecycleCallback> _backgroundListeners = [];
final List<_LifecycleCallback> _foregroundListeners = [];

void listenToLifecycle({void Function()? onBackground, void Function()? onForeground}) {
  if (onBackground != null) _backgroundListeners.add(onBackground);
  if (onForeground != null) _foregroundListeners.add(onForeground);
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
