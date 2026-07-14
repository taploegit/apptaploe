import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

Future<String?> scanTaploeQrCode(BuildContext context) async {
  return showDialog<String?>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        elevation: 0,
        backgroundColor: TaploeColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: TaploeColors.border),
        ),
        title: const Text('Escanear QR'),
        content: Text(
          'El escaneo con cámara está disponible desde el navegador.',
          style: GoogleFonts.dmSans(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      );
    },
  );
}

class TaploeQrScannerView extends StatelessWidget {
  final ValueChanged<String> onDetected;
  final VoidCallback onCancel;

  const TaploeQrScannerView({
    super.key,
    required this.onDetected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Escanea el QR de tu tarjeta',
            style: GoogleFonts.outfit(
              color: context.text,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'El escaneo con cámara está disponible desde el navegador.',
            style: GoogleFonts.dmSans(color: context.muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        ],
      ),
    );
  }
}
