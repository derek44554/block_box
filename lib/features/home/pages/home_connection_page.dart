import 'package:flutter/material.dart';

import '../../../../core/widgets/layouts/segmented_page_scaffold.dart';
import '../widgets/connection_list_view.dart';
import '../widgets/node_info_view.dart';

class HomeConnectionPage extends StatelessWidget {
  const HomeConnectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SegmentedPageScaffold(
      title: '连接设置',
      segments: const ['节点', '列表'],
      controlWidth: 150,
      pages: const [
        NodeInfoView(),
        ConnectionListView(),
      ],
    );
  }
}
