import 'package:flutter/material.dart';

import '../../../components/block/block_card_factory.dart';
import '../../../core/models/block_model.dart';

class TagBlockList extends StatelessWidget {
  const TagBlockList({super.key, required this.blocks, required this.header});

  final List<BlockModel> blocks;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                header,
                for (var i = 0; i < blocks.length; i++) ...[
                  BlockCardFactory.build(blocks[i]),
                  if (i != blocks.length - 1) const SizedBox(height: 16),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

