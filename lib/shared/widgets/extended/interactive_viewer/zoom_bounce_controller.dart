import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '/core/models/editor_configs/utils/zoom_bounce_configs.dart';

/// How long the handoff between a running spring and a fresh gesture is eased
/// over, so restarting a pinch mid-bounce does not snap.
const Duration _kCarryDuration = Duration(milliseconds: 120);

/// How long a burst of scroll events is allowed to pause before the overshoot
/// settles.
///
/// Long enough to bridge the gap between events in an inertial scroll, short
/// enough that a deliberate second scroll reads as a separate gesture.
const Duration _kWheelDebounce = Duration(milliseconds: 110);

/// How far past a scale limit a gesture may accumulate before its origin is
/// re-anchored.
///
/// Chosen where the rubber band is ~94% saturated: far enough that the stretch
/// looks complete, close enough that the return stroke responds at once.
/// Without it a gesture banks travel that buys no visible stretch but still
/// has to be undone before the zoom moves again, which reads as sticking.
const double kZoomBounceMaxSlackRatio = 1.6;

/// Guards against a nonsensical ratio from a degenerate pinch reaching [log].
const double _kMinRatio = 0.2;
const double _kMaxRatio = 5.0;

/// Maps how far past a scale limit the user has pushed onto how far the view
/// actually stretches, in log space.
///
/// [ratio] is `desiredScale / clampedScale`: `1.0` when the gesture is within
/// range, above `1.0` when pushed past the maximum, below `1.0` when pushed
/// below the minimum. The result is the log of the visual overshoot factor, so
/// `0.0` means no overshoot.
///
/// The curve approaches its limit asymptotically rather than being clipped.
/// A clipped curve tracks the fingers and then stops dead, which reads as the
/// gesture breaking; this one keeps responding — just less and less. It is
/// continuous and differentiable everywhere, monotonic, and its slope at
/// `ratio == 1` is `1 / resistance`, so the very first sliver of overshoot
/// follows the fingers before resistance builds.
///
/// Working in log space makes zooming in and out feel symmetric, because scale
/// composes multiplicatively.
@visibleForTesting
double rubberBandLog(
  double ratio, {
  required double limitIn,
  required double limitOut,
  required double resistance,
}) {
  if (ratio <= 0 || !ratio.isFinite) return 0;

  final x = math.log(ratio.clamp(_kMinRatio, _kMaxRatio));
  if (x == 0) return 0;

  // Each side has its own asymptote.
  final maxLog = math.log(x > 0 ? limitIn : limitOut);
  if (maxLog <= 0) return 0; // limit of exactly 1.0 disables this side.

  final damped = maxLog * (1 - math.exp(-x.abs() / (maxLog * resistance)));
  return x.isNegative ? -damped : damped;
}

/// Drives the visual overshoot shown when the user zooms past a scale limit.
///
/// The value it exposes is deliberately *not* part of the viewer's
/// transformation matrix — it is applied by a separate transform at paint time.
/// That keeps every consumer of the editor's scale (layer placement, helper
/// lines, crop overlays, exports) seeing a value inside the configured limits
/// while the bounce plays.
///
/// Internally the animated quantity is the **log** of the overshoot factor, so
/// `0` means "no overshoot". That composes naturally with [rubberBandLog] and
/// keeps the factor strictly positive no matter what the spring does.
class ZoomBounceController extends ChangeNotifier {
  /// Creates a controller driven by [vsync].
  ZoomBounceController({required TickerProvider vsync, required this.configs})
    : _ctrl = AnimationController.unbounded(vsync: vsync) {
    _ctrl.addListener(notifyListeners);
  }

  /// The active configuration. Replaced when the widget updates.
  ZoomBounceConfigs configs;

  /// Unbounded because [AnimationController.animateWith] clamps to
  /// `[lowerBound, upperBound]`, which would flatten the spring.
  final AnimationController _ctrl;

  Timer? _watchdog;
  Timer? _wheelDebounce;
  double? _wheelDesired;

  Alignment _alignment = Alignment.center;
  bool _hasAlignment = false;

  double _carry = 0;
  Duration? _carryStart;

  /// The visual overshoot factor. `1.0` means no overshoot.
  double get scale => math.exp(_ctrl.value);

  /// Where the overshoot scales from, as a fraction of the target's box.
  ///
  /// Expressed as an [Alignment] rather than a pixel offset so it stays valid
  /// wherever the effect is actually applied — the widget that renders the
  /// overshoot is usually smaller than the viewport the gesture was measured
  /// in.
  Alignment get alignment => _alignment;

  /// Whether an overshoot is currently visible or still settling.
  bool get isActive => _ctrl.value.abs() > 1e-4 || _ctrl.isAnimating;

