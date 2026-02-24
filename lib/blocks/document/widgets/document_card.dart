import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../state/block_provider.dart';
import '../../../widgets/border/document_border.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = block.maybeString('name');
    final content = block.getString('content');
    final bid = block.maybeString('bid');
    final createdAt = block.getDateTime('createdAt');

    return GestureDetector(
      onTap:
          onTap ??
          () {
            // Try to get the latest Block from BlockProvider before opening detail page
            BlockModel blockToOpen = block;
            if (bid != null) {
              try {
                final blockProvider = context.read<BlockProvider>();
                final latestBlock = blockProvider.getBlock(bid);
                if (latestBlock != null) {
                  blockToOpen = latestBlock;
                  debugPrint('DocumentCard: Using latest Block from BlockProvider for BID: $bid');
                }
              } catch (e) {
                debugPrint('DocumentCard: Could not get BlockProvider, using original block: $e');
              }
            }
            AppRouter.openBlockDetailPage(context, blockToOpen);
          },
      child: DocumentBorder(
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
                  Icon(Icons.article_outlined, color: Colors.white, size: 42),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '文档',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (title != null) ...[
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
              ],
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (bid != null)
                    Text(
                      formatBid(bid),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 2,
                      ),
                    ),
                  if (createdAt != null)
                    Text(
                      formatDate(createdAt),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
