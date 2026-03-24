# Architecture Offline-First — FasoStock Flutter

## Stack

- **Frontend**: Flutter, Riverpod (state), Drift (SQLite local)
- **Backend**: Supabase (PostgreSQL, Auth, RLS)

## Cinq principes (ultra rapide + fiable)

1. **Lecture locale d’abord** — Les données sont lues depuis Drift avant tout appel réseau. L’UI utilise des streams Riverpod (`productsStreamProvider`, `inventoryQuantitiesStreamProvider`) qui lisent uniquement la base locale ; aucun `await` réseau pour afficher la liste.
2. **Sync en arrière-plan** — Le serveur ne bloque jamais l’interface. La sync (SyncServiceV2) est lancée au démarrage et à la reconnexion via `Future.microtask` ; après création/édition/suppression d’un produit, la sync est relancée en arrière-plan sans `await` dans l’UI.
3. **Requêtes SQL bien indexées** — Côté **Drift** : index sur `local_products(company_id)`, `store_inventory(store_id)`, `pending_actions(synced)`. Côté **Supabase** : les migrations existantes définissent déjà des index sur `company_id`, `store_id`, `created_at`, etc. (voir `00001_initial_schema.sql`).
4. **UI optimisée** — Liste produits en `SliverList` + `SliverChildBuilderDelegate` (construction paresseuse) ; pas de chargement lourd au build ; états loading/erreur/vide gérés sans rebuild inutiles des tuiles.
5. **Données bien structurées** — Tables Drift dédiées (LocalProducts, StoreInventory, PendingActions, etc.) ; sync ordonnée : push des pending → pull → merge en Drift (last-write-wins) ; pas de logique de sync mélangée à l’UI.

## Rule #1: UI never waits for the network

- All **reads** come from the **local Drift database** first.
- The UI subscribes to **streams** (e.g. `watchProducts`, `watchInventoryQuantities`) so data appears instantly from cache and updates when sync runs.

## Data flow (Repository pattern)

```
UI (Widgets)
  → Riverpod providers
    → Repository (offline-first)
      → Local DB (Drift)  ← primary read path
      → Remote API (Supabase) ← sync only (background)
```

## Local database (Drift) responsibilities

| Table | Purpose |
|-------|--------|
| `LocalProducts` | Products by company (paginated) |
| `StoreInventory` | Quantity per store/product |
| `LocalSales` / `LocalSaleItems` | Sales (and synced flag) |
| `LocalCustomers` | Customers |
| `LocalSuppliers` | Suppliers |
| `PendingActions` | Queue of local changes to push (sale, stock_adjustment, customer, etc.) |

## Synchronization

1. **Push**: Sync service reads `PendingActions` where `synced = false`, sends each to Supabase (RPC or REST), then marks `synced = true`.
2. **Pull**: After push, fetches from Supabase (products, inventory, customers, stores) and **upserts** into Drift.
3. **Conflict resolution**: Last-write-wins using `updated_at` from Supabase; local Drift tables store `updated_at` for future use if needed.

## Performance

- **Pagination**: Use `limit` and `offset` for products and other large lists (e.g. `watchLocalProducts(companyId, limit: 100, offset: 0)`).
- **Indexes**: Supabase tables use indexed columns (`company_id`, `store_id`, `product_id`, `created_at`) for fast queries; Drift primary keys and foreign keys give efficient local lookups.
- **Avoid unnecessary network**: Do not call Supabase from the UI for read path; only the sync service and explicit “refresh” actions should hit the network.

## État par écran (ultra rapide ou pas)

| Écran | Lecture | Commentaire |
|-------|--------|-------------|
| **Produits** | ✅ Drift | `productsStreamProvider` + `inventoryQuantitiesStreamProvider`. **Ultra rapide.** |
| **Catégories / Marques** (onglets Produits) | ❌ Réseau | Toujours chargés via `ProductsPageProvider` (Supabase). |
| **Ventes** | ✅ Drift | `salesStreamProvider(companyId, storeId)` ; filtres (statut, dates) en mémoire. **Ultra rapide.** |
| **Clients** | ✅ Drift | `customersStreamProvider(companyId)`. **Ultra rapide.** |
| **Boutiques** (liste) | ✅ Drift | `storesStreamProvider(companyId)` — sync pull stores dans `LocalStores`. **Ultra rapide** si l’UI utilise le provider. |
| **Dashboard** | ❌ Réseau | `ReportsRepository` — KPIs et graphiques au réseau. |
| **Stock / Inventaire** | ✅ Drift | `productsStreamProvider` + `inventoryQuantitiesStreamProvider` + `storesStreamProvider` + `categoriesStreamProvider`. Paramètres/mouvements via API. |
| **POS** | ✅ Drift | Produits, clients, stock depuis Drift ; ventes/clients pending via PendingActions. |
| **Catégories / Marques** | ✅ Drift | `LocalCategories`, `LocalBrands` ; sync pull ; `categoriesStreamProvider`, `brandsStreamProvider`. |
| **Fournisseurs** | ✅ Drift | `suppliersStreamProvider` ; sync pull. |
| **Achats** | ✅ Hybride | Stores + fournisseurs depuis Drift ; liste achats depuis API ; sync au refresh. |
| **Transferts** | ✅ Hybride | Boutiques depuis Drift ; liste transferts depuis API ; sync au refresh. |
| **Dashboard** | ✅ Sync | KPIs depuis API ; sync v2 déclenché en arrière-plan au chargement. |

Sync (SyncServiceV2) : au démarrage et à la reconnexion, pull **products**, **inventory** (store), **customers**, **stores**, **sales** (avec items) vers Drift. Push des `PendingActions` (ventes, clients, ajustements stock) vers Supabase.

## File layout

- `lib/data/local/drift/app_database.dart` — Drift schema and DB class.
- `lib/data/repositories/offline/*_offline_repository.dart` — Repositories that read from Drift and expose streams; sync service uses them to pull and merge.
- `lib/data/sync/sync_service_v2.dart` — Push pending actions, then pull and merge into Drift.
- `lib/providers/offline_providers.dart` — Riverpod providers for `AppDatabase`, offline repositories, and sync service.

## Migrating a screen to offline-first

1. Replace direct Supabase repository calls with the corresponding **offline repository** (e.g. `ProductsOfflineRepository.watchProducts(companyId)`).
2. Use a **Riverpod StreamProvider** (or `FutureProvider` for one-shot) that depends on `productsOfflineRepositoryProvider` and `companyId`.
3. Trigger **sync** when the app comes to foreground or when the user pulls-to-refresh (call `SyncServiceV2.sync(...)` with current user and company).

## Supabase (backend)

- PostgreSQL remains the source of truth; RLS policies stay multi-tenant (`company_id`, `store_id`).
- Indexed columns are used for list and filter queries.
- No change required to existing RLS for offline-first; the app simply reads from Drift first and syncs in the background.
