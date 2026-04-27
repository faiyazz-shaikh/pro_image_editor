import '../../constants/int_constants.dart';
import 'layer.dart';

///
class PaintingDataLayer extends Layer {

  ///
  factory PaintingDataLayer.fromMap(Layer layer, Map<String, dynamic> map) {
    /// Constructs and returns a PaintingLayerData instance with properties
    /// derived from the layer and map.
    return PaintingDataLayer(
      id: layer.id,
      flipX: layer.flipX,
      flipY: layer.flipY,
      offset: layer.offset,
      rotation: layer.rotation,
      scale: layer.scale,
      horizontalMirror: layer.horizontalMirror,
      verticalMirror: layer.verticalMirror,
      transparency: layer.transparency,
      lock: layer.lock,
      hyperLink: layer.hyperLink,
      interaction: layer.interaction,
      meta: layer.meta,
      groupId: layer.groupId,
      startTime: layer.startTime,
      endTime: layer.endTime,
      enterDuration: layer.enterDuration,
      exitDuration: layer.exitDuration,
      enterCurve: layer.enterCurve,
      exitCurve: layer.exitCurve,
      boxConstraints: layer.boxConstraints,
      painting: map['painting'],
      initHeight: map['initHeight'],
      initWidth: map['initWidth'],
    );
  }

  ///
  PaintingDataLayer({
    required this.painting,
    this.initWidth,
    this.initHeight,
    super.offset,
    super.rotation,
    super.scale,
    super.id,
    super.flipX,
    super.flipY,
    super.horizontalMirror,
    super.verticalMirror,
    super.transparency,
    super.lock,
    super.hyperLink,
    super.interaction,
    super.meta,
    super.boxConstraints,
    super.key,
    super.groupId,
    super.startTime,
    super.endTime,
    super.enterDuration,
    super.exitDuration,
    super.enterCurve,
    super.exitCurve,
    super.transitionBuilder,
  });

  ///
  String? painting;
  ///
  double? initHeight;
  ///
  double? initWidth;

  @override
  Map<String, dynamic> toMap({
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,
  }) {
    return {
      ...super.toMap(),
      'painting': painting,
      'initHeight': initHeight,
      'initWidth': initWidth,
      'type': 'JDPaintingDocument',
    };
  }

  @override
  Map<String, dynamic> toMapFromReference(
    Layer layer, {
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,
  }) {
    var paintingLayer = layer as PaintingDataLayer;
    return {
      ...super.toMapFromReference(
        layer,
        maxDecimalPlaces: maxDecimalPlaces,
        enableMinify: enableMinify,
      ),
      if (paintingLayer.painting != painting) 'painting': painting,
      if (paintingLayer.initHeight != initHeight) 'initHeight': initHeight,
      if (paintingLayer.initWidth != initWidth) 'initWidth': initWidth,
    };
  }
}