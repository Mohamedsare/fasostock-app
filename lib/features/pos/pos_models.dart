// Modèles et constantes partagés par la page POS Facture A4.

/// Unités utilisables sur la facture A4 (choix par ligne dans le POS).
const List<String> kInvoiceUnits = ['pce', 'm', 'm²', 'kg', 'carton', 'paquet', 'lot', 'boite', 'sachet'];

/// Élément du panier POS (aligné web CartItem). Unité modifiable pour la facture A4.
class PosCartItem {
  PosCartItem({
    required this.productId,
    required this.name,
    this.sku,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final String? sku;
  String unit;
  int quantity;
  /// Prix unitaire réellement facturé (modifiable au POS facture-tab) — source des rapports via [total].
  double unitPrice;
  double total;
  final String? imageUrl;
}

/// Résultat du dialog de création de client (nom + téléphone).
class CreateCustomerResult {
  CreateCustomerResult({required this.name, this.phone});
  final String name;
  final String? phone;
}
