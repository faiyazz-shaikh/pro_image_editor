import '../../constants/int_constants.dart';
import 'layer.dart';

///
class JDStickerLayerData extends Layer {

  ///
  JDStickerLayerData({
    required this.sticker,
    this.initWidth,
    this.initHeight,
    this.format,
    this.runTimeContent,
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
  factory JDStickerLayerData.fromMap(Layer layer, Map<String, dynamic> map) {
    /// Constructs and returns a PaintingLayerData instance with properties
    /// derived from the layer and map.
    return JDStickerLayerData(
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
      sticker: map['sticker'],
      initHeight: map['initHeight'],
      initWidth: map['initWidth'],
      format: map['format'],
      runTimeContent: map['runTimeContent'],
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
  String sticker;
  ///
  double? initHeight;
  ///
  double? initWidth;
  ///
  String? format;
  ///
  String? runTimeContent;

  @override
  Map<String, dynamic> toMap({
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false}) {
    return {
      ...super.toMap(),
      'sticker': sticker,
      'initHeight': initHeight,
      'initWidth': initWidth,
      'format': format,
      'runTimeContent': runTimeContent,
      'type': 'JDSticker',
    };
  }

  @override
  Map<String, dynamic> toMapFromReference(
    Layer layer, {
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,
  }) {
    var stickerLayer = layer as JDStickerLayerData;
    return {
      ...super.toMapFromReference(
        layer,
        maxDecimalPlaces: maxDecimalPlaces,
        enableMinify: enableMinify,
      ),
      if (stickerLayer.sticker != sticker) 'sticker': sticker,
      if (stickerLayer.initHeight != initHeight) 'initHeight': initHeight,
      if (stickerLayer.initWidth != initWidth) 'initWidth': initWidth,
      if (stickerLayer.format != format) 'format': format,
      if (stickerLayer.runTimeContent != runTimeContent)
        'runTimeContent': runTimeContent,
    };
  }
}
