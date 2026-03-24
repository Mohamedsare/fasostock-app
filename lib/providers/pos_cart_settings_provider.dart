import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _keyShowQuantityInput = 'pos_cart_show_quantity_input';
const String _keyShowQuantityButtons = 'pos_cart_show_quantity_buttons';
const String _keyPosQuickAutoPrint = 'pos_quick_auto_print';

/// Paramètres panier POS : champ de saisie quantité et/ou boutons (-) et (+).
/// Caisse rapide : impression automatique du ticket après chaque vente (évite de cliquer sur Imprimer).
class PosCartSettingsProvider extends ChangeNotifier {
  PosCartSettingsProvider() {
    _load();
  }

  bool _showQuantityInput = true;
  bool _showQuantityButtons = false;
  bool _posQuickAutoPrint = false;

  bool get showQuantityInput => _showQuantityInput;
  bool get showQuantityButtons => _showQuantityButtons;
  /// Si true, après une vente en caisse rapide le ticket est considéré comme imprimé sans afficher le dialogue (gain de temps).
  bool get posQuickAutoPrint => _posQuickAutoPrint;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _showQuantityInput = prefs.getBool(_keyShowQuantityInput) ?? true;
      _showQuantityButtons = prefs.getBool(_keyShowQuantityButtons) ?? false;
      _posQuickAutoPrint = prefs.getBool(_keyPosQuickAutoPrint) ?? false;
      await _normalizeAndPersist(prefs);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _normalizeAndPersist(SharedPreferences prefs) async {
    // Invariant UX: exactement un mode actif pour modifier la quantité.
    if (_showQuantityInput && _showQuantityButtons) {
      _showQuantityButtons = false;
      await prefs.setBool(_keyShowQuantityButtons, false);
      return;
    }
    if (!_showQuantityInput && !_showQuantityButtons) {
      _showQuantityInput = true;
      await prefs.setBool(_keyShowQuantityInput, true);
    }
  }

  Future<void> setShowQuantityInput(bool value) async {
    if (_showQuantityInput == value) return;
    _showQuantityInput = value;
    if (value) {
      _showQuantityButtons = false;
    } else if (!_showQuantityButtons) {
      // Empêche l'état invalide "aucun mode actif".
      _showQuantityButtons = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowQuantityInput, _showQuantityInput);
      await prefs.setBool(_keyShowQuantityButtons, _showQuantityButtons);
    } catch (_) {}
  }

  Future<void> setShowQuantityButtons(bool value) async {
    if (_showQuantityButtons == value) return;
    _showQuantityButtons = value;
    if (value) {
      _showQuantityInput = false;
    } else if (!_showQuantityInput) {
      // Empêche l'état invalide "aucun mode actif".
      _showQuantityInput = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowQuantityButtons, _showQuantityButtons);
      await prefs.setBool(_keyShowQuantityInput, _showQuantityInput);
    } catch (_) {}
  }

  Future<void> setPosQuickAutoPrint(bool value) async {
    if (_posQuickAutoPrint == value) return;
    _posQuickAutoPrint = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPosQuickAutoPrint, value);
    } catch (_) {}
  }
}
