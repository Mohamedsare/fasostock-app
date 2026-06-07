import 'package:http/http.dart' as http;

import 'supabase_http_client_factory_stub.dart'
    if (dart.library.io) 'supabase_http_client_factory_io.dart' as impl;

/// Client HTTP optionnel pour [Supabase.initialize] (null = défaut du SDK).
http.Client? buildSupabaseHttpClient() => impl.buildSupabaseHttpClient();
