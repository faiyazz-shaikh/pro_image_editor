import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/shared/widgets/extended/interactive_viewer/zoom_bounce_controller.dart';

const _limitIn = 1.18;
const _limitOut = 1.12;

double band(
  double ratio, {
  double limitIn = _limitIn,
  double limitOut = _limitOut,
  double resistance = 1.0,
}) =>
    rubberBandLog(
      ratio,
      limitIn: limitIn,
      limitOut: limitOut,
      resistance: resistance,
    );

/// The visual factor a user would actually see for a given push.
double factor(double ratio) => math.exp(band(ratio));

void main() {
  group('rubberBandLog — rest state', () {
    test('is exactly zero when the gesture is within range', () {
      expect(band(1), 0);
    });

    test('is zero for degenerate input rather than throwing', () {
      // Non-finite input means something upstream is wrong; producing no
      // bounce is safer than a full-strength one from garbage.
      expect(band(0), 0);
      expect(band(-1), 0);
      expect(band(double.nan), 0);
      expect(band(double.infinity), 0);
    });

    test('a limit of exactly 1.0 disables that side', () {
      expect(band(2, limitIn: 1), 0);
      expect(band(0.5, limitOut: 1), 0);

      // The other side keeps working.
      expect(band(0.5, limitIn: 1), isNot(0));
      expect(band(2, limitOut: 1), isNot(0));
    });
  });

  group('rubberBandLog — shape', () {
    test('is monotonic across the whole input range', () {
      var previous = band(0.1);
      for (var ratio = 0.11; ratio <= 6.0; ratio += 0.01) {
        final current = band(ratio);
        expect(
          current,
          greaterThanOrEqualTo(previous),
          reason: 'decreased at ratio=$ratio',
        );
        previous = current;
      }
    });

    test('approaches each limit asymptotically without exceeding it', () {
      // Approaches but never quite reaches, by construction — the input is
      // also clamped, so the closest attainable point is a hair short.
      expect(factor(1e6), closeTo(_limitIn, 1e-4));
      expect(factor(1e6), lessThan(_limitIn));
      expect(factor(1e-6), closeTo(1 / _limitOut, 1e-4));

      // Never overshoots its own asymptote at any input.
      for (var ratio = 1.0; ratio <= 50; ratio += 0.25) {
        expect(factor(ratio), lessThanOrEqualTo(_limitIn + 1e-9));
      }
    });

    test('is symmetric in log space when both limits match', () {
      for (final ratio in [1.1, 1.5, 2.0, 4.0]) {
        expect(
          band(ratio, limitOut: _limitIn),
          closeTo(-band(1 / ratio, limitOut: _limitIn), 1e-12),
        );
      }
    });

    test('tracks the gesture 1:1 at the moment overshoot begins', () {
      // Slope at ratio == 1 should be 1 / resistance.
      for (final resistance in [0.5, 1.0, 1.6]) {
        const h = 1e-6;
        final slope =
            (band(math.exp(h), resistance: resistance) -
                    band(math.exp(-h), resistance: resistance)) /
                (2 * h);
        expect(
          slope,
          closeTo(1 / resistance, 0.01),
          reason: 'resistance=$resistance',
        );
      }
    });

    test('higher resistance yields less overshoot for the same push', () {
      expect(band(1.3, resistance: 1.6), lessThan(band(1.3)));
      expect(band(1.3, resistance: 0.5), greaterThan(band(1.3)));
    });
  });

  group('rubberBandLog — documented feel', () {
    // These are the numbers quoted in the config docs; if the curve is
    // retuned, the docs need to move with it.
    test('matches the documented response at the default settings', () {
      expect(factor(1.1), closeTo(1.075, 0.005));
      expect(factor(1.5), closeTo(1.163, 0.005));
      expect(factor(3.0), closeTo(1.180, 0.005));
    });

    test('the zoom-out side shrinks by a comparable, tighter amount', () {
      expect(factor(0.9), closeTo(0.934, 0.005));
      expect(factor(0.5), closeTo(0.893, 0.005));
    });
  });
}
