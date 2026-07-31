import 'package:flutter/physics.dart';

/// Configuration for the elastic rubber-band feedback shown when the user
/// zooms past the editor's scale limits.
///
/// Without this the zoom stops dead at [ZoomConfigs.editorMinScale] and
/// [ZoomConfigs.editorMaxScale], which reads as a broken gesture rather than a
/// boundary. When enabled, pushing past a limit resists progressively and then
/// springs back on release.
///
/// The overshoot is **purely visual**: it is rendered by a separate transform
/// and never enters the viewer's transformation matrix. Everything that reads
/// the editor's scale — layer placement, helper lines, crop overlays, exports —
/// continues to see a value inside the configured limits.
///
/// Disabled by default, so existing behaviour is unchanged unless opted in.
class ZoomBounceConfigs {
  /// Creates the elastic zoom feedback configuration.
  const ZoomBounceConfigs({
    this.enabled = false,
    this.overshootZoomIn = 1.18,
    this.overshootZoomOut = 1.12,
    this.resistance = 1.0,
    this.spring,
    this.settleWatchdog = const Duration(milliseconds: 240),
  }) : assert(
         overshootZoomIn >= 1.0,
         'overshootZoomIn is a factor past the maximum scale and cannot be '
         'below 1.0. Use exactly 1.0 to disable the zoom-in side.',
       ),
       assert(
         overshootZoomOut >= 1.0,
         'overshootZoomOut is a factor below the minimum scale, expressed as a '
         'value >= 1.0. Use exactly 1.0 to disable the zoom-out side.',
       ),
       assert(resistance > 0, 'resistance must be greater than zero.');

  /// Whether the elastic feedback is active.
  ///
  /// Defaults to `false`, which reproduces the previous hard-clamped zoom
  /// exactly.
  final bool enabled;

  /// How far past the maximum scale the view may stretch, as a factor.
  ///
  /// `1.18` allows the content to grow a further 18% beyond
  /// [ZoomConfigs.editorMaxScale] at full resistance. The value is an
  /// asymptote, not a cap that is reached abruptly — see [resistance].
  ///
  /// Set to exactly `1.0` to disable the zoom-in side.
  final double overshootZoomIn;

  /// How far below the minimum scale the view may shrink, expressed as a
  /// factor `>= 1.0`.
  ///
  /// `1.12` allows the content to shrink to roughly `1 / 1.12` of the minimum
  /// scale. Slightly tighter than [overshootZoomIn] because a shrinking canvas
  /// reveals background and reads as heavier.
  ///
  /// Set to exactly `1.0` to disable the zoom-out side.
  final double overshootZoomOut;

  /// How stiff the rubber band feels from the first moment of overshoot.
  ///
  /// `1.0` tracks the pinch one-to-one at the very start and then resists
  /// progressively. Higher values resist sooner; `1.6` roughly halves the
  /// initial response while keeping the same limits.
  final double resistance;

  /// The spring used to settle back to the limit when the gesture ends.
  ///
  /// Defaults to [defaultSpring] when null.
  final SpringDescription? spring;

  /// How long the overshoot may go without an update before settling on its
  /// own.
  ///
  /// A gesture can end without the viewer being told — the main editor only
  /// forwards `onScaleEnd` under certain conditions, and the gesture arena can
  /// cancel a pointer outright. Without this the overshoot would stay frozen.
  final Duration settleWatchdog;

  /// The default settle spring: one clearly visible bounce, settling in
  /// roughly 400ms.
  ///
  /// A damping ratio of `0.58` undershoots by about 11% of the displacement
  /// once before landing. Ratios below ~0.4 oscillate several times and read
  /// as wobbly; `1.0` removes the bounce entirely.
  static final SpringDescription defaultSpring =
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: 400,
        ratio: 0.58,
      );

  // Value equality matters here: the viewer recreates its controller when the
  // configuration changes, and a caller passing a fresh (non-const) instance
  // on every rebuild would otherwise churn it continuously.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ZoomBounceConfigs &&
        other.enabled == enabled &&
        other.overshootZoomIn == overshootZoomIn &&
        other.overshootZoomOut == overshootZoomOut &&
        other.resistance == resistance &&
        other.spring == spring &&
        other.settleWatchdog == settleWatchdog;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    overshootZoomIn,
    overshootZoomOut,
    resistance,
    spring,
    settleWatchdog,
  );

  /// Creates a copy of this configuration with the given fields replaced.
  ZoomBounceConfigs copyWith({
    bool? enabled,
    double? overshootZoomIn,
    double? overshootZoomOut,
    double? resistance,
    SpringDescription? spring,
    Duration? settleWatchdog,
  }) {
    return ZoomBounceConfigs(
      enabled: enabled ?? this.enabled,
      overshootZoomIn: overshootZoomIn ?? this.overshootZoomIn,
      overshootZoomOut: overshootZoomOut ?? this.overshootZoomOut,
      resistance: resistance ?? this.resistance,
      spring: spring ?? this.spring,
      settleWatchdog: settleWatchdog ?? this.settleWatchdog,
    );
  }
}
