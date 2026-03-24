# FasoStock — Application Flutter

Version Flutter de l'application FasoStock (même API Supabase que l'app web).

## Prérequis

- Flutter SDK (stable)
- Compte Supabase (même projet que l'app web)

## Configuration

Variables d'environnement (même que le web) :

- `SUPABASE_URL` : URL du projet Supabase
- `SUPABASE_ANON_KEY` : Clé anon publique

Lancer avec :

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Sous Windows PowerShell, passer les définitions entre guillemets si nécessaire.

## Structure

- `lib/core/` — Config (env, routes), erreurs, thème
- `lib/services/` — Auth (Supabase)
- `lib/data/models/` — Modèles (Profile pour l’instant)
- `lib/providers/` — État global (AuthProvider)
- `lib/navigation/` — GoRouter et redirect (auth / super_admin)
- `lib/features/` — Écrans (auth/login, dashboard, placeholder pour les autres)
- `lib/shared/utils/` — formatCurrency, etc.

## Étapes suivantes (cahier.md)

- Étape 4 : Modèles et services API (tous les DTO et appels Supabase)
- Étape 5 : Auth complète (persistance, refresh, permissions)
- Étape 6 : Navigation et shell (sidebar, bottom nav)
- Étape 7–8 : Reproduction écran par écran
