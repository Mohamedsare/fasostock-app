import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Partage un vrai fichier CSV (écrit dans le dossier temporaire).
///
/// Pourquoi: sur certaines plateformes, `XFile.fromData(...)` peut apparaître comme un fichier vide.
/// Écrire sur disque puis partager le chemin est beaucoup plus fiable.
Future<void> shareCsvFile({
  required String filename,
  required Uint8List bytes,
  String? subject,
}) async {
  // share_plus sur Web ne garantit pas un "fichier" (souvent texte/nom uniquement).
  // On garde le comportement actuel (partage) ; le download Web peut être ajouté si besoin.
  if (kIsWeb) {
    await Share.share(String.fromCharCodes(bytes), subject: subject ?? filename);
    return;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv', name: filename)], subject: subject ?? filename);
}

/// Enregistre un CSV sur l'appareil (boîte de dialogue "Enregistrer sous").
///
/// C'est le comportement attendu pour "Exporter" (PC / téléphone) plutôt que "envoyer".
/// Retourne `true` si le fichier a été enregistré, `false` si l'utilisateur annule.
Future<bool> saveCsvFile({
  required String filename,
  required Uint8List bytes,
}) async {
  if (kIsWeb) {
    // Sur Web, FilePicker.saveFile n'est pas fiable. On retombe sur un partage texte.
    await Share.share(String.fromCharCodes(bytes), subject: filename);
    return false;
  }
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Enregistrer le fichier CSV',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
  );
  if (path == null || path.isEmpty) return false;
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return true;
}

