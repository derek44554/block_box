import 'package:flutter/material.dart';

import '../models/photo_models.dart';

class PhotoCard extends StatelessWidget {
  const PhotoCard({
    super.key,
    required this.item,
    required this.size,
    required this.onTap,
    this.image,
  });

  final PhotoImage item;
  final double size;
  final VoidCallback onTap;
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Hero(
          tag: item.heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: const BoxDecoration(color: Color(0xFF222225)),
              child: _buildImageContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (image != null) {
      return Image(
        image: image!,
        fit: BoxFit.cover,
      );
    }

    return const Center(
      child: Icon(Icons.broken_image, color: Colors.white24, size: 20),
    );
  }
}

