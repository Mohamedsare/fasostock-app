# Performance & « 0 attente » (objectif utilisateur)

## Réalité technique
- **Zéro attente absolue** est impossible : disque, réseau, GPU et le scheduler Flutter imposent toujours un délai fini.
- L’objectif produit est plutôt : **instantané perçu** (données locales, pas de blocage UI, sync en arrière-plan).

## Ce que l’app fait déjà
- **Drift (SQLite)** : lecture produits, stock, ventes en cache → pas d’attente réseau pour afficher les listes.
- **Sync** (`SyncServiceV2` + `OfflineSyncWrapper`) : envoi / réception **asynchrone**, sans bloquer la navigation.
- **Démarrage** : `initializeDateFormatting` une seule fois avant `runApp` (pas de double appel dans `_AppLoader._load`).
- **Warm** de la base au premier build (`appDatabaseProvider`).

## Pistes d’amélioration continue
1. **DevTools** : onglet Performance + Timeline pour repérer les frames > 16 ms.
2. **Listes** : préférer `ListView.builder` / `SliverList` avec `itemExtent` ou estimate quand possible.
3. **Images réseau** : cache (`cached_network_image`) si beaucoup de vignettes produits.
4. **Gros calculs** : isoler avec `compute()` (hors isolate UI).
5. **Rebuilds** : `const` widgets, `Selector` / Riverpod `select` pour limiter les reconstructions.

## Mesure
- Scénario type : cold start → login → ouvrir Produits / Stock : doit rester fluide si les données sont déjà synchronisées.
