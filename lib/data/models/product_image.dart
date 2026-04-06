/// URL vignette catalogue : image avec le plus petit [position] (aligné `order('position')` REST).
String? primaryProductImageUrl(Iterable<ProductImage> images) {
  final list = images.toList();
  if (list.isEmpty) return null;
  list.sort((a, b) => a.position.compareTo(b.position));
  final u = list.first.url.trim();
  return u.isEmpty ? null : u;
}

/// Image produit — table product_images.
class ProductImage {
  const ProductImage({
    required this.id,
    required this.productId,
    required this.url,
    this.position = 0,
  });

  final String id;
  final String productId;
  final String url;
  final int position;

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      url: json['url'] as String,
      position: (json['position'] is int) ? json['position'] as int : (json['position'] as num?)?.toInt() ?? 0,
    );
  }
}
