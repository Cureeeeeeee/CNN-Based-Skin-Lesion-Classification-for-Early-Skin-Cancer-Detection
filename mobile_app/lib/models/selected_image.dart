import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

class SelectedImage {
  const SelectedImage({
    required this.file,
    required this.bytes,
  });

  final XFile file;
  final Uint8List bytes;

  String get name => file.name.isEmpty ? 'selected_image.jpg' : file.name;
}
