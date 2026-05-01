import '../../../../data/models/product.dart';
import '../../../../shared/utils/csv_export.dart';

const String _sep = ',';
const String _quote = '"';

/// Export des produits en CSV (même colonnes que web : nom, sku, code_barres, ...).
String productsToCsv(List<Product> products) {
  const headers = [
    'nom',
    'sku',
    'code_barres',
    'unite',
    'prix_achat',
    'prix_vente',
    'stock_min',
    'description',
    'actif',
    'categorie',
    'marque',
  ];
  final rows = products
      .map<List<CsvCell>>(
        (p) => [
          p.name,
          p.sku ?? '',
          p.barcode ?? '',
          p.unit,
          formatCsvMoney(p.purchasePrice),
          formatCsvMoney(p.salePrice),
          p.stockMin,
          p.description ?? '',
          p.isActive ? 1 : 0,
          p.category?.name ?? '',
          p.brand?.name ?? '',
        ],
      )
      .toList();
  return buildCsv(headers: headers, rows: rows, separator: ';');
}

/// Ligne produit parsée depuis CSV (équivalent CsvProductRow web).
class CsvProductRow {
  const CsvProductRow({
    required this.name,
    this.sku,
    this.barcode,
    this.unit = 'pce',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.stockMin = 0,
    this.stockEntrant = 0,
    this.description,
    this.isActive = true,
    this.category,
    this.brand,
  });

  final String name;
  final String? sku;
  final String? barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final int stockMin;
  final int stockEntrant;
  final String? description;
  final bool isActive;
  final String? category;
  final String? brand;
}

const Map<String, String> _headerMap = {
  'nom': 'name',
  'name': 'name',
  'sku': 'sku',
  'code_barres': 'barcode',
  'barcode': 'barcode',
  'unite': 'unit',
  'unit': 'unit',
  'prix_achat': 'purchase_price',
  'purchase_price': 'purchase_price',
  'prix_vente': 'sale_price',
  'sale_price': 'sale_price',
  'stock_min': 'stock_min',
  'stock_entrant': 'stock_entrant',
  'quantite_entrante': 'stock_entrant',
  'description': 'description',
  'actif': 'is_active',
  'is_active': 'is_active',
  'active': 'is_active',
  'categorie': 'category',
  'category': 'category',
  'marque': 'brand',
  'brand': 'brand',
};

/// Parse CSV en lignes produit (RFC 4180 basique, même logique que parseProductsCsv web).
List<List<String>> parseCsvRaw(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  var cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == _quote) {
        if (i + 1 < text.length && text[i + 1] == _quote) {
          cell.write(_quote);
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else {
      if (c == _quote) {
        inQuotes = true;
      } else if (c == _sep) {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if (c == '\n' || c == '\r') {
        row.add(cell.toString());
        cell = StringBuffer();
        rows.add(row);
        row = [];
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else {
        cell.write(c);
      }
    }
  }
  row.add(cell.toString());
  if (row.length > 1 || row[0].isNotEmpty) rows.add(row);
  return rows;
}

List<CsvProductRow> parseProductsCsv(String text) {
  final raw = parseCsvRaw(text);
  if (raw.isEmpty) return [];
  final headerRow = raw.first.map((h) => h.trim().toLowerCase()).toList();
  final colIndex = <String, int>{};
  for (var i = 0; i < headerRow.length; i++) {
    final key = _headerMap[headerRow[i]];
    if (key != null) colIndex[key] = i;
  }
  if (!colIndex.containsKey('name')) return [];
  final result = <CsvProductRow>[];
  for (var r = 1; r < raw.length; r++) {
    final row = raw[r];
    final name = (row.length > (colIndex['name'] ?? -1) ? row[colIndex['name']!] : '').trim();
    if (name.isEmpty) continue;
    double numAt(String? key) {
      final idx = key != null ? colIndex[key] : null;
      if (idx == null || idx >= row.length) return 0;
      final v = row[idx].trim().replaceAll(',', '.');
      if (v.isEmpty) return 0;
      return double.tryParse(v) ?? 0;
    }

    bool boolAt(String? key) {
      final idx = key != null ? colIndex[key] : null;
      if (idx == null || idx >= row.length) return true;
      final v = (row[idx]).trim().toLowerCase();
      return v == '1' || v == 'true' || v == 'oui' || v == 'yes';
    }

    String strAt(String? key) {
      final idx = key != null ? colIndex[key] : null;
      if (idx == null || idx >= row.length) return '';
      return (row[idx]).trim();
    }

    result.add(CsvProductRow(
      name: name,
      sku: strAt('sku').isEmpty ? null : strAt('sku'),
      barcode: strAt('barcode').isEmpty ? null : strAt('barcode'),
      unit: strAt('unit').isEmpty ? 'pce' : strAt('unit'),
      purchasePrice: numAt('purchase_price'),
      salePrice: numAt('sale_price'),
      stockMin: numAt('stock_min').toInt(),
      stockEntrant: numAt('stock_entrant').toInt(),
      description: strAt('description').isEmpty ? null : strAt('description'),
      isActive: boolAt('is_active'),
      category: strAt('category').isEmpty ? null : strAt('category'),
      brand: strAt('brand').isEmpty ? null : strAt('brand'),
    ));
  }
  return result;
}

/// Convertit les lignes CSV en maps pour le repository (clés attendues par importFromCsv).
List<Map<String, dynamic>> csvRowsToMaps(List<CsvProductRow> rows) {
  return rows.map((r) => <String, dynamic>{
        'name': r.name,
        'sku': r.sku,
        'barcode': r.barcode,
        'unit': r.unit,
        'purchase_price': r.purchasePrice,
        'sale_price': r.salePrice,
        'stock_min': r.stockMin,
        'stock_entrant': r.stockEntrant,
        'description': r.description,
        'is_active': r.isActive,
        'category': r.category,
        'brand': r.brand,
      }).toList();
}

/// En-têtes CSV attendus pour l'import (avec optionnel stock_entrant).
final List<String> productsCsvHeaders = [
  'nom',
  'sku',
  'code_barres',
  'unite',
  'prix_achat',
  'prix_vente',
  'stock_min',
  'description',
  'actif',
  'categorie',
  'marque',
  'stock_entrant',
];

/// Retourne un CSV modèle avec en-têtes et 2 lignes d'exemple pour montrer comment remplir le fichier.
String getProductsCsvModelTemplate() {
  final headers = productsCsvHeaders.join(_sep);
  const line1 = 'Café moulu 250g,CAF-250,,pce,1200,1800,5,Paquet 250g,1,Boissons,Marque A,100';
  const line2 = 'Riz local 1kg,RIZ-1K,5449000000016,kg,800,1200,10,,1,Alimentaire,Marque B,50';
  return '$headers\n$line1\n$line2';
}
