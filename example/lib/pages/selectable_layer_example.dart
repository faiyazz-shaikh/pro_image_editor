// Flutter imports:
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Package imports:
import 'package:pro_image_editor/pro_image_editor.dart';

// Project imports:
import '../utils/example_constants.dart';
import '../utils/example_helper.dart';
import 'painting_data_layer_example/painting_data_ll.dart';

class SelectableLayerExample extends StatefulWidget {
  const SelectableLayerExample({super.key});

  @override
  State<SelectableLayerExample> createState() => _SelectableLayerExampleState();
}

class _SelectableLayerExampleState extends State<SelectableLayerExample>
    with ExampleHelperState<SelectableLayerExample> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () async {
        await precacheImage(
            AssetImage(ExampleConstants.of(context)!.demoAssetPath), context);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildEditor(),
          ),
        );
      },
      leading: const Icon(Icons.select_all_outlined),
      title: const Text('Selectable layer'),
      subtitle: const Text(
          'When you click on a layer, it will show interaction buttons.'),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  Widget _buildEditor() {
    return ProImageEditor.asset(
      ExampleConstants.of(context)!.demoAssetPath,
      key: editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingStarted: onImageEditingStarted,
        onImageEditingComplete: onImageEditingComplete,
        onCloseEditor: onCloseEditor,
        onPaintingEditorTap: (layer) async {
          final result = await Navigator.push<PaintingDataLayer>(
            context,
            MaterialPageRoute(
              builder: (context) => const MyPaintingDataAppPage(),
            ),
          );
          return result!;
        },
        onJDImageTap: _openPicker,
      ),
      configs: ProImageEditorConfigs(
        designMode: platformDesignMode,
        imageGenerationConfigs: const ImageGenerationConfigs(
          processorConfigs: ProcessorConfigs(
            processorMode: ProcessorMode.auto,
          ),
        ),
        layerInteraction: const LayerInteraction(
          /// Choose between `auto`, `enabled` and `disabled`.
          ///
          /// Mode `auto`:
          /// Automatically determines if the layer is selectable based on the device type.
          /// If the device is a desktop-device, the layer is selectable; otherwise, the layer is not selectable.
          selectable: LayerInteractionSelectable.enabled,
          initialSelected: true,
        ),
        imageEditorTheme: const ImageEditorTheme(
          layerInteraction: ThemeLayerInteraction(
            buttonRadius: 10,
            strokeWidth: 1.2,
            borderElementWidth: 7,
            borderElementSpace: 5,
            borderColor: Colors.blue,
            removeCursor: SystemMouseCursors.click,
            rotateScaleCursor: SystemMouseCursors.click,
            editCursor: SystemMouseCursors.click,
            hoverCursor: SystemMouseCursors.move,
            borderStyle: LayerInteractionBorderStyle.solid,
            showTooltips: false,
          ),
        ),
        icons: const ImageEditorIcons(
          layerInteraction: IconsLayerInteraction(
            remove: Icons.clear,
            edit: Icons.edit_outlined,
            rotateScale: Icons.sync,
          ),
        ),
        i18n: const I18n(
          layerInteraction: I18nLayerInteraction(
            remove: 'Remove',
            edit: 'Edit',
            rotateScale: 'Rotate and Scale',
          ),
        ),
      ),
    );
  }

  Future<JDImageLayerData?> _openPicker(JDImageLayerData? source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    Uint8List? bytes;

    bytes = await image.readAsBytes();

    if (!mounted) return null;
    var decodedImage = await decodeImageFromList(bytes);

    if (!mounted) return null;

    final (initWidth, initHeight) = calculateScaledDimensions(
      originalWidth: decodedImage.width.toDouble(),
      originalHeight: decodedImage.height.toDouble(),
      maxWidth: 150,
      maxHeight: 200,
    );

    return JDImageLayerData(
      imageData: base64Encode(bytes),
      initWidth: initWidth,
      initHeight: initHeight,
      tempWidget: Image.memory(
        bytes,
        width: initWidth,
        height: initHeight,
        fit: BoxFit.cover,
      ),
    );
  }

  (double, double) calculateScaledDimensions({
    required double originalWidth,
    required double originalHeight,
    required double maxWidth,
    required double maxHeight,
  }) {
    // If the height is larger than maxHeight, scale down by height
    if (originalHeight > maxHeight) {
      double scalingFactor = maxHeight / originalHeight;

      // Scale the width proportionally
      double newWidth = originalWidth * scalingFactor;
      double newHeight = originalHeight * scalingFactor;

      // If the new width exceeds maxWidth, scale down further by width
      if (newWidth > maxWidth) {
        scalingFactor = maxWidth / newWidth;
        newWidth = newWidth * scalingFactor;
        newHeight = newHeight * scalingFactor;
      }

      return (newWidth, newHeight);
    }

    // If height is within bounds but width is larger, scale down by width
    if (originalWidth > maxWidth) {
      double scalingFactor = maxWidth / originalWidth;
      double newWidth = originalWidth * scalingFactor;
      double newHeight = originalHeight * scalingFactor;

      return (newWidth, newHeight);
    }

    // If neither height nor width needs scaling
    return (originalWidth, originalHeight);
  }
}
