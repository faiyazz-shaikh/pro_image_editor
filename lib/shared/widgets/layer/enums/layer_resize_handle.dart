// Flutter imports:
import 'package:flutter/painting.dart';

/// Identifies which edge-midpoint handle drives a non-uniform resize.
///
/// Unlike the corner rotate/scale handle — which is purely radial and
/// therefore corner-agnostic — a resize handle has to know which edge it sits
/// on, because it stretches exactly one of the layer's local axes and anchors
/// the opposite edge.
enum LayerResizeHandle {
  /// Sits on the layer-local `-x` edge and stretches horizontally.
  left(Axis.horizontal, -1),

  /// Sits on the layer-local `+x` edge and stretches horizontally.
  right(Axis.horizontal, 1),

  /// Sits on the layer-local `-y` edge and stretches vertically.
  top(Axis.vertical, -1),

  /// Sits on the layer-local `+y` edge and stretches vertically.
  bottom(Axis.vertical, 1);

  const LayerResizeHandle(this.axis, this.sign);

  /// The layer-local axis this handle stretches.
  final Axis axis;

  /// `1` when the handle sits on the positive side of [axis], `-1` otherwise.
  ///
  /// Dragging outward along this direction always grows the layer, regardless
  /// of which of the two opposing handles is being used.
  final double sign;

  /// Whether this handle drives the horizontal axis.
  bool get isHorizontal => axis == Axis.horizontal;
}
