import 'package:flutter/widgets.dart';

import 'zoom_bounce_controller.dart';

/// Makes the active [ZoomBounceController] available to descendants.
///
/// Inserted by the interactive viewer around its child. Editors use it, via
/// [ZoomBounceTarget], to nominate which part of their content should show the
/// elastic feedback.
class ZoomBounceScope extends InheritedNotifier<ZoomBounceController> {
  /// Publishes [controller] to the subtree.
  const ZoomBounceScope({
    required ZoomBounceController super.notifier,
    required super.child,
    super.key,
  });

  /// The controller in scope, or null when the effect is disabled.
  static ZoomBounceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ZoomBounceScope>()
        ?.notifier;
  }
}

/// Applies the elastic zoom overshoot to [child].
///
/// The viewer deliberately does not apply the effect itself. Its child is
/// usually a full-bleed background with the actual page centred inside, and
/// stretching the whole thing makes the editor chrome appear to breathe rather
/// than the page. Wrapping just the page keeps the effect where the user
/// expects it.
///
/// Does nothing when the effect is disabled or no viewer is above it, so it is
/// always safe to include.
class ZoomBounceTarget extends StatelessWidget {
  /// Wraps [child] so it stretches when the zoom is pushed past a limit.
  const ZoomBounceTarget({required this.child, super.key});

  /// The content that should visually stretch — typically the page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bounce = ZoomBounceScope.maybeOf(context);
    if (bounce == null) return child;

    return AnimatedBuilder(
      animation: bounce,
      // Passed through rather than rebuilt, so a settling spring only
      // re-applies a transform instead of rebuilding the content each frame.
      child: child,
      builder: (context, inner) {
        final scale = bounce.scale;

        // Emitted unconditionally, even at rest where it is the identity.
        //
        // Skipping it when there is no overshoot would change the *shape* of
        // the widget tree every time the effect engages or releases. Flutter
        // would then tear down and re-inflate everything below, and the editor
        // keeps its gesture detector down there — its recognizers would be
        // recreated mid-pinch and the gesture dropped, forcing the user to
        // lift and start again.
        return Transform(
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          alignment: bounce.alignment,
          // A pointer's hit-test transform is captured on pointer-down and
          // reused for the rest of that gesture, so transforming hit tests
          // would let a pointer landing mid-bounce carry a stale overshoot for
          // its whole lifetime. Leaving them alone keeps pointers aligned with
          // the committed matrix, which is what the rest of the editor sees.
          transformHitTests: false,
          child: inner,
        );
      },
    );
  }
}
