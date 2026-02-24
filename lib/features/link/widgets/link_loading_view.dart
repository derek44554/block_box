import 'package:flutter/material.dart';

/// 链接模块加载态展示，保持与全局设计一致的提示。
class LinkLoadingView extends StatelessWidget {
  const LinkLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
      ),
    );
  }
}

