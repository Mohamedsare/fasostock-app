// Modèles et constantes partagés par la page POS Caisse rapide.

/// Unités utilisables sur la facture thermique (choix par ligne dans le POS).
const List<String> kInvoiceUnits = ['pce', 'm', 'm²', 'kg', 'carton', 'paquet', 'lot', 'boite', 'sachet'];

/// Élément du panier POS (aligné web CartItem). Unité modifiable pour la facture thermique.
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
  final double unitPrice;
  double total;
  final String? imageUrl;
}

/// Résultat du dialog de création de client (nom + téléphone).
class CreateCustomerResult {
  CreateCustomerResult({required this.name, this.phone});
  final String name;
  final String? phone;
}

/// Logique de calcul panier (subtotal, total avec remise, canPay) — testable sans UI.
class PosQuickCartLogic {
  PosQuickCartLogic._();

  static double subtotal(List<PosCartItem> cart) =>
      cart.fold(0.0, (s, c) => s + c.total);

  static double totalWithDiscount(List<PosCartItem> cart, double discount) =>
      (subtotal(cart) - discount).clamp(0.0, double.infinity);

  static bool canPay(List<PosCartItem> cart, double total) =>
      cart.isNotEmpty && total >= 0;
}




