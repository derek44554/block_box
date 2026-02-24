import 'package:flutter/material.dart';

/// 从底部弹出的操作列表，符合应用的整体设计风格
///
/// 通常与 [showModalBottomSheet] 结合使用
class ActionSheet extends StatelessWidget {
  const ActionSheet({super.key, required this.title, required this.actions});

  /// 显示在顶部的标题
  final String title;

  /// 操作项列表
  final List<ActionItem> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// [ActionSheet] 中的操作项
class ActionItem extends StatelessWidget {
  const ActionItem({
    super.key,
    required this.label,
    this.icon,
    this.trailing,
    this.isDestructive = false,
    this.onTap,
  });

  /// 操作项的文本标签
  final String label;

  /// 显示在文本左侧的图标
  final IconData? icon;

  /// 显示在最右侧的组件
  final Widget? trailing;

  /// 是否为危险操作，若是则文本和图标会显示为红色
  final bool isDestructive;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFE55C5C) : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
