import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Rôle d’imprimante (ticket thermique vs facture A4).
enum LocalPrinterRole {
  thermal,
  a4,
}

/// Portée d’enregistrement — aligné appweb.
enum PrinterStorageScope {
  user,
  device,
}

/// Données persistées (JSON).
class PrinterAssociationData {
  const PrinterAssociationData({
    required this.thermalPrinterName,
    required this.a4PrinterName,
    required this.scope,
    required this.updatedAtIso,
  });

  final String? thermalPrinterName;
  final String? a4PrinterName;
  final PrinterStorageScope scope;
  final String updatedAtIso;

  Map<String, dynamic> toJson() => {
    'v': 2,
    'thermalPrinterName': thermalPrinterName,
    'a4PrinterName': a4PrinterName,
    'scope': scope == PrinterStorageScope.device ? 'device' : 'user',
    'updatedAt': updatedAtIso,
  };

  static PrinterAssociationData? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['v'] != 2) return null;
      return PrinterAssociationData(
        thermalPrinterName: m['thermalPrinterName'] as String?,
        a4PrinterName: m['a4PrinterName'] as String?,
        scope: m['scope'] == 'device'
            ? PrinterStorageScope.device
            : PrinterStorageScope.user,
        updatedAtIso: m['updatedAt'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// Persistance locale des associations imprimante (même idée que l’app web).
class PrinterAssociationStorage {
  PrinterAssociationStorage._();

  static const int _version = 2;
  static const _clientIdKey = 'fs_client_install_id';

  static String _userKey(String userId, String companyId) =>
      'fs_qz_printers_v${_version}_u_${userId}_$companyId';

  static Future<String> _deviceKey(String companyId) async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_clientIdKey);
    if (id == null || id.isEmpty) {
      id =
          'fs_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
      await prefs.setString(_clientIdKey, id);
    }
    return 'fs_qz_printers_v${_version}_d_${companyId}_$id';
  }

  static Future<PrinterAssociationData?> _loadKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return PrinterAssociationData.fromJsonString(prefs.getString(key));
  }

  /// Nom d’imprimante enregistré pour [role] : d’abord portée **utilisateur**, puis **appareil**.
  static Future<String?> getResolvedPrinterName({
    required LocalPrinterRole role,
    required String userId,
    required String companyId,
  }) async {
    if (userId.isEmpty || companyId.isEmpty) return null;
    final userData = await _loadKey(_userKey(userId, companyId));
    String? n = role == LocalPrinterRole.thermal
        ? userData?.thermalPrinterName
        : userData?.a4PrinterName;
    if (n != null && n.trim().isNotEmpty) return n.trim();

    final dk = await _deviceKey(companyId);
    final devData = await _loadKey(dk);
    n = role == LocalPrinterRole.thermal
        ? devData?.thermalPrinterName
        : devData?.a4PrinterName;
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return null;
  }

  static String? _norm(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static Future<void> save({
    required String userId,
    required String companyId,
    required PrinterStorageScope scope,
    String? thermalPrinterName,
    String? a4PrinterName,
  }) async {
    if (userId.isEmpty || companyId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final data = PrinterAssociationData(
      thermalPrinterName: _norm(thermalPrinterName),
      a4PrinterName: _norm(a4PrinterName),
      scope: scope,
      updatedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
    final json = jsonEncode(data.toJson());
    if (scope == PrinterStorageScope.user) {
      await prefs.setString(_userKey(userId, companyId), json);
    } else {
      final dk = await _deviceKey(companyId);
      await prefs.setString(dk, json);
    }
  }

  /// Charge la config pour l’UI selon la portée sélectionnée.
  static Future<PrinterAssociationData?> loadForScope({
    required String userId,
    required String companyId,
    required PrinterStorageScope scope,
  }) async {
    if (userId.isEmpty || companyId.isEmpty) return null;
    if (scope == PrinterStorageScope.user) {
      return _loadKey(_userKey(userId, companyId));
    }
    final dk = await _deviceKey(companyId);
    return _loadKey(dk);
  }
}
