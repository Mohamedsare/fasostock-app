import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Anciennes clés (avant séparation caisse rapide / facture A4).
const String _legacyKeyShowQuantityInput = 'pos_cart_show_quantity_input';
const String _legacyKeyShowQuantityButtons = 'pos_cart_show_quantity_buttons';

const String _keyQuickShowQuantityInput = 'pos_quick_show_quantity_input';
const String _keyQuickShowQuantityButtons = 'pos_quick_show_quantity_buttons';
const String _keyInvoiceShowQuantityInput = 'pos_invoice_a4_show_quantity_input';
const String _keyInvoiceShowQuantityButtons = 'pos_invoice_a4_show_quantity_buttons';
const String _keyPosQuickAutoPrint = 'pos_quick_auto_print';

/// Paramètres panier : champ de saisie quantité et/ou boutons (-) et (+), par type de caisse.
/// Caisse rapide : impression automatique du ticket après chaque vente (évite de cliquer sur Imprimer).
class PosCartSettingsProvider extends ChangeNotifier {
  PosCartSettingsProvider() {
    _load();
  }

  bool _quickShowQuantityInput = true;
  bool _quickShowQuantityButtons = false;
  bool _invoiceShowQuantityInput = true;
  bool _invoiceShowQuantityButtons = false;
  bool _posQuickAutoPrint = false;

  bool get quickShowQuantityInput => _quickShowQuantityInput;
  bool get quickShowQuantityButtons => _quickShowQuantityButtons;
  bool get invoiceShowQuantityInput => _invoiceShowQuantityInput;
  bool get invoiceShowQuantityButtons => _invoiceShowQuantityButtons;

  /// Si true, après une vente en caisse rapide le ticket est considéré comme imprimé sans afficher le dialogue (gain de temps).
  bool get posQuickAutoPrint => _posQuickAutoPrint;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final legacyInput = prefs.containsKey(_legacyKeyShowQuantityInput)
          ? prefs.getBool(_legacyKeyShowQuantityInput)
          : null;
      final legacyButtons = prefs.containsKey(_legacyKeyShowQuantityButtons)
          ? prefs.getBool(_legacyKeyShowQuantityButtons)
          : null;

      if (prefs.containsKey(_keyQuickShowQuantityInput)) {
        _quickShowQuantityInput = prefs.getBool(_keyQuickShowQuantityInput)!;
        _quickShowQuantityButtons = prefs.getBool(_keyQuickShowQuantityButtons)!;
      } else if (legacyInput != null) {
        _quickShowQuantityInput = legacyInput;
        _quickShowQuantityButtons = legacyButtons ?? false;
      } else {
        _quickShowQuantityInput = true;
        _quickShowQuantityButtons = false;
      }

      if (prefs.containsKey(_keyInvoiceShowQuantityInput)) {
        _invoiceShowQuantityInput = prefs.getBool(_keyInvoiceShowQuantityInput)!;
        _invoiceShowQuantityButtons = prefs.getBool(_keyInvoiceShowQuantityButtons)!;
      } else if (legacyInput != null) {
        _invoiceShowQuantityInput = legacyInput;
        _invoiceShowQuantityButtons = legacyButtons ?? false;
      } else {
        _invoiceShowQuantityInput = true;
        _invoiceShowQuantityButtons = false;
      }

      _posQuickAutoPrint = prefs.getBool(_keyPosQuickAutoPrint) ?? false;

      await _normalizeQuick(prefs);
      await _normalizeInvoice(prefs);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _normalizeQuick(SharedPreferences prefs) async {
    if (_quickShowQuantityInput && _quickShowQuantityButtons) {
      _quickShowQuantityButtons = false;
    }
    if (!_quickShowQuantityInput && !_quickShowQuantityButtons) {
      _quickShowQuantityInput = true;
    }
    await prefs.setBool(_keyQuickShowQuantityInput, _quickShowQuantityInput);
    await prefs.setBool(_keyQuickShowQuantityButtons, _quickShowQuantityButtons);
  }

  Future<void> _normalizeInvoice(SharedPreferences prefs) async {
    if (_invoiceShowQuantityInput && _invoiceShowQuantityButtons) {
      _invoiceShowQuantityButtons = false;
    }
    if (!_invoiceShowQuantityInput && !_invoiceShowQuantityButtons) {
      _invoiceShowQuantityInput = true;
    }
    await prefs.setBool(_keyInvoiceShowQuantityInput, _invoiceShowQuantityInput);
    await prefs.setBool(_keyInvoiceShowQuantityButtons, _invoiceShowQuantityButtons);
  }

  Future<void> setQuickShowQuantityInput(bool value) async {
    if (_quickShowQuantityInput == value) return;
    _quickShowQuantityInput = value;
    if (value) {
      _quickShowQuantityButtons = false;
    } else if (!_quickShowQuantityButtons) {
      _quickShowQuantityButtons = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyQuickShowQuantityInput, _quickShowQuantityInput);
      await prefs.setBool(_keyQuickShowQuantityButtons, _quickShowQuantityButtons);
    } catch (_) {}
  }

  Future<void> setQuickShowQuantityButtons(bool value) async {
    if (_quickShowQuantityButtons == value) return;
    _quickShowQuantityButtons = value;
    if (value) {
      _quickShowQuantityInput = false;
    } else if (!_quickShowQuantityInput) {
      _quickShowQuantityInput = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyQuickShowQuantityButtons, _quickShowQuantityButtons);
      await prefs.setBool(_keyQuickShowQuantityInput, _quickShowQuantityInput);
    } catch (_) {}
  }

  Future<void> setInvoiceShowQuantityInput(bool value) async {
    if (_invoiceShowQuantityInput == value) return;
    _invoiceShowQuantityInput = value;
    if (value) {
      _invoiceShowQuantityButtons = false;
    } else if (!_invoiceShowQuantityButtons) {
      _invoiceShowQuantityButtons = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyInvoiceShowQuantityInput, _invoiceShowQuantityInput);
      await prefs.setBool(_keyInvoiceShowQuantityButtons, _invoiceShowQuantityButtons);
    } catch (_) {}
  }

  Future<void> setInvoiceShowQuantityButtons(bool value) async {
    if (_invoiceShowQuantityButtons == value) return;
    _invoiceShowQuantityButtons = value;
    if (value) {
      _invoiceShowQuantityInput = false;
    } else if (!_invoiceShowQuantityInput) {
      _invoiceShowQuantityInput = true;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyInvoiceShowQuantityButtons, _invoiceShowQuantityButtons);
      await prefs.setBool(_keyInvoiceShowQuantityInput, _invoiceShowQuantityInput);
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
