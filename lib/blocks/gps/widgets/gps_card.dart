import 'package:flutter/material.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../widgets/border/document_border.dart';

class GpsCard extends StatelessWidget {
  const GpsCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final intro = block.maybeString('intro');
    final bid = block.maybeString('bid');
    final gpsData = block.map('gps');
    
    String? longitude;
    String? latitude;
    if (gpsData.isNotEmpty) {
      final lon = gpsData['longitude'];
      final lat = gpsData['latitude'];
      if (lon != null) longitude = lon.toString();
      if (lat != null) latitude = lat.toString();
    }

    final addTime = block.maybeString('add_time');
    final createdAt = block.getDateTime('createdAt');

    return GestureDetector(
      onTap: onTap ?? () {
        AppRouter.openBlockDetailPage(context, block);
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
                  Icon(Icons.location_on, color: Colors.white, size: 42),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'GPS 位置',
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
              
              // 经纬度信息
              if (longitude != null && latitude != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCoordinateRow(Icons.swap_horiz, '经度', longitude),
                      const SizedBox(height: 12),
                      _buildCoordinateRow(Icons.swap_vert, '纬度', latitude),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              
              // 介绍
              if (intro != null) ...[
                Text(
                  intro,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
              ],
              
              const SizedBox(height: 4),
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
                  if (addTime != null && addTime.isNotEmpty)
                    Text(
                      addTime,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                    )
                  else if (createdAt != null)
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

  Widget _buildCoordinateRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white60,
          size: 16,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
