import 'package:http/http.dart' as http;

/// Web / plateformes sans `dart:io` : client HTTP par défaut de Supabase.
http.Client? buildSupabaseHttpClient() => null;
