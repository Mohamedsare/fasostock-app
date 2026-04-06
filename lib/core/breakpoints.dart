/// Breakpoints pour le responsive (mobile / tablette / desktop).
/// Utiliser avec MediaQuery.sizeOf(context).width.
class Breakpoints {
  Breakpoints._();

  /// Largeur à partir de laquelle on considère une tablette (layout à 2 colonnes, etc.).
  static const double tablet = 600;

  /// Largeur à partir de laquelle on affiche la sidebar desktop au lieu du drawer + bottom nav.
  static const double desktop = 900;

  /// Aligné `appweb` `useDesktopNav()` — sidebar + header bureau à partir de 1024px.
  static const double shellDesktop = 1024;

  /// Shell principal (drawer + bottom nav vs sidebar) : même seuil que le web.
  static bool isShellDesktop(double width) => width >= shellDesktop;

  /// Largeur max du contenu sur desktop (évite que le contenu s'étire sur ultra-wide).
  static const double maxContentWidth = 1280;

  /// À partir de cette largeur, on utilise [maxContentWidthLarge] pour exploiter un peu plus l'écran.
  static const double largeDesktop = 1600;

  /// Largeur max du contenu sur très grands écrans (> [largeDesktop]).
  static const double maxContentWidthLarge = 1440;

  /// Seuils pour le POS facture (tableau) : plus de place au tableau sur écrans larges.
  static const double factureTabWideFlexStep1 = 1400;
  static const double factureTabWideFlexStep2 = 1900;
  /// Bandeau produits facture-tab : cible ~1/9 de la hauteur (~11 %).
  static const int factureTabWideStripHeightDivisor = 9;

  /// Hauteur du bandeau produits (h = hauteur utile sous bannières ; [width] = largeur fenêtre).
  /// Plafond **32 %** de [h] ; plancher adapté (**plus bas** sur téléphone pour laisser place au tableau).
  /// entre les deux : cible **1/9** de [h] dans une fourchette bornée.
  static double factureTabStripHeight(double h, {double? width}) {
    if (h <= 0) return 220;
    final ninth = h / factureTabWideStripHeightDivisor;
    final maxStrip = h * 0.32;
    final w = width ?? double.infinity;
    final isPhoneNarrow = w.isFinite && w < tablet;
    final minStrip = isPhoneNarrow
        ? 200.0
        : (w.isFinite && w < desktop ? 230.0 : 250.0);
    if (maxStrip <= minStrip) {
      return maxStrip;
    }
    if (ninth <= minStrip) return minStrip;
    if (ninth >= maxStrip) return maxStrip;
    return ninth;
  }

  /// Largeur max effective selon la largeur d'écran (1280 par défaut, 1440 si > 1600 px).
  static double effectiveMaxContentWidth(double width) =>
      width >= largeDesktop ? maxContentWidthLarge : maxContentWidth;

  /// Cible minimale pour zones tactiles (Android / iOS).
  static const double minTouchTarget = 44;

  static bool isMobile(double width) => width < tablet;
  static bool isTabletOrWider(double width) => width >= tablet;
  static bool isDesktop(double width) => width >= desktop;
  static bool isNarrow(double width) => width < tablet;
}
