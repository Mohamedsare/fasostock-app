/// Libellés français des rôles pour l'affichage dans l'app.
/// Les noms en base peuvent être en anglais ; on affiche toujours le libellé FR ici.
class RoleLabels {
  RoleLabels._();

  static const Map<String, String> _labels = {
    'super_admin': 'Super administrateur',
    'owner': 'Propriétaire',
    'manager': 'Gestionnaire',
    'store_manager': 'Gestionnaire de boutique',
    'cashier': 'Caissier',
    'stock_manager': 'Magasinier',
    'accountant': 'Comptable',
    'viewer': 'Lecture seule',
  };

  /// Retourne le libellé français du rôle à partir de son slug. Sinon [fallback] (ex. nom API).
  static String labelFr(String slug, [String? fallback]) {
    final normalized = slug.trim().toLowerCase();
    return _labels[normalized] ?? fallback ?? slug;
  }
}
