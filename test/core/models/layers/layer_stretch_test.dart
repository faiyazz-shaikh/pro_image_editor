import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/core/models/layers/image_data_layer.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_image_editor/core/models/layers/painting_data_layer.dart';
import 'package:pro_image_editor/core/models/layers/quill_data_layer.dart';
import 'package:pro_image_editor/core/models/layers/sticker_layer_data.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/shared/services/import_export/utils/key_minifier.dart';

/// Every layer type together with a map that makes [Layer.fromMap] build it.
///
/// Keeping this table exhaustive is the point of the round-trip tests: a new
/// base field that a subclass factory forgets to forward shows up here as a
/// failure instead of as silently lost user data.
final _layerTypeFixtures = <String, Map<String, dynamic>>{
  'default': {'type': 'default'},
  'text': {
    'type': 'text',
    'text': 'hello',
    // TextLayer.fromMap resolves these enums with `firstWhere`, so they have
    // to be present and valid.
    'colorMode': 'background',
    'align': 'left',
    'color': 0xFF000000,
    'background': 0x00000000,
  },
  'emoji': {'type': 'emoji', 'emoji': '🙂'},
  'paint': {
    'type': 'paint',
    'item': {'mode': 'freeStyle', 'offsets': <dynamic>[], 'color': 0xFF000000},
    'rawSize': {'w': 10.0, 'h': 10.0},
  },
  'widget': {'type': 'widget'},
  'JDQuillDocument': {'type': 'JDQuillDocument', 'document': '[]'},
  'JDPaintingDocument': {'type': 'JDPaintingDocument', 'painting': 'a/b.png'},
  'JDImage': {'type': 'JDImage', 'image': 'a/b.png'},
  'JDSticker': {'type': 'JDSticker', 'sticker': 'a/b.svg'},
};

/// One concrete instance of every layer type, for the copy-manager tests.
List<Layer> _allLayerInstances() => [
  Layer(),
  TextLayer(text: 'hello'),
  EmojiLayer(emoji: '🙂'),
  WidgetLayer(widget: const SizedBox()),
  QuillDataLayer(document: '[]', initWidth: 100, initHeight: 50),
  PaintingDataLayer(painting: 'a/b.png', initWidth: 100, initHeight: 50),
  JDImageLayerData(image: 'a/b.png', initWidth: 100, initHeight: 50),
  JDStickerLayerData(sticker: 'a/b.svg', initWidth: 70, initHeight: 70),
];

