import 'package:flutter/material.dart';

import '../widgets/connection_status_view.dart';

class ConnectionStatusPage extends StatelessWidget {
  const ConnectionStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节点状态'),
      ),
      body: const ConnectionStatusView(),
    );
  }
}
