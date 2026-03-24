import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

/// Enregistre un fichier binaire (PDF, XLSX, etc.) sur l'appareil via "Enregistrer sous".
///
/// Sur Web, retombe sur un partage (le download Web peut être ajouté plus tard).
Future<bool> saveBytesFile({
  required String dialogTitle,
  required String filename,
  required Uint8List bytes,
  required List<String> allowedExtensions,
}) async {
  if (kIsWeb) {
    await Share.share('Fichier: $filename (${bytes.length} octets)', subject: filename);
    return false;
  }
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
  );
  if (path == null || path.isEmpty) return false;
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return true;
}

