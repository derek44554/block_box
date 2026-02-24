import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// 显示一个通用的确认对话框
///
/// 返回 `true` 表示用户点击了确认按钮，`false` 表示点击了取消，`null` 表示点击了遮罩层关闭
Future<bool?> showConfirmationDialog({
  required BuildContext context,
  required String title,
  required Widget content,
  String confirmText = '确认',
  String cancelText = '取消',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AppDialog(
        title: title,
        content: content,
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  foregroundColor: Colors.white70,
                ),
                child: Text(cancelText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDestructive ? Colors.redAccent : Colors.white,
                  foregroundColor: isDestructive ? Colors.white : Colors.black,
                ),
                child: Text(confirmText),
              ),
            ),
          ],
        ),
      );
    },
  );
}
