import 'package:flutter/material.dart';

/// AppDialog 提供统一的弹窗容器样式，确保标题、背景与间距一致。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.actions,
    this.maxWidth = 360,
    this.padding = const EdgeInsets.fromLTRB(24, 20, 24, 16),
  });

  final String title;
  final Widget content;
  final Widget? actions;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: actions,
            ),
          ],
        ),
      ),
    );
  }
}

/// AppDialogTextField 提供统一的弹窗内文本输入样式。
class AppDialogTextField extends StatefulWidget {
  const AppDialogTextField({
    super.key,
    required this.controller,
    this.label,
    required this.hintText,
    this.validator,
    this.keyboardType,
    this.initialObscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String hintText;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool initialObscureText;
  final int? minLines;
  final int? maxLines;
  final void Function(String)? onSubmitted;

  @override
  State<AppDialogTextField> createState() => _AppDialogTextFieldState();
}

class _AppDialogTextFieldState extends State<AppDialogTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.initialObscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscureText,
          minLines: widget.minLines,
          maxLines: _obscureText ? 1 : widget.maxLines,
          onFieldSubmitted: widget.onSubmitted,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: widget.initialObscureText
                ? IconButton(
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54, size: 18),
                    splashRadius: 16,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.36)),
            ),
            errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 11),
          ),
          validator: widget.validator,
        ),
      ],
    );
  }
}
