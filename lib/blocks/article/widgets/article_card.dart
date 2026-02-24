import 'package:flutter/material.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../widgets/border/article_border.dart';
import '../../../core/widgets/common/tag_widget.dart';

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final title = block.maybeString('name');
    final intro = block.maybeString('intro');
    final bid = block.maybeString('bid');
    final createdAt = block.getDateTime('createdAt');
    final coverUrl = block.maybeString('coverUrl');
    final tags = block.getList<String>('tags');

    return GestureDetector(
      onTap: onTap ?? () {
        AppRouter.openBlockDetailPage(context, block);
      },
      child: ArticleBorder(
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
                    Icons.article,
                    color: Colors.white,
                    size: 42,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '文章',
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
              if (coverUrl != null) ...[
                Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white24,
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderCover();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (title != null)
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 18,
                        height: 1.3,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (intro != null) ...[
                const SizedBox(height: 10),
                Text(
                  intro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                TagWidget(tags: tags),
              ],
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

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          color: Colors.white24,
          size: 32,
        ),
      ),
    );
  }
}
