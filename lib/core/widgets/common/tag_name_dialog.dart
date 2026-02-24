import 'package:flutter/material.dart';

import '../dialogs/app_dialog.dart';

/// 通用输入标签名称的弹窗，内部自管 TextEditingController 生命周期，
/// 避免业务页面手动回收导致的异常。
class TagNameDialog extends StatefulWidget {
  const TagNameDialog({
    super.key,
    required this.title,
    required this.description,
    required this.label,
    required this.hintText,
    this.validator,
  });

  final String title;
  final String description;
  final String label;
  final String hintText;
  final String? Function(String?)? validator;

  @override
  State<TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<TagNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.title,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.description,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            AppDialogTextField(
              controller: _controller,
              label: widget.label,
              hintText: widget.hintText,
              validator: widget.validator,
            ),
          ],
        ),
      ),
      actions: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _handleSave,
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
