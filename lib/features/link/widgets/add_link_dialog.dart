import 'package:flutter/material.dart';

import '../../../components/layout/collection_picker_sheet.dart';
import '../../../components/layout/recent_blocks_sheet.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';

/// 弹出“添加链接”对话框，返回用户输入的 BID；若取消返回 null。
Future<String?> showAddLinkDialog(BuildContext context) {
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return AppDialog(
        title: '添加链接',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogTextField(
              controller: controller,
              label: '链接 BID',
              hintText: '请输入链接的 BID',
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                final bid = await CollectionPickerSheet.show(dialogContext);
                if (bid != null && bid.trim().isNotEmpty && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(bid.trim());
                }
              },
              icon: const Icon(Icons.collections_bookmark_outlined, color: Colors.white70, size: 18),
              label: const Text(
                '更多集合',
                style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.6),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24, width: 0.6),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final bid = await RecentBlocksSheet.show(dialogContext);
                if (bid != null && bid.trim().isNotEmpty && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(bid.trim());
                }
              },
              icon: const Icon(Icons.history_outlined, color: Colors.white70, size: 18),
              label: const Text(
                '最近创建',
                style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 0.6),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24, width: 0.6),
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  foregroundColor: Colors.white70,
                ),
                child: const Text('取消'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('BID 不能为空')),
                    );
                    return;
                  }
                  Navigator.of(dialogContext).pop(value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('确定'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

