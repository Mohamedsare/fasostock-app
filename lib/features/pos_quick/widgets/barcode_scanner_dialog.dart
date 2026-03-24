import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Dialogue de scan caméra pour la caisse rapide. Retourne le code-barres détecté via [onDetected].
/// L'appelant doit vérifier la plateforme (Windows/Linux non supportés) et appeler [onUnsupported] si besoin.
void showBarcodeScannerDialog({
  required BuildContext context,
  required void Function(String code) onDetected,
  void Function()? onUnsupported,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _BarcodeScannerDialog(
      onDetected: (code) {
        Navigator.of(context).pop();
        onDetected(code);
      },
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog({
    required this.onDetected,
    required this.onClose,
  });

  final void Function(String code) onDetected;
  final VoidCallback onClose;

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  bool _alreadySent = false;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_alreadySent) return;
    final list = capture.barcodes;
    if (list.isEmpty) return;
    final barcode = list.first;
    final code = barcode.rawValue;
    if (code == null || code.trim().isEmpty) return;
    _alreadySent = true;
    widget.onDetected(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < 400 || size.height < 500;
    final width = isNarrow ? size.width - 32 : 400.0;
    final height = isNarrow ? (size.height * 0.55).clamp(280.0, 500.0) : 400.0;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: isNarrow ? 16 : 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(12, 12, 8, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Scannez un code-barres',
                          style: TextStyle(color: Colors.white, fontSize: isNarrow ? 14 : 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        tooltip: 'Fermer',
                        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
