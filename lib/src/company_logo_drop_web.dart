// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class CompanyLogoDropFile {
  final String name;
  final Uint8List bytes;

  const CompanyLogoDropFile({required this.name, required this.bytes});
}

class CompanyLogoDropSubscription {
  final FutureOr<void> Function(CompanyLogoDropFile file) onDropped;
  final void Function(bool active)? onDragActive;
  late final StreamSubscription<html.MouseEvent> _dragOver;
  late final StreamSubscription<html.MouseEvent> _dragLeave;
  late final StreamSubscription<html.MouseEvent> _drop;

  CompanyLogoDropSubscription({required this.onDropped, this.onDragActive}) {
    final body = html.document.body;
    _dragOver = body!.onDragOver.listen((event) {
      event.preventDefault();
      onDragActive?.call(true);
    });
    _dragLeave = body.onDragLeave.listen((event) {
      event.preventDefault();
      onDragActive?.call(false);
    });
    _drop = body.onDrop.listen((event) async {
      event.preventDefault();
      onDragActive?.call(false);
      try {
        final files = event.dataTransfer.files;
        if (files == null || files.isEmpty) return;
        final file = files.first;
        if (!_allowed(file)) return;
        final bytes = await _readFileBytes(file);
        await onDropped(CompanyLogoDropFile(name: file.name, bytes: bytes));
      } catch (_) {
        return;
      }
    });
  }

  Future<Uint8List> _readFileBytes(html.File file) {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoad.listen((_) {
      try {
        final result = reader.result;
        if (result is String) {
          final comma = result.indexOf(',');
          final payload = comma == -1 ? result : result.substring(comma + 1);
          completer.complete(base64Decode(payload));
        } else if (result is ByteBuffer) {
          completer.complete(Uint8List.view(result));
        } else if (result is Uint8List) {
          completer.complete(result);
        } else {
          completer.completeError(StateError('No se pudo leer el archivo.'));
        }
      } catch (error) {
        completer.completeError(error);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('No se pudo leer el archivo.'));
      }
    });
    reader.readAsDataUrl(file);
    return completer.future;
  }

  void dispose() {
    _dragOver.cancel();
    _dragLeave.cancel();
    _drop.cancel();
  }

  static bool _allowed(html.File file) {
    final type = file.type.toLowerCase();
    final name = file.name.toLowerCase();
    return type == 'image/jpeg' ||
        type == 'image/png' ||
        type == 'image/webp' ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
  }
}
