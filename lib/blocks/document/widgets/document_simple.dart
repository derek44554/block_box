import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';

class DocumentSimple extends StatelessWidget {
  const DocumentSimple({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = block.getString('content').trim();
    final timeText = _resolveTime();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () => AppRouter.openBlockDetailPage(context, block),
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.06),
        highlightColor: Colors.white.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.07),
                          width: 0.6,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 320),
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                          gradient: LinearGradient(
                            colors: [Color(0xFF1A1A1F), Color(0xFF131317)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              content.isEmpty ? '无内容' : content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.65,
                                letterSpacing: 0.4,
                              ),
                            ),
                            if (timeText.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 18,
                      bottom: -8,
                      child: Transform.rotate(
                        angle: -0.6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFF131317),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(8),
                              bottomLeft: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveTime() {
    final createdAt = block.getDateTime('createdAt');
    if (createdAt != null) {
      return formatDate(createdAt);
    }
    final updatedAt = block.getDateTime('updatedAt');
    if (updatedAt != null) {
      return formatDate(updatedAt);
    }
    final addTime = block.maybeString('add_time');
    if (addTime != null && addTime.isNotEmpty) {
      return addTime;
    }
    final time = block.maybeString('time');
    if (time != null && time.isNotEmpty) {
      return time;
    }
    return '';
  }
}
