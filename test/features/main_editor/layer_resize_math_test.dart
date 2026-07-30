import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_interaction_manager.dart';
import 'package:pro_image_editor/shared/widgets/layer/enums/layer_resize_handle.dart';

/// Every rotation / flip combination the resize math has to survive.
const _rotations = <double>[0, pi / 6, pi / 4, pi / 2, pi, -pi / 3];
const _flips = <(bool, bool)>[
  (false, false),
  (true, false),
  (false, true),
  (true, true),
];

/// Mirrors the anchoring rule in `calculateInteractiveResize`: the layer's
/// centre moves by half the change in extent, along the handle's axis.
Offset _anchoredCentre({
  required Offset startCentre,
  required Offset axisDirection,
  required double sign,
  required double startExtent,
  required double appliedExtent,
}) {
  return startCentre +
      axisDirection * (sign * (appliedExtent - startExtent) / 2);
}

/// World position of the edge opposite [handle], which must not move.
Offset _oppositeEdgeCentre({
  required Offset centre,
  required Offset axisDirection,
  required double sign,
  required double extent,
}) {
  return centre - axisDirection * (sign * extent / 2);
}

void main() {
  group('localAxes', () {
    test('produces an orthonormal basis for every rotation and flip', () {
      for (final rotation in _rotations) {
        for (final (flipX, flipY) in _flips) {
          final axes = LayerInteractionManager.localAxes(
            rotation,
            flipX: flipX,
            flipY: flipY,
          );

          final reason = 'rotation=$rotation flipX=$flipX flipY=$flipY';

          expect(axes.u.distance, closeTo(1, 1e-9), reason: 'u unit: $reason');
          expect(axes.v.distance, closeTo(1, 1e-9), reason: 'v unit: $reason');
          expect(
            axes.u.dx * axes.v.dx + axes.u.dy * axes.v.dy,
            closeTo(0, 1e-9),
            reason: 'u orthogonal to v: $reason',
          );
        }
      }
    });

    test('unrotated, unflipped axes are the identity basis', () {
      final axes = LayerInteractionManager.localAxes(
        0,
        flipX: false,
        flipY: false,
      );

      expect(axes.u.dx, closeTo(1, 1e-9));
      expect(axes.u.dy, closeTo(0, 1e-9));
      expect(axes.v.dx, closeTo(0, 1e-9));
      expect(axes.v.dy, closeTo(1, 1e-9));
    });
  });

  group('resize anchoring', () {
    // The defining property of an edge resize: whichever handle is dragged,
    // and however the layer is rotated or flipped, the edge on the far side
    // stays exactly where it was.
    test('the edge opposite the handle never moves', () {
      const startCentre = Offset(120, -40);
      const startExtent = 80.0;

      for (final rotation in _rotations) {
        for (final (flipX, flipY) in _flips) {
          for (final handle in LayerResizeHandle.values) {
            for (final appliedExtent in <double>[20, 79.9, 80, 80.1, 400]) {
              final axes = LayerInteractionManager.localAxes(
                rotation,
                flipX: flipX,
                flipY: flipY,
              );
              final axisDirection = handle.isHorizontal ? axes.u : axes.v;

              final before = _oppositeEdgeCentre(
                centre: startCentre,
                axisDirection: axisDirection,
                sign: handle.sign,
                extent: startExtent,
              );

              final after = _oppositeEdgeCentre(
                centre: _anchoredCentre(
                  startCentre: startCentre,
                  axisDirection: axisDirection,
                  sign: handle.sign,
                  startExtent: startExtent,
                  appliedExtent: appliedExtent,
                ),
                axisDirection: axisDirection,
                sign: handle.sign,
                extent: appliedExtent,
              );

              final reason =
                  'rotation=$rotation flipX=$flipX flipY=$flipY '
                  'handle=${handle.name} extent=$appliedExtent';

              expect((after - before).distance, closeTo(0, 1e-9),
                  reason: reason);
            }
          }
        }
      }
    });

    test('an unchanged extent leaves the centre untouched', () {
      const startCentre = Offset(10, 20);

      for (final handle in LayerResizeHandle.values) {
        final axes = LayerInteractionManager.localAxes(
          pi / 5,
          flipX: false,
          flipY: false,
        );

        final centre = _anchoredCentre(
          startCentre: startCentre,
          axisDirection: handle.isHorizontal ? axes.u : axes.v,
          sign: handle.sign,
          startExtent: 50,
          appliedExtent: 50,
        );

        expect((centre - startCentre).distance, closeTo(0, 1e-9));
      }
    });
  });

  group('LayerResizeHandle', () {
    test('opposing handles share an axis with opposite signs', () {
      expect(LayerResizeHandle.left.axis, LayerResizeHandle.right.axis);
      expect(LayerResizeHandle.top.axis, LayerResizeHandle.bottom.axis);
      expect(
        LayerResizeHandle.left.sign,
        -LayerResizeHandle.right.sign,
      );
      expect(LayerResizeHandle.top.sign, -LayerResizeHandle.bottom.sign);
    });

    test('only the left/right pair drives the horizontal axis', () {
      expect(LayerResizeHandle.left.isHorizontal, isTrue);
      expect(LayerResizeHandle.right.isHorizontal, isTrue);
      expect(LayerResizeHandle.top.isHorizontal, isFalse);
      expect(LayerResizeHandle.bottom.isHorizontal, isFalse);
    });
  });
}
