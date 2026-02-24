import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../common/block_detail_page.dart';
import '../../../state/block_detail_listener_mixin.dart';


class GpsDetailPage extends StatefulWidget {
  final BlockModel block;

  const GpsDetailPage({super.key, required this.block});

  @override
  State<GpsDetailPage> createState() => _GpsDetailPageState();
}

class _GpsDetailPageState extends State<GpsDetailPage> with BlockDetailListenerMixin {
  double? _longitude;
  double? _latitude;
  String? _intro;
  String? _bid;
  String? _addTime;
  DateTime? _createdAt;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _loadDataFromBlock(updatedBlock);
    });
  }

  @override
  void initState() {
    super.initState();
    startBlockProviderListener();
    _loadDataFromBlock(widget.block);
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  void _loadDataFromBlock(BlockModel block) {
    final gpsData = block.map('gps');
    if (gpsData.isNotEmpty) {
      final lon = gpsData['longitude'];
      final lat = gpsData['latitude'];
      if (lon != null) _longitude = double.tryParse(lon.toString());
      if (lat != null) _latitude = double.tryParse(lat.toString());
    }

    _intro = block.maybeString('intro');
    _bid = block.maybeString('bid');
    _addTime = block.maybeString('add_time');
    _createdAt = block.getDateTime('createdAt');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: Container(
        color: Colors.black,
        child: RefreshIndicator(
          onRefresh: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlockDetailPage(block: widget.block),
              ),
            );
          },
          color: Colors.white,
          backgroundColor: Colors.grey.shade900,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 48),
                    if (_longitude != null && _latitude != null)
                      _buildGpsSection(_longitude!, _latitude!),
                    _buildTimeInfo(),
                    if (_intro != null && _intro!.isNotEmpty) _buildIntro(_intro!),
                    if (_bid != null && _bid!.isNotEmpty) _buildBid(_bid!),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'GPS 位置',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsSection(double longitude, double latitude) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 大图标 - 居中
          Center(
            child: Container(
              width: 120,
              height: 120,
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 64,
              ),
            ),
          ),

          // 坐标信息卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
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
                  longitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 16),
                _buildCoordinateRow(
                  Icons.swap_vert,
                  '纬度',
                  latitude.toStringAsFixed(6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 地图按钮
          _buildMapButton(latitude, longitude),
        ],
      ),
    );
  }

  Widget _buildCoordinateRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white60,
          size: 20,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapButton(double latitude, double longitude) {
    return InkWell(
      onTap: () => _openInGoogleMaps(latitude, longitude),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text(
                  '在 Google 地图中打开',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Icon(
              Icons.open_in_new,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInGoogleMaps(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开 Google 地图')),
        );
      }
    }
  }

  Widget _buildTimeInfo() {
    final displayTime = _addTime ?? (_createdAt != null ? formatDate(_createdAt!) : null);
    
    if (displayTime == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_outlined,
            color: Colors.white54,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            displayTime,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '介绍',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            intro,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.6,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBid(String bid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 36, top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BID',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            formatBid(bid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

