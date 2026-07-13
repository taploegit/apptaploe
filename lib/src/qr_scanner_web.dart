// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

Future<String?> scanTaploeQrCode(BuildContext context) async {
  return showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: TaploeQrScannerView(
          onDetected: (value) => Navigator.pop(dialogContext, value),
          onCancel: () => Navigator.pop(dialogContext),
        ),
      ),
    ),
  );
}

class TaploeQrScannerView extends StatefulWidget {
  final ValueChanged<String> onDetected;
  final VoidCallback onCancel;

  const TaploeQrScannerView({
    super.key,
    required this.onDetected,
    required this.onCancel,
  });

  @override
  State<TaploeQrScannerView> createState() => _TaploeQrScannerViewState();
}

class _TaploeQrScannerViewState extends State<TaploeQrScannerView> {
  late final String viewType;
  late final html.VideoElement video;
  html.MediaStream? stream;
  Timer? scanTimer;
  JSObject? detector;
  String? errorMessage;
  bool starting = true;
  bool detected = false;

  @override
  void initState() {
    super.initState();
    viewType = 'taploe-qr-scanner-${DateTime.now().microsecondsSinceEpoch}';
    video = html.VideoElement()
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', 'true')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '20px'
      ..style.backgroundColor = '#050505';

    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);
    _start();
  }

  Future<void> _start() async {
    if (!globalContext.has('BarcodeDetector')) {
      setState(() {
        starting = false;
        errorMessage = 'Este navegador no permite escanear con cámara.';
      });
      return;
    }

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        setState(() {
          starting = false;
          errorMessage =
              'Permite el acceso a la cámara para escanear tu tarjeta.';
        });
        return;
      }

      stream = await mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': {'ideal': 'environment'},
        },
      });
      video.srcObject = stream;
      await video.play();

      final barcodeDetector = globalContext['BarcodeDetector'] as JSFunction;
      detector = barcodeDetector.callAsConstructor<JSObject>(
        {
          'formats': ['qr_code'],
        }.jsify(),
      );

      if (!mounted) return;
      setState(() => starting = false);
      scanTimer = Timer.periodic(
        const Duration(milliseconds: 650),
        (_) => _scanFrame(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        starting = false;
        errorMessage =
            'Permite el acceso a la cámara para escanear tu tarjeta.';
      });
    }
  }

  Future<void> _scanFrame() async {
    if (detected || detector == null || video.readyState < 2) return;

    try {
      final promise = detector!.callMethod<JSPromise<JSArray<JSObject>>>(
        'detect'.toJS,
        JSObject.fromInteropObject(video),
      );
      final result = await promise.toDart;
      final length = result.length;
      if (length == 0) return;

      final first = result[0];
      final raw = (first['rawValue'] as JSString?)?.toDart;
      if (raw == null || raw.trim().isEmpty) return;

      detected = true;
      _stopCamera();
      if (!mounted) return;
      widget.onDetected(raw.trim());
    } catch (_) {
      // Some browsers throw while the video is settling. The next frame can work.
    }
  }

  void _stopCamera() {
    scanTimer?.cancel();
    scanTimer = null;
    final tracks = stream?.getTracks() ?? const <html.MediaStreamTrack>[];
    for (final track in tracks) {
      track.stop();
    }
    video.srcObject = null;
    stream = null;
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: BoxDecoration(
        color: TaploeColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: TaploeColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF2458FF),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Escanea el QR de tu tarjeta',
                  style: GoogleFonts.dmSans(
                    color: context.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cerrar',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage == null
                ? 'Coloca el QR dentro del recuadro para identificarla.'
                : 'Permite el acceso a la cámara para escanear tu tarjeta.',
            style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HtmlElementView(viewType: viewType),
                  if (starting)
                    const ColoredBox(
                      color: Color(0xFF050505),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2458FF),
                        ),
                      ),
                    ),
                  if (errorMessage != null)
                    ColoredBox(
                      color: TaploeColors.white,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              color: context.muted,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!starting && errorMessage == null)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 190,
                          height: 190,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: TaploeColors.blue,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage == null
                ? 'Lectura automática activa.'
                : 'Puedes cerrar e intentarlo de nuevo después de habilitar cámara.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(color: context.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (errorMessage != null)
            TaploeQrScannerButton(
              label: 'Solicitar permiso',
              icon: Icons.videocam_outlined,
              onPressed: () {
                setState(() {
                  errorMessage = null;
                  starting = true;
                  detected = false;
                });
                _start();
              },
            )
          else
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancelar'),
            ),
        ],
      ),
    );
  }
}

class TaploeQrScannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const TaploeQrScannerButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: TaploeColors.blue,
          foregroundColor: TaploeColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
