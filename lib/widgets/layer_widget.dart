// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:pro_image_editor/plugins/rounded_background_text/src/rounded_background_text.dart';

// Project imports:
import 'package:pro_image_editor/pro_image_editor.dart';
import '../mixins/converted_configs.dart';
import '../mixins/editor_configs_mixin.dart';
import '../utils/theme_functions.dart';
import 'layer_interaction_helper/layer_interaction_helper_widget.dart';

/// A widget representing a layer within a design canvas.
class LayerWidget extends StatefulWidget with SimpleConfigsAccess {
  /// Creates a [LayerWidget] with the specified properties.
  const LayerWidget({
    super.key,
    this.onScaleRotateDown,
    this.onScaleRotateUp,
    required this.editorCenterX,
    required this.editorCenterY,
    required this.configs,
    required this.layerData,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onEditTap,
    this.onRemoveTap,
    this.highPerformanceMode = false,
    this.enableHitDetection = false,
    this.selected = false,
    this.isInteractive = false,
    this.callbacks = const ProImageEditorCallbacks(),
  });
  @override
  final ProImageEditorConfigs configs;

  @override
  final ProImageEditorCallbacks callbacks;

  /// The x-coordinate of the editor's center.
  ///
  /// This parameter specifies the horizontal center of the editor's body in
  /// logical pixels, used to position and transform layers relative to the
  /// editor's center.
  final double editorCenterX;

  /// The y-coordinate of the editor's center.
  ///
  /// This parameter specifies the vertical center of the editor's body in
  /// logical pixels,  used to position and transform layers relative to the
  /// editor's center.
  final double editorCenterY;

  /// Data for the layer.
  final Layer layerData;

  /// Callback when a tap down event occurs.
  final Function()? onTapDown;

  /// Callback when a tap up event occurs.
  final Function()? onTapUp;

  /// Callback when a tap event occurs.
  final Function(Layer)? onTap;

  /// Callback for removing the layer.
  final Function()? onRemoveTap;

  /// Callback for editing the layer.
  final Function()? onEditTap;

  /// Callback for handling pointer down events associated with scale and rotate
  /// gestures.
  ///
  /// This callback is triggered when the user presses down on the widget to
  /// begin a scaling or rotating gesture. It provides both the pointer event
  /// and the size of the widget being interacted with, allowing for precise
  /// manipulation.
  ///
  /// - Parameters:
  ///   - event: The [PointerDownEvent] containing details about the pointer
  ///     interaction, such as position and device type.
  ///   - size: The [Size] of the widget being manipulated, useful for
  ///     calculating scaling and rotation transformations relative to the
  ///     widget's dimensions.
  final Function(PointerDownEvent, Size)? onScaleRotateDown;

  /// Callback for handling pointer up events associated with scale and rotate
  /// gestures.
  ///
  /// This callback is triggered when the user releases the widget after a
  /// scaling or rotating gesture. It allows for finalizing the interaction and
  /// making any necessary updates or state changes based on the completed
  /// gesture.
  ///
  /// - Parameter event: The [PointerUpEvent] containing details about the
  ///   pointer release, such as position and device type.
  final Function(PointerUpEvent)? onScaleRotateUp;

  /// Controls high-performance for free-style drawing.
  final bool highPerformanceMode;

  /// Enables or disables hit detection.
  /// When set to `true`, it allows detecting user interactions with the
  /// interface.
  final bool enableHitDetection;

  /// Indicates whether the layer is selected.
  final bool selected;

  /// Indicates whether the layer is interactive.
  final bool isInteractive;

  @override
  createState() => _LayerWidgetState();
}