  /// Feeds the controller the scale the user is asking for versus the scale
  /// the viewer was actually allowed to apply.
  ///
  /// [viewportAlignment] is only adopted while no overshoot is engaged yet;
  /// once the rubber band is stretched the anchor is held for the rest of the
  /// gesture *and* its spring, because a moving anchor under a non-unit scale
  /// visibly jitters.
  void drive({
    required double desiredScale,
    required double clampedScale,
    required Alignment viewportAlignment,
  }) {
    if (!configs.enabled || clampedScale <= 0 || !desiredScale.isFinite) {
      return;
    }

    if (!_hasAlignment || !isActive) {
      _alignment = viewportAlignment;
      _hasAlignment = true;
    }

    var target = rubberBandLog(
      desiredScale / clampedScale,
      limitIn: configs.overshootZoomIn,
      limitOut: configs.overshootZoomOut,
      resistance: configs.resistance,
    );

    // A fresh gesture can begin while a spring is still running — lifting one
    // of two fingers ends and restarts the scale gesture. Ease from wherever
    // the spring got to instead of jumping to the new target.
    final now = _now;
    if (_carryStart == null) {
      _carry = _ctrl.value - target;
      _carryStart = now;
    }
    final elapsed = (now - _carryStart!).inMicroseconds /
        _kCarryDuration.inMicroseconds;
    if (elapsed < 1) {
      target += _carry * (1 - Curves.easeOut.transform(elapsed.clamp(0, 1)));
    }

    // Assigning value stops any running simulation and notifies listeners.
    _ctrl.value = target;

    _armWatchdog();
  }

  /// Feeds the controller from discrete scroll ticks.
  ///
  /// Unlike a pinch, a wheel event carries no cumulative scale — each notch is
  /// an independent multiplication — so the desired scale is accumulated here
  /// and settling is debounced. Without that, a continuous scroll would bounce
  /// once per notch.
  void driveWheel({
    required double currentScale,
    required double scaleChange,
    required double Function(double) clampScale,
    required Alignment viewportAlignment,
  }) {
    if (!configs.enabled) return;

    final desired = (_wheelDesired ?? currentScale) * scaleChange;
    final clamped = clampScale(desired);

    // Cap the accumulated desire at the point where the band is saturated.
    // Anything beyond it adds no visible stretch but still has to be scrolled
    // back through before the zoom responds, which reads as a stuck gesture.
    _wheelDesired = desired.clamp(
      clamped / kZoomBounceMaxSlackRatio,
      clamped * kZoomBounceMaxSlackRatio,
    );

    drive(
      desiredScale: _wheelDesired!,
      clampedScale: clamped,
      viewportAlignment: viewportAlignment,
    );

    // Back in range: drop the accumulator so a scroll out and back does not
    // leave a stale bias.
    if ((_wheelDesired! - clamped).abs() < 1e-9) _wheelDesired = null;

    _wheelDebounce?.cancel();
    _wheelDebounce = Timer(_kWheelDebounce, () {
      _wheelDesired = null;
      settle();
    });
  }

  /// Springs the overshoot back to rest.
  void settle() {
    _watchdog?.cancel();
    _watchdog = null;
    _carryStart = null;
    _carry = 0;

    if (_ctrl.value == 0) return;

    _ctrl.animateWith(
      SpringSimulation(
        configs.spring ?? ZoomBounceConfigs.defaultSpring,
        _ctrl.value,
        0,
        0,
      ),
    );
  }

  /// Removes the overshoot immediately, without animating.
  ///
  /// Used when the transform is being set explicitly — a spring that kept
  /// running would animate a stale overshoot over freshly-reset content, and
  /// could still be moving when a snapshot is taken.
  void cancel() {
    _watchdog?.cancel();
    _watchdog = null;
    _wheelDebounce?.cancel();
    _wheelDebounce = null;
    _wheelDesired = null;
    _carryStart = null;
    _carry = 0;
    _hasAlignment = false;

    _ctrl.stop(canceled: true);
    // Notifies synchronously, so the repaint lands in the current frame.
    if (_ctrl.value != 0) _ctrl.value = 0;
  }

  /// Settles on its own if updates stop arriving while stretched.
  ///
  /// The viewer is not reliably told when a gesture ends: the main editor only
  /// forwards `onScaleEnd` under some conditions, and the gesture arena can
  /// cancel a pointer outright. Without this the overshoot could stay frozen.
  void _armWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(configs.settleWatchdog, settle);
  }

  Duration get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp;

  @override
  void dispose() {
    _watchdog?.cancel();
    _wheelDebounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }
}
