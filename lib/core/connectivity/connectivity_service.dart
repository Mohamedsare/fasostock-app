import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Expose l'état de la connexion et un stream de changements.
/// Sur desktop (Windows/macOS/Linux), le plugin peut renvoyer [none] à tort — on considère alors en ligne.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();

  bool get isOnline => _isOnline;
  Stream<bool> get onConnectivityChanged => _controller.stream;

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Initialise et écoute les changements. À appeler au démarrage de l'app.
  Future<void> init() async {
    await _update();
    _connectivity.onConnectivityChanged.listen((_) => _update());
  }

  Future<void> _update() async {
    final result = await _connectivity.checkConnectivity();
    final wasOnline = _isOnline;
    final allNone = result.every((e) => e == ConnectivityResult.none);
    // Sur desktop, le plugin renvoie souvent "none" alors que le réseau est OK : considérer en ligne.
    _isOnline = allNone ? _isDesktop : true;
    if (_isOnline != wasOnline) _controller.add(_isOnline);
  }

  /// Vérifie une fois l'état actuel (utile avant une action critique).
  Future<bool> checkOnce() async {
    await _update();
    return _isOnline;
  }

  void dispose() {
    _controller.close();
  }
}
