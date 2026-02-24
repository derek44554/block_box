import 'package:flutter/material.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/formatters/bid_formatter.dart';


/// GPS 位置简单卡片，用于显示地理位置信息
class GpsSimple extends StatelessWidget {
  const GpsSimple({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final intro = block.maybeString('intro') ?? '';
    final gpsData = block.map('gps');
    final timeText = _resolveTime();

    String? longitude;
    String? latitude;
    if (gpsData.isNotEmpty) {
      final lon = gpsData['longitude'];
      final lat = gpsData['latitude'];
      if (lon != null) longitude = lon.toString();
      if (lat != null) latitude = lat.toString();
    }

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
                            // GPS 图标和标题
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'GPS 位置',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            
                            // 经纬度信息 - 上下布局
                            if (longitude != null && latitude != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    _buildCoordinateRow(
                                      Icons.swap_horiz,
                                      '经度',
                                      longitude,
                                    ),
                                    const SizedBox(height: 10),
                                    _buildCoordinateRow(
                                      Icons.swap_vert,
                                      '纬度',
                                      latitude,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // 介绍
                            if (intro.isNotEmpty) ...[
                              Text(
                                intro,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.5,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 10),
                            ],

                            // 时间
                            if (timeText.isNotEmpty)
                              Text(
                                timeText,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
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

  Widget _buildCoordinateRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white60,
          size: 16,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  String _resolveTime() {
    final addTime = block.maybeString('add_time');
    if (addTime != null && addTime.isNotEmpty) {
      return addTime;
    }
    final createdAt = block.getDateTime('createdAt');
    if (createdAt != null) {
      return formatDate(createdAt);
    }
    final updatedAt = block.getDateTime('updatedAt');
    if (updatedAt != null) {
      return formatDate(updatedAt);
    }
    return '';
  }
}