void main() {
  group('Layer stretch — defaults', () {
    test('defaults to 1 on both axes', () {
      final layer = Layer();

      expect(layer.stretchX, 1);
      expect(layer.stretchY, 1);
      expect(layer.hasStretch, isFalse);
    });

    test('resetStretch clears distortion without touching scale', () {
      final layer = Layer(scale: 3)
        ..stretchX = 2.5
        ..stretchY = 0.4;

      expect(layer.hasStretch, isTrue);

      layer.resetStretch();

      expect(layer.stretchX, 1);
      expect(layer.stretchY, 1);
      expect(layer.hasStretch, isFalse);
      expect(layer.scale, 3, reason: 'stretch is independent of scale');
    });
  });

  group('Layer stretch — constructors', () {
    // Every other base field can be passed straight to a subclass
    // constructor; stretch has to behave the same way or callers are forced
    // to construct and then mutate.
    test('every subclass accepts it directly', () {
      final layers = <Layer>[
        Layer(stretchX: 2.5, stretchY: 0.4),
        TextLayer(text: 'hello', stretchX: 2.5, stretchY: 0.4),
        EmojiLayer(emoji: '🙂', stretchX: 2.5, stretchY: 0.4),
        WidgetLayer(
          widget: const SizedBox(),
          stretchX: 2.5,
          stretchY: 0.4,
        ),
        QuillDataLayer(document: '[]', stretchX: 2.5, stretchY: 0.4),
        PaintingDataLayer(painting: 'a.png', stretchX: 2.5, stretchY: 0.4),
        JDImageLayerData(image: 'a.png', stretchX: 2.5, stretchY: 0.4),
        JDStickerLayerData(sticker: 'a.svg', stretchX: 2.5, stretchY: 0.4),
      ];

      for (final layer in layers) {
        expect(layer.stretchX, 2.5, reason: '${layer.runtimeType}');
        expect(layer.stretchY, 0.4, reason: '${layer.runtimeType}');
      }
    });

    test('omitting it leaves the layer undistorted', () {
      expect(TextLayer(text: 'hello').hasStretch, isFalse);
      expect(QuillDataLayer(document: '[]').hasStretch, isFalse);
    });
  });

  group('Layer stretch — backward compatibility', () {
    // This is the contract that keeps already-saved documents rendering the
    // way they did before non-uniform resize existed.
    for (final entry in _layerTypeFixtures.entries) {
      test('${entry.key}: map without stretch keys parses to 1', () {
        final layer = Layer.fromMap(entry.value);

        expect(layer.stretchX, 1);
        expect(layer.stretchY, 1);
      });
    }

    test('toMap omits both keys when the layer is not distorted', () {
      final map = Layer().toMap();

      expect(map.containsKey('stretchX'), isFalse);
      expect(map.containsKey('stretchY'), isFalse);
    });

    test('toMap omits only the axis that is undistorted', () {
      final map = (Layer()..stretchX = 2).toMap();

      expect(map['stretchX'], 2);
      expect(map.containsKey('stretchY'), isFalse);
    });

    test('an undistorted layer serializes identically to a plain layer', () {
      // Guards consumers that checksum the raw encoded content: adding the
      // feature must not mark every existing document as modified.
      final untouched = Layer(id: 'a').toMap();
      final resetAgain = (Layer(id: 'a')
            ..stretchX = 2
            ..resetStretch())
          .toMap();

      expect(resetAgain, equals(untouched));
    });
  });

  group('Layer stretch — round trip', () {
    for (final entry in _layerTypeFixtures.entries) {
      test('${entry.key}: survives toMap -> fromMap', () {
        final source = Layer.fromMap(entry.value)
          ..stretchX = 2.5
          ..stretchY = 0.4;

        final restored = Layer.fromMap({...entry.value, ...source.toMap()});

        expect(restored.stretchX, 2.5);
        expect(restored.stretchY, 0.4);
      });
    }
  });

  group('Layer stretch — copy paths', () {
    // copyLayerList runs on every history entry, so a copy that drops stretch
    // makes undo/redo silently erase the user's resize.
    for (final layer in _allLayerInstances()) {
      final name = layer.runtimeType.toString();

      test('$name: copyLayer preserves stretch', () {
        layer
          ..stretchX = 2.5
          ..stretchY = 0.4;

        final copy = LayerCopyManager().copyLayer(layer);

        expect(copy.stretchX, 2.5);
        expect(copy.stretchY, 0.4);
      });

      test('$name: duplicateLayer preserves stretch', () {
        layer
          ..stretchX = 2.5
          ..stretchY = 0.4;

        final copy = LayerCopyManager().duplicateLayer(layer);

        expect(copy.stretchX, 2.5);
        expect(copy.stretchY, 0.4);
      });
    }
  });

  group('Layer stretch — misc', () {
    test('minifier knows both keys', () {
      final minifier = EditorKeyMinifier(enableMinify: true);

      expect(minifier.convertLayerKey('stretchX'), isNotEmpty);
      expect(minifier.convertLayerKey('stretchY'), isNotEmpty);
    });

    test('equality and hashCode take stretch into account', () {
      final a = Layer(id: 'same');
      final b = Layer(id: 'same')..stretchX = 2;

      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('copyWith carries stretch through', () {
      final layer = Layer()
        ..stretchX = 2.5
        ..stretchY = 0.4;

      final copy = layer.copyWith();

      expect(copy.stretchX, 2.5);
      expect(copy.stretchY, 0.4);
    });

    test('toMapFromReference emits stretch only when it differs', () {
      final reference = Layer(id: 'a');
      final same = Layer(id: 'a');
      final changed = Layer(id: 'a')..stretchX = 2;

      expect(same.toMapFromReference(reference).containsKey('stretchX'), false);
      expect(changed.toMapFromReference(reference)['stretchX'], 2);
    });
  });
}
