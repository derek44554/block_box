import 'package:flutter/material.dart';
import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/widgets/common/tag_widget.dart';
import '../../../widgets/border/block_border.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = block.maybeString('name');
    final intro = block.maybeString('intro');
    final bid = block.maybeString('bid');
    final tags = block.list<String>('tags');

    return GestureDetector(
      onTap: onTap ?? () {
        AppRouter.openBlockDetailPage(context, block);
      },
      child: BlockBorder(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.grid_view,
                    color: Colors.white,
                    size: 42,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '集合',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (title != null)
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              if (intro != null) ...[
                const SizedBox(height: 12),
                Text(
                  intro,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                TagWidget(tags: tags),
              ],
              const SizedBox(height: 24),
              if (bid != null)
                Text(
                  formatBid(bid),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    letterSpacing: 2,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

