import 'dart:io';

import 'package:http/io_client.dart' as io_client;
import 'package:http/http.dart' as http;

/// Client HTTP avec plafond de connexions par hôte (Windows : évite en partie
/// « Le délai de temporisation de sémaphore a expiré » sous charge réseau).
http.Client? buildSupabaseHttpClient() {
  final hc = HttpClient();
  hc.maxConnectionsPerHost = 8;
  hc.connectionTimeout = const Duration(seconds: 30);
  return io_client.IOClient(hc);
}
