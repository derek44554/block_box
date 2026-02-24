import 'package:block_app/features/trace/pages/trace_record_page.dart';
import 'package:block_app/features/trace/pages/trace_setting_page.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/layouts/segmented_page_scaffold.dart';

/// 痕迹页面入口
class TracePage extends StatefulWidget {
  const TracePage({super.key});

  @override
  State<TracePage> createState() => _TracePageState();
}

class _TracePageState extends State<TracePage> {
  bool _showGps = false; // 是否显示GPS，默认不显示，不持久化

  void _toggleShowGps(bool value) {
    setState(() {
      _showGps = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedPageScaffold(
      title: '痕迹',
      segments: const ['记录', '设置'],
      controlWidth: 150,
      headerPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      backgroundColor: Colors.black,
      pages: [
        TraceRecordPage(showGps: _showGps),
        TraceSettingPage(showGps: _showGps, onShowGpsChanged: _toggleShowGps),
      ],
    );
  }
}
