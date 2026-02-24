import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../blocks/file/models/file_card_data.dart';


class FileViewer {
  FileViewer._();

  static void showImage(BuildContext context, FileCardData data, {Uint8List? bytes}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ImageViewerPage(
          title: data.fileName,
          imageBytes: bytes,
        ),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  const _ImageViewerPage({required this.title, this.imageBytes});

  final String title;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.contain)
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
