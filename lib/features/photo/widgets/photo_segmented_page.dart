import 'package:flutter/material.dart';

import '../../../core/widgets/layouts/segmented_page_scaffold.dart';

class PhotoSegmentedPage extends StatelessWidget {
  const PhotoSegmentedPage({
    super.key,
    required this.photos,
    required this.collections,
    this.onPageChanged,
  });

  final Widget photos;
  final Widget collections;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedPageScaffold(
      title: '照片',
      segments: const ['照片', '集合'],
      pages: [
        photos,
        collections,
      ],
      controlWidth: 136,
      onIndexChanged: onPageChanged,
    );
  }
}