class _LayerWidgetState extends State<LayerWidget>
    with ImageEditorConvertedConfigs, SimpleConfigsAccessState {
  final _layerKey = GlobalKey();

  /// The type of layer being represented.
  late _LayerType _layerType;

  /// Flag to control the display of a move cursor.
  bool _showMoveCursor = false;

  @override
  void initState() {
    switch (widget.layerData.runtimeType) {
      case const (TextLayerData):
        _layerType = _LayerType.text;
        break;
      case const (EmojiLayerData):
        _layerType = _LayerType.emoji;
        break;
      case const (StickerLayerData):
        _layerType = _LayerType.sticker;
        break;
      case const (PaintingLayerData):
        _layerType = _LayerType.canvas;
        break;
      case const (QuillDataLayer):
        _layerType = _LayerType.document;
        break;
      case const (PaintingDataLayer):
        _layerType = _LayerType.painting;
        break;
      case const (JDImageLayerData):
        _layerType = _LayerType.jdImage;
        break;
      case const (JDStickerLayerData):
        _layerType = _LayerType.jdSticker;
        break;
      default:
        _layerType = _LayerType.unknown;
        break;
    }

    super.initState();
  }

  /// Handles a secondary tap up event, typically for showing a context menu.
  void _onSecondaryTapUp(TapUpDetails details) {
    if (_checkHitIsOutsideInCanvas()) return;
    final Offset clickPosition = details.globalPosition;

    // Show a popup menu at the click position
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        clickPosition.dx,
        clickPosition.dy,
        clickPosition.dx + 1.0, // Adding a small value to avoid zero width
        clickPosition.dy + 1.0, // Adding a small value to avoid zero height
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 4),
              Text('Remove'),
            ],
          ),
        ),
      ],
    ).then((String? selectedValue) {
      if (selectedValue != null) {
        widget.onRemoveTap?.call();
      }
    });
  }

  /// Handles a tap event on the layer.
  void _onTap() {
    if (_checkHitIsOutsideInCanvas()) return;
    widget.onTap?.call(_layer);
  }

  /// Handles a pointer down event on the layer.
  void _onPointerDown(PointerDownEvent event) {
    if (_checkHitIsOutsideInCanvas()) return;
    if (!isDesktop || event.buttons != kSecondaryMouseButton) {
      widget.onTapDown?.call();
    }
  }

  /// Handles a pointer up event on the layer.
  void _onPointerUp(PointerUpEvent event) {
    widget.onTapUp?.call();
  }

  /// Checks if the hit is outside the canvas for certain types of layers.
  bool _checkHitIsOutsideInCanvas() {
    return _layerType == _LayerType.canvas &&
        !(_layer as PaintingLayerData).item.hit;
  }

  /// Calculates the transformation matrix for the layer's position and
  /// rotation.
  Matrix4 _calcTransformMatrix() {
    return Matrix4.identity()
      ..setEntry(3, 2, 0.001) // Add a small z-offset to avoid rendering issues
      ..rotateX(_layer.flipY ? pi : 0)
      ..rotateY(_layer.flipX ? pi : 0)
      ..rotateZ(_layer.rotation);
  }

  /// Returns the current layer being displayed.
  Layer get _layer => widget.layerData;

  /// Calculates the horizontal offset for the layer.
  double get offsetX => _layer.offset.dx + widget.editorCenterX;

  /// Calculates the vertical offset for the layer.
  double get offsetY => _layer.offset.dy + widget.editorCenterY;

  @override
  Widget build(BuildContext context) {
    // Position the widget with specified padding
    return Positioned(
      top: offsetY,
      left: offsetX,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _buildPosition(), // Build the widget content
      ),
    );
  }

  /// Build the content with possible transformations
  Widget _buildPosition() {
    Matrix4 transformMatrix = _calcTransformMatrix();
    return Hero(
      key: _layerKey,
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      tag: widget.layerData.id,
      child: Transform(
        transform: transformMatrix,
        alignment: Alignment.center,
        child: Stack(
          children: [
            LayerInteractionHelperWidget(
              layerData: widget.layerData,
              configs: configs,
              callbacks: callbacks,
              selected: widget.selected,
              onEditLayer: widget.onEditTap,
              isInteractive: widget.isInteractive,
              onScaleRotateDown: (details) {
                widget.onScaleRotateDown
                    ?.call(details, context.size ?? Size.zero);
              },
              onScaleRotateUp: widget.onScaleRotateUp,
              onRemoveLayer: widget.onRemoveTap,
              child: MouseRegion(
                hitTestBehavior: HitTestBehavior.translucent,
                cursor: _showMoveCursor
                    ? imageEditorTheme.layerInteraction.hoverCursor
                    : MouseCursor.defer,
                onEnter: (event) {
                  if (_layerType != _LayerType.canvas) {
                    setState(() {
                      _showMoveCursor = true;
                    });
                  }
                },
                onExit: (event) {
                  if (_layerType == _LayerType.canvas) {
                    (widget.layerData as PaintingLayerData).item.hit = false;
                  } else {
                    setState(() {
                      _showMoveCursor = false;
                    });
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onSecondaryTapUp: isDesktop ? _onSecondaryTapUp : null,
                  onTap: _onTap,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    child: Padding(
                      padding: EdgeInsets.all(widget.selected ? 7.0 : 0),
                      child: FittedBox(
                        child: _buildContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the content widget based on the type of layer being displayed.
  Widget _buildContent() {
    switch (_layerType) {
      case _LayerType.emoji:
        return _buildEmoji();
      case _LayerType.text:
        return _buildText();
      case _LayerType.sticker:
        return _buildSticker();
      case _LayerType.canvas:
        return _buildCanvas();
      case _LayerType.document:
        return _buildQuilDocumentLayer();
      case _LayerType.painting:
        return _buildPaintingLayer();
      case _LayerType.jdImage:
        return _buildJdImageLayer();
      case _LayerType.jdSticker:
        return _buildJdStickerLayer();
      default:
        return const SizedBox.shrink();
    }
  }

  double getLineHeight(TextStyle style) {
    final span = TextSpan(text: 'X', style: style);
    final painter = TextPainter(
      text: span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.preferredLineHeight;
  }

  Widget _buildQuilDocumentLayer() {
    var layer = _layer as QuillDataLayer;

    final data = layer.document;
    final json = jsonDecode(data);

    debugPrint('height : ${layer.initHeight}');
    debugPrint('width : ${layer.initWidth}');
    debugPrint('scale: ${_layer.scale}');

    final QuillController controller = QuillController(
      document: Document.fromJson(json as List),
      selection: const TextSelection.collapsed(offset: 0),
    );

    return AbsorbPointer(
      child: SizeTransition(
        sizeFactor: AlwaysStoppedAnimation<double>(_layer.scale),
        child: SizedBox(
          height: (layer.initHeight ?? 0),
          width: (layer.initWidth ?? 0) * _layer.scale,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: IntrinsicWidth(
              // height: (layer.initHeight ?? 0),
              // width: (layer.initWidth ?? 0),
              child: QuillEditor.basic(
                configurations: QuillEditorConfigurations(
                  controller: controller,
                  scrollable: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the text widget
  Widget _buildText() {
    var fontSize = textEditorConfigs.initFontSize * _layer.scale;
    var layer = _layer as TextLayerData;
    var style = TextStyle(
      fontSize: fontSize * layer.fontScale,
      color: layer.color,
      overflow: TextOverflow.ellipsis,
    );

    double height = getLineHeight(style);
    const horizontalPaddingFactor = 0.3;

    return Container(
      // Fix Hit-Box
      padding: EdgeInsets.only(
        left: height * horizontalPaddingFactor,
        right: height * horizontalPaddingFactor,
        bottom: height * 0.175 / 2,
      ),
      child: HeroMode(
        enabled: false,
        child: RoundedBackgroundText(
          layer.text.toString(),
          backgroundColor: layer.background,
          textAlign: layer.align,
          style: layer.textStyle?.copyWith(
                fontSize: style.fontSize,
                fontWeight: style.fontWeight,
                color: style.color,
                fontFamily: style.fontFamily,
              ) ??
              style,
        ),
      ),
    );
  }

  /// Build the emoji widget
  Widget _buildEmoji() {
    var layer = _layer as EmojiLayerData;
    return Material(
      // Prevent hero animation bug
      type: MaterialType.transparency,
      textStyle: platformTextStyle(context, designMode),
      child: Text(
        layer.emoji.toString(),
        textAlign: TextAlign.center,
        style: imageEditorTheme.emojiEditor.textStyle.copyWith(
          fontSize: textEditorConfigs.initFontSize * _layer.scale,
        ),
      ),
    );
  }

  /// Build the sticker widget
  Widget _buildSticker() {
    var layer = _layer as StickerLayerData;
    return SizedBox(
      width: (stickerEditorConfigs?.initWidth ?? 100) * layer.scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: layer.sticker,
      ),
    );
  }

  /// Build the canvas widget
  Widget _buildCanvas() {
    var layer = _layer as PaintingLayerData;
    return Padding(
      // Better hit detection for mobile devices
      padding: EdgeInsets.all(isDesktop ? 0 : 15),
      child: RepaintBoundary(
        child: Opacity(
          opacity: layer.opacity,
          child: CustomPaint(
            size: layer.size,
            willChange: false,
            isComplex: layer.item.mode == PaintModeE.freeStyle,
            painter: DrawPainting(
              item: layer.item,
              scale: widget.layerData.scale,
              selected: widget.selected,
              enabledHitDetection: widget.enableHitDetection,
              freeStyleHighPerformance: widget.highPerformanceMode,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaintingLayer() {
    var layer = _layer as PaintingDataLayer;
    // final DrawingController drawingController = DrawingController();

    // final json = (jsonDecode(layer.painting!) as List<dynamic>);
    //
    // final rectJson =
    //     jsonToRect(jsonDecode(layer.rect!) as Map<String, dynamic>);

    jsonToImageCrop(jsonDecode(layer.cropImage!) as Map<String, dynamic>)
        .then((result) {
      layer.tempImage = result;
    });

    if (layer.tempImage != null) {
      return SizeTransition(
        sizeFactor: AlwaysStoppedAnimation<double>(_layer.scale),
        child: SizedBox(
          width: (layer.tempImage?.width.toDouble() ?? 0) * _layer.scale,
          height: (layer.tempImage?.height.toDouble() ?? 0),
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: CustomPaint(
              painter: ImagePainter(layer.tempImage),
              size: Size(
                layer.tempImage?.width.toDouble() ?? 0,
                layer.tempImage?.height.toDouble() ?? 0,
              ),
            ),
          ),
        ),
      );
    }
    return const CircularProgressIndicator();
  }

  Widget _buildJdImageLayer() {
    var layer = _layer as JDImageLayerData;
    return SizedBox(
      width: (layer.initWidth ?? 100) * layer.scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: layer.tempWidget,
      ),
    );
  }

  Widget _buildJdStickerLayer() {
    var layer = _layer as JDStickerLayerData;
    return SizedBox(
      width: (layer.initWidth ?? 50) * layer.scale,
      child: FittedBox(
        fit: BoxFit.contain,
        child: layer.tempWidget,
      ),
    );
  }
}

// ignore: camel_case_types
enum _LayerType {
  emoji,
  text,
  sticker,
  canvas,
  unknown,
  document,
  painting,
  jdImage,
  jdSticker
}

Future<ui.Image> jsonToImageCrop(Map<String, dynamic> json) async {
  final ByteData newByteData = jsonToByteData(json);

  // Step 4: Convert byte data back to image
  final ui.Image newImage = await byteDataToImage(newByteData);
  return newImage;
}

ByteData jsonToByteData(Map<String, dynamic> json) {
  final List<int> data = List<int>.from(json['data'] as List);
  return ByteData.view(Uint8List.fromList(data).buffer);
}

Future<ui.Image> byteDataToImage(ByteData byteData) async {
  final Completer<ui.Image> completer = Completer();
  ui.decodeImageFromList(byteData.buffer.asUint8List(), completer.complete);
  return completer.future;
}

class ImagePainter extends CustomPainter {
  final ui.Image? image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the image on the canvas
    if (image != null) {
      canvas.drawImage(
          image!, Offset.zero, Paint()..filterQuality = ui.FilterQuality.high);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Rect jsonToRect(Map<String, dynamic> data) {
//   return Rect.fromLTRB(
//     data['left'] as double,
//     data['top'] as double,
//     data['right'] as double,
//     data['bottom'] as double,
//   );
// }
