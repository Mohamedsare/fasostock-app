# App ultra rapide — checklist

## Déjà en place

1. **Lecture 100 % locale**  
   Produits, clients, ventes, boutiques, catégories, marques, fournisseurs, stock : tout est lu depuis Drift (SQLite). Aucun `await` réseau pour afficher les listes.

2. **Sync non bloquante**  
   SyncServiceV2 est toujours lancée en `Future.microtask` ou après un refresh. L’UI ne reste jamais bloquée sur le réseau.

3. **Drift chauffé au démarrage**  
   `OfflineSyncWrapper.build()` appelle `ref.read(appDatabaseProvider)` pour ouvrir la base dès le premier build, afin que le premier écran qui utilise les streams ne subisse pas l’ouverture.

4. **Listes paresseuses**  
   - Page Produits : `SliverList` + `SliverChildBuilderDelegate` (construction des lignes à la demande).  
   - POS : `GridView.builder` et `ListView.builder`.  
   - Pas de `.toList()` sur toute la liste pour l’affichage.

5. **Index SQL**  
   Index sur `company_id`, `store_id`, `synced` pour les requêtes Drift/Supabase.

6. **Page Produits sans appel API au montage**  
   Produits, catégories et marques viennent des streams Drift. Plus de `loadIfNeeded()` dans `didChangeDependencies` : affichage immédiat.

## Bonnes pratiques à garder

- **Streams Riverpod** : utiliser `ref.watch(…StreamProvider)` pour que l’UI se mette à jour toute seule quand Drift change.
- **Refresh** : garder le pull-to-refresh qui déclenche la sync puis met à jour l’affichage (données déjà en local).
- **Écritures** : après création/édition/suppression, lancer la sync en arrière-plan sans `await` dans l’UI.

## Si tu veux aller plus loin

- **Achats / Transferts** : tables Drift + streams pour les listes (aujourd’hui : références en Drift, listes en API).
- **Dashboard** : dériver une partie des KPIs depuis `LocalSales` pour un affichage instantané même hors ligne.
- **Images** : cache (ex. `cached_network_image`) pour les photos produits.
- **Rebuilds** : utiliser `ref.watch(provider.select((async) => async.value))` si seul `.value` compte et limiter les rebuilds quand `isLoading`/`hasError` changent.
