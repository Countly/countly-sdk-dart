// Toast for Flutter warnings & errors
import 'package:flutter/material.dart';
import 'dart:collection';

const bool sdkToastAvailable = true;

// Queue and show toasts when Overlay is available
final Queue<String> _pendingToasts = Queue<String>();
bool _willShow = false;
const int _maxQueue = 20;

// SDK method
void showSdkToast(String message) {
  if (_pendingToasts.length >= _maxQueue) {
    _pendingToasts.removeFirst();
  }

  final overlay = _locateOverlay();

  if (overlay == null) {
    _pendingToasts.add(message);
    _scheduleDrain();
    return;
  }

  _insertToast(overlay, message);
}

void _insertToast(OverlayState overlay, String message) {
  final entry = OverlayEntry(builder: (_) => _SdkToastWidget(message: message));
  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3)).then((_) {
    try {
      entry.remove();
    } catch (_) {}
  });
}

void _scheduleDrain() {
  if (_willShow) return;
  _willShow = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _willShow = false;
    _drainQueue();
  });
}

void _drainQueue() {
  if (_pendingToasts.isEmpty) return;
  final overlay = _locateOverlay();
  if (overlay == null) {
    _scheduleDrain();
    return;
  }
  while (_pendingToasts.isNotEmpty) {
    _insertToast(overlay, _pendingToasts.removeFirst());
  }
}

OverlayState? _locateOverlay() {
  final root = WidgetsBinding.instance.renderViewElement;
  if (root == null) {
    return null;
  }
  OverlayState? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.widget is Overlay) {
      final state = (e as StatefulElement).state;
      if (state is OverlayState) {
        found = state;
        return;
      }
    }
    e.visitChildren(visit);
  }

  root.visitChildren(visit);
  return found;
}

class _SdkToastWidget extends StatelessWidget {
  final String message;
  const _SdkToastWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    String text = message;
    if (text.startsWith('!!!!!')) {
      text = text.replaceFirst('!!!!!', '').trim();
    }

    final bgColor = Colors.redAccent;
    final fontSize = 16.0;
    final fontWeight = FontWeight.w600;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 1)),
              child: DefaultTextStyle(
                  style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: fontWeight, height: 1.2),
                  child: Text('[Countly] $text', maxLines: 5, overflow: TextOverflow.ellipsis)),
            ),
          ),
        ),
      ),
    );
  }
}
