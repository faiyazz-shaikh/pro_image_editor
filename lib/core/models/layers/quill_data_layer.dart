import '../../constants/int_constants.dart';
import 'layer.dart';

///
class QuillDataLayer extends Layer {
  ///
  factory QuillDataLayer.fromMap(Layer layer, Map<String, dynamic> map) {
    return QuillDataLayer(
      id: layer.id,
      flipX: layer.flipX,
      flipY: layer.flipY,
      interaction: layer.interaction,
      offset: layer.offset,
      rotation: layer.rotation,
      scale: layer.scale,
      meta: layer.meta,
      groupId: layer.groupId,
      startTime: layer.startTime,
      endTime: layer.endTime,
      enterDuration: layer.enterDuration,
      exitDuration: layer.exitDuration,
      enterCurve: layer.enterCurve,
      exitCurve: layer.exitCurve,
      boxConstraints: layer.boxConstraints,
      horizontalMirror: layer.horizontalMirror,
      verticalMirror: layer.verticalMirror,
      transparency: layer.transparency,
      lock: layer.lock,
      hyperLink: layer.hyperLink,
      document: map['document'],
      initHeight: map['initHeight'],
      initWidth: map['initWidth'],
    );
  }

  ///
  QuillDataLayer({
    required this.document,
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
  String document;

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
      'document': document,
      'initHeight': initHeight,
      'initWidth': initWidth,
      'type': 'JDQuillDocument',
    };
  }

  @override
  Map<String, dynamic> toMapFromReference(
    Layer layer, {
    int maxDecimalPlaces = kMaxSafeDecimalPlaces,
    bool enableMinify = false,
  }) {
    var quillLayer = layer as QuillDataLayer;
    return {
      ...super.toMapFromReference(
        layer,
        maxDecimalPlaces: maxDecimalPlaces,
        enableMinify: enableMinify,
      ),
      if (quillLayer.document != document) 'document': document,
      if (quillLayer.initHeight != initHeight) 'initHeight': initHeight,
      if (quillLayer.initWidth != initWidth) 'initWidth': initWidth,
    };
  }
}
