import 'package:flutter/material.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../core/utils/formatters/file_size_formatter.dart';
import '../../../utils/file_category.dart';
import '../../../widgets/border/document_border.dart';
import '../models/file_card_data.dart';
import '../pages/file_detail_page.dart';


class FileCard extends StatelessWidget {
  const FileCard({super.key, required this.block, required this.cardData});

  final BlockModel block;
  final FileCardData cardData;

  String get _fileName => block.getString('fileName');

  String get _extension => cardData.extension;

  String get _displayName {
    final fileName = _fileName;
    if (fileName.isEmpty) {
      return cardData.nameWithoutExtension;
    }
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return fileName;
    return fileName.substring(0, lastDot);
  }

  @override
  Widget build(BuildContext context) {
    final category = resolveFileCategory(_extension);
    final bid = block.maybeString('bid');
    final intro = block.maybeString('intro');

    return GestureDetector(
      onTap: () => AppRouter.openBlockDetailPage(context, block),
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
                children: [
                  Icon(category.icon, color: Colors.white, size: 42),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      category.label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  if (_extension.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Text(
                        _extension.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_displayName.isNotEmpty)
                Text(
                  _displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 17,
                        height: 1.3,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (intro != null) ...[
                const SizedBox(height: 10),
                Text(
                  intro,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (bid != null)
                    Text(
                      formatBid(bid),
                      style: const TextStyle(color: Colors.white, fontSize: 15, letterSpacing: 2),
                    ),
                  _buildMetaBadges(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPage() {
    return FileDetailPage(block: block);
  }

  Widget _buildMetaBadges() {
    final fileSize = cardData.ipfsSize != null ? formatFileSize(cardData.ipfsSize!) : null;
    final isEncrypted = cardData.encryption?.isSupported == true;

    if (fileSize == null && !isEncrypted) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      if (isEncrypted)
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: Colors.white70, size: 15),
        ),
      if (fileSize != null) ...[
        if (isEncrypted) const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white24, width: 0.4),
          ),
          child: Text(
            fileSize,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ];

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

