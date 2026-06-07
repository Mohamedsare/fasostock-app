import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Helper centralisé pour le retour haptique — vibrations subtiles sur les actions tactiles
/// importantes. C'est l'un des signaux les plus forts pour qu'une app "se sente native"
/// sur mobile (Android & iOS). Sur desktop/web, c'est un no-op.
///
/// Usage :
/// ```dart
/// FsHaptic.selection(); // tap sur item de navigation, changement de tab, ajout au panier
/// FsHaptic.light();     // pull-to-refresh, ouverture de sheet
/// FsHaptic.medium();    // confirmation d'action (encaissement, sauvegarde)
/// FsHaptic.warning();   // suppression, annulation, action destructive
/// ```
class FsHaptic {
  FsHaptic._();

  /// Tap léger — sélection / changement d'état. Le plus discret.
  static void selection() {
    if (!_isMobile) return;
    HapticFeedback.selectionClick();
  }

  /// Impact léger — feedback d'interaction (ouverture sheet, pull-to-refresh, etc.).
  static void light() {
    if (!_isMobile) return;
    HapticFeedback.lightImpact();
  }

  /// Impact moyen — confirmation d'action positive (validation paiement, sauvegarde réussie).
  static void medium() {
    if (!_isMobile) return;
    HapticFeedback.mediumImpact();
  }

  /// Impact lourd — action critique réussie (rarement utilisé, à réserver à de gros événements).
  static void heavy() {
    if (!_isMobile) return;
    HapticFeedback.heavyImpact();
  }

  /// Vibration courte — action destructive ou annulation (suppression, cancel).
  /// Réalisé via `mediumImpact` (pattern Material 3 — ce n'est PAS une erreur visuelle).
  static void warning() {
    if (!_isMobile) return;
    HapticFeedback.mediumImpact();
  }

  /// Compute mobile platform check sans dépendance MediaQuery — `defaultTargetPlatform`
  /// est suffisant : les HapticFeedback iOS/Android s'auto-mutent sur les autres plateformes,
  /// mais on évite tout de même l'appel pour ne pas polluer les logs en debug desktop.
  static bool get _isMobile {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }
}
