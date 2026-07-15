import 'dart:async';
import 'dart:typed_data';

class CompanyLogoDropFile {
  final String name;
  final Uint8List bytes;

  const CompanyLogoDropFile({required this.name, required this.bytes});
}

class CompanyLogoDropSubscription {
  CompanyLogoDropSubscription({
    required FutureOr<void> Function(CompanyLogoDropFile file) onDropped,
    void Function(bool active)? onDragActive,
  });

  void dispose() {}
}
