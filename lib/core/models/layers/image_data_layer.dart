import '../../constants/int_constants.dart';
import 'layer.dart';

///
class JDImageLayerData extends Layer {

  ///
  JDImageLayerData({
    required this.image,
    this.initWidth,
    this.initHeight,
    super.offset,
    super.rotation,
    super.scale,
    super.stretchX,
    super.stretchY,
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
  factory JDImageLayerData.fromMap(Layer layer, Map<String, dynamic> map) {
    /// Constructs and returns a PaintingLayerData instance with properties
    /// derived from the layer and map.
    return JDImageLayerData(
      id: layer.id,
      flipX: layer.flipX,
      flipY: layer.flipY,
      offset: layer.offset,
      rotation: layer.rotation,
      scale: layer.scale,
      stretchX: layer.stretchX,
      stretchY: layer.stretchY,
      horizontalMirror: layer.horizontalMirror,
      verticalMirror: layer.verticalMirror,
      transparency: layer.transparency,
      lock: layer.lock,
      hyperLink: layer.hyperLink,
      image: map['image'],
      initHeight: map['initHeight'],
      initWidth: map['initWidth'],

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
    );
  }
  ///
  String image;
  ///
  double? initHeight;

  ///
  double? initWidth;

  @override
  Map<String, dynamic> toMap({
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,}) {
    return {
      ...super.toMap(),
      'image': image,
      'initHeight': initHeight,
      'initWidth': initWidth,
      'type': 'JDImage',
    };
  }

  @override
  Map<String, dynamic> toMapFromReference(
    Layer layer, {
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,
  }) {
    var imageLayer = layer as JDImageLayerData;
    return {
      ...super.toMapFromReference(
        layer,
        maxDecimalPlaces: maxDecimalPlaces,
        enableMinify: enableMinify,
      ),
      if (imageLayer.image != image) 'image': image,
      if (imageLayer.initHeight != initHeight) 'initHeight': initHeight,
      if (imageLayer.initWidth != initWidth) 'initWidth': initWidth,
    };
  }
}