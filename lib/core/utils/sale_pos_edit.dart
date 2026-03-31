import '../../data/models/sale.dart';

/// True si la vente doit être modifiée sur l’écran **Facture A4** (`PosPage`).
/// Sinon : **Caisse rapide / ticket thermique** (`PosQuickPage`).
/// Aligné sur l’affichage liste ventes (`document_type` puis `sale_mode`).
bool saleOpensOnInvoicePosScreen(Sale s) {
  if (s.documentType == DocumentType.a4Invoice) return true;
  if (s.documentType == DocumentType.thermalReceipt) return false;
  if (s.saleMode == SaleMode.invoicePos) return true;
  if (s.saleMode == SaleMode.quickPos) return false;
  return false;
}

/// Query `?editSale=` pour ouvrir le bon POS en mode modification.
String saleEditQuery(String saleId) => 'editSale=$saleId';
