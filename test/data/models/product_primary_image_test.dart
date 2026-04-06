import 'package:flutter_test/flutter_test.dart';
import 'package:fasostock/data/models/product_image.dart';

void main() {
  group('primaryProductImageUrl', () {
    test('returns null for empty iterable', () {
      expect(primaryProductImageUrl(const []), isNull);
    });

    test('picks smallest position', () {
      final url = primaryProductImageUrl([
        const ProductImage(id: 'b', productId: 'p', url: 'https://second.png', position: 5),
        const ProductImage(id: 'a', productId: 'p', url: 'https://first.png', position: 0),
        const ProductImage(id: 'm', productId: 'p', url: 'https://mid.png', position: 2),
      ]);
      expect(url, 'https://first.png');
    });

    test('trims whitespace-only url to null', () {
      expect(
        primaryProductImageUrl([
          const ProductImage(id: 'a', productId: 'p', url: '  ', position: 0),
        ]),
        isNull,
      );
    });
  });
}
