/// Breakpoints pour le responsive (mobile / tablette / desktop).
/// Utiliser avec MediaQuery.sizeOf(context).width.
class Breakpoints {
  Breakpoints._();

  /// Largeur à partir de laquelle on considère une tablette (layout à 2 colonnes, etc.).
  static const double tablet = 600;

  /// Largeur à partir de laquelle on affiche la sidebar desktop au lieu du drawer + bottom nav.
  static const double desktop = 900;

  /// Largeur max du contenu sur desktop (évite que le contenu s'étire sur ultra-wide).
  static const double maxContentWidth = 1280;

  /// À partir de cette largeur, on utilise [maxContentWidthLarge] pour exploiter un peu plus l'écran.
  static const double largeDesktop = 1600;

  /// Largeur max du contenu sur très grands écrans (> [largeDesktop]).
  static const double maxContentWidthLarge = 1440;

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
