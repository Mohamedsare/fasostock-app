# Logo FasoStock

- **logo.png** : logo bitmap (icône app, splash). Remplacer par votre version si besoin.
- **logo.svg** : logo vectoriel (orange #EA580C, boîte + tendance). Utilisable dans l’UI avec le package `flutter_svg` si vous l’ajoutez.

## Icônes launcher (mobile & Windows)

Pour appliquer le logo comme icône d’app sur Android, iOS et Windows :

1. Générer un **1024×1024** (ou 512×512) à partir de `logo.svg` ou du PNG (outil en ligne ou Figma/Inkscape).
2. **Option A** – Package [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) : ajouter la config dans `pubspec.yaml`, placer la source dans `assets/` puis lancer `dart run flutter_launcher_icons`.
3. **Option B** – Manuel : remplacer les PNG dans `android/app/src/main/res/drawable-*` et `windows/runner/resources/app_icon.ico` (converter PNG → ICO pour Windows).

Couleur principale du logo : **#EA580C** (orange, aligné avec le thème app).
