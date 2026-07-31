import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/core/models/editor_configs/main_editor_configs.dart';
import 'package:pro_image_editor/core/models/editor_configs/utils/zoom_bounce_configs.dart';
import 'package:pro_image_editor/shared/widgets/extended/interactive_viewer/extended_interactive_viewer.dart';
import 'package:pro_image_editor/shared/widgets/extended/interactive_viewer/extended_raw_interactive_viewer.dart';
import 'package:pro_image_editor/shared/widgets/extended/interactive_viewer/zoom_bounce_target.dart';

const _maxScale = 2.0;
const _viewerSize = 300.0;

final _viewerKey = GlobalKey<ExtendedInteractiveViewerState>();
final _pageKey = GlobalKey();

Widget buildViewer({
  required bool bounceEnabled,
  bool withTarget = true,
  bool probe = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: _viewerSize,
          height: _viewerSize,
          child: ExtendedInteractiveViewer(
            key: _viewerKey,
            zoomConfigs: MainEditorConfigs(
              enableZoom: true,
              editorMaxScale: _maxScale,
              zoomBounce: ZoomBounceConfigs(enabled: bounceEnabled),
            ),
            onInteractionStart: (_) {},
            onInteractionUpdate: (_) {},
            onInteractionEnd: (_) {},
            // Mirrors the real editor: a full-bleed background with the
            // page centred inside it.
            child: ColoredBox(
              color: const Color(0xFFEEEEEE),
              child: Center(
                child: SizedBox(
                  key: _pageKey,
                  width: 200,
                  height: 200,
                  child: withTarget
                      ? ZoomBounceTarget(
                          child: probe
                              ? const _InflationProbe()
                              : const ColoredBox(color: Color(0xFF2196F3)),
                        )
                      : const ColoredBox(color: Color(0xFF2196F3)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

double matrixScaleOf() =>
    _viewerKey.currentState!.transformMatrix4.getMaxScaleOnAxis();

/// The overshoot factor currently being painted, or 1.0 when there is none.
double paintedBounceOf(WidgetTester tester) {
  final built = find.descendant(
    of: find.byType(ExtendedRawInteractiveViewer),
    matching: find.byType(Transform),
  );
  var largest = 1.0;
  for (final element in built.evaluate()) {
    final widget = element.widget as Transform;
    // The bounce transform is the one that does not hit-test.
    if (widget.transformHitTests) continue;
    final scale = widget.transform.getMaxScaleOnAxis();
    if (scale > largest) largest = scale;
  }
  return largest;
}

/// Pinches outward well past [_maxScale], reporting the matrix scale and
/// painted overshoot seen on every frame.
Future<({double peakMatrix, double peakBounce})> pinchPastMax(
  WidgetTester tester,
) async {
  // Global coordinates — the viewer is centred in the test window, not at
  // the origin.
  final center = tester.getCenter(find.byType(ExtendedInteractiveViewer));
  final first = await tester.startGesture(center - const Offset(10, 0));
  final second = await tester.startGesture(center + const Offset(10, 0));

  var peakMatrix = 0.0;
  var peakBounce = 1.0;

  for (var step = 1; step <= 14; step++) {
    final spread = Offset(10.0 * step, 0);
    await first.moveTo(center - spread);
    await second.moveTo(center + spread);
    await tester.pump(const Duration(milliseconds: 16));

    peakMatrix = peakMatrix > matrixScaleOf() ? peakMatrix : matrixScaleOf();
    final painted = paintedBounceOf(tester);
    peakBounce = peakBounce > painted ? peakBounce : painted;
  }

  await first.up();
  await second.up();
  return (peakMatrix: peakMatrix, peakBounce: peakBounce);
}

/// Counts how many times its subtree has been inflated.
///
/// Stands in for the editor's own gesture detector, which lives inside the
/// bounce target. If the element is ever rebuilt from scratch its gesture
/// recognizers are recreated too, and any pinch in flight is dropped.
class _InflationProbe extends StatefulWidget {
  const _InflationProbe();

  static int inflations = 0;

  @override
  State<_InflationProbe> createState() => _InflationProbeState();
}

class _InflationProbeState extends State<_InflationProbe> {
  @override
  void initState() {
    super.initState();
    _InflationProbe.inflations++;
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFF00FF00));
}

void main() {
  group('zoom bounce widget stability', () {
    testWidgets('never re-inflates the content it wraps', (tester) async {
      // Regression: the target used to skip its transform while at rest, so
      // the tree changed shape every time the effect engaged or released.
      // Flutter re-inflated everything below, the editor's gesture recognizers
      // were recreated mid-pinch, and the gesture was dropped — the user had
      // to lift and pinch again.
      _InflationProbe.inflations = 0;

      await tester.pumpWidget(buildViewer(bounceEnabled: true, probe: true));
      expect(_InflationProbe.inflations, 1);

      // Engage the overshoot...
      await pinchPastMax(tester);
      await tester.pump(const Duration(milliseconds: 16));
      expect(paintedBounceOf(tester), greaterThan(1.0));
      expect(
        _InflationProbe.inflations,
        1,
        reason: 'engaging the overshoot must not rebuild the subtree',
      );

      // ...and release it, passing back through no-overshoot.
      await tester.pumpAndSettle();
      expect(paintedBounceOf(tester), closeTo(1.0, 1e-3));
      expect(
        _InflationProbe.inflations,
        1,
        reason: 'settling must not rebuild the subtree either',
      );
    });
  });

  group('zoom bounce', () {
    testWidgets(
      'the transformation matrix never leaves the configured limits',
      (tester) async {
        // The whole point of the design: the overshoot is painted, never
        // committed, so everything that reads the editor's scale keeps seeing
        // an in-range value.
        await tester.pumpWidget(buildViewer(bounceEnabled: true));
        final result = await pinchPastMax(tester);

        expect(
          result.peakMatrix,
          lessThanOrEqualTo(_maxScale + 1e-9),
          reason: 'matrix must stay clamped',
        );
        expect(
          result.peakBounce,
          greaterThan(1.0),
          reason: 'but an overshoot must actually have been painted',
        );

        await tester.pumpAndSettle();
      },
    );

    testWidgets('settles back to no overshoot after release', (tester) async {
      await tester.pumpWidget(buildViewer(bounceEnabled: true));
      await pinchPastMax(tester);

      await tester.pumpAndSettle();

      expect(paintedBounceOf(tester), closeTo(1.0, 1e-3));
      expect(matrixScaleOf(), closeTo(_maxScale, 1e-6));
    });

    testWidgets('stretches only the page, not the editor background', (
      tester,
    ) async {
      // The whole reason the effect is applied by an opt-in target rather than
      // by the viewer: stretching the viewer's child would scale the editor
      // chrome too, and the page would appear not to move at all.
      await tester.pumpWidget(buildViewer(bounceEnabled: true));
      final backgroundBefore = tester.getRect(find.byType(ColoredBox).first);

      await pinchPastMax(tester);
      await tester.pump(const Duration(milliseconds: 16));

      expect(paintedBounceOf(tester), greaterThan(1.0));
      expect(
        tester.getRect(find.byType(ColoredBox).first),
        backgroundBefore,
        reason: 'the background must not move',
      );

      // The bounce transform must live below the page, not above it.
      expect(
        find.descendant(
          of: find.byKey(_pageKey),
          matching: find.byType(ZoomBounceTarget),
        ),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
    });

    testWidgets('is inert when no target marks the page', (tester) async {
      // A viewer whose content never opts in must still zoom normally.
      await tester.pumpWidget(
        buildViewer(bounceEnabled: true, withTarget: false),
      );
      final result = await pinchPastMax(tester);

      expect(result.peakBounce, 1.0);
      expect(result.peakMatrix, lessThanOrEqualTo(_maxScale + 1e-9));

      await tester.pumpAndSettle();
    });

    testWidgets('keeps responding when pinched far past the limit', (
      tester,
    ) async {
      // Regression: the gesture used to bank travel past the limit that bought
      // no extra stretch, and all of it had to be un-pinched back through
      // before the zoom moved again. It read as the pinch sticking, forcing
      // the user to lift and start over.
      await tester.pumpWidget(buildViewer(bounceEnabled: true));
      final center = tester.getCenter(find.byType(ExtendedInteractiveViewer));
      final first = await tester.startGesture(center - const Offset(10, 0));
      final second = await tester.startGesture(center + const Offset(10, 0));

      Future<double> spreadTo(double spread) async {
        await first.moveTo(center - Offset(spread, 0));
        await second.moveTo(center + Offset(spread, 0));
        await tester.pump(const Duration(milliseconds: 16));
        return matrixScaleOf() * paintedBounceOf(tester);
      }

      // Push well past the limit.
      for (var spread = 20.0; spread <= 220; spread += 20) {
        await spreadTo(spread);
      }
      final atFullStretch = await spreadTo(220);

      // Every step of the return stroke must give ground immediately.
      var previous = atFullStretch;
      for (var spread = 200.0; spread >= 60; spread -= 20) {
        final current = await spreadTo(spread);
        expect(
          current,
          lessThan(previous),
          reason: 'un-pinching at spread=$spread produced no response',
        );
        previous = current;
      }

      expect(previous, lessThan(atFullStretch));

      await first.up();
      await second.up();
      await tester.pumpAndSettle();
    });

    testWidgets('reset() drops the overshoot within a single frame', (
      tester,
    ) async {
      // The app resets the zoom immediately before capturing a page snapshot,
      // so a running spring has to be cancelled outright rather than retargeted.
      await tester.pumpWidget(buildViewer(bounceEnabled: true));
      await pinchPastMax(tester);
      await tester.pump(const Duration(milliseconds: 40));

      expect(paintedBounceOf(tester), greaterThan(1.0));

      _viewerKey.currentState!.reset();
      await tester.pump();

      expect(paintedBounceOf(tester), 1.0);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('zoom bounce disabled', () {
    testWidgets('paints no overshoot transform at all', (tester) async {
      // Guards every other consumer of the library: off by default means the
      // widget tree and the matrix behave exactly as they did before.
      await tester.pumpWidget(buildViewer(bounceEnabled: false));
      final result = await pinchPastMax(tester);

      expect(result.peakBounce, 1.0);
      expect(result.peakMatrix, lessThanOrEqualTo(_maxScale + 1e-9));

      await tester.pumpAndSettle();
      expect(matrixScaleOf(), closeTo(_maxScale, 1e-6));
    });
  });
}
