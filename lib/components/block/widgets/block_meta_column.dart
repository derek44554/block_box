import 'package:flutter/material.dart';

import 'block_meta_tile.dart';

class BlockMetaField {
  const BlockMetaField({required this.label, required this.value});

  final String label;
  final String value;
}

class BlockMetaColumn extends StatelessWidget {
  const BlockMetaColumn({super.key, required this.fields});

  final List<BlockMetaField> fields;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: const Text(
          '暂无信息',
          style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 0.5),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < fields.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == fields.length - 1 ? 0 : 16),
            child: BlockMetaTile(label: fields[i].label, value: fields[i].value),
          ),
      ],
    );
  }
}

