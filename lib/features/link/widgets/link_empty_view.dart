import 'package:flutter/material.dart';

/// 链接模块空态展示，提示当前 BID 下无可用的数据。
class LinkEmptyView extends StatelessWidget {
  const LinkEmptyView({super.key, this.message = '暂无相关链接数据'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

