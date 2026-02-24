import 'package:flutter/material.dart';

typedef QuickActionCallback = void Function(BlockQuickAction action);

class BlockQuickActions extends StatelessWidget {
  const BlockQuickActions({
    super.key,
    required this.actions,
    required this.onTap,
  });

  final List<BlockQuickAction> actions;
  final QuickActionCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 480;
        final children = actions
            .map(
              (action) => Expanded(
                child: _QuickActionButton(
                  action: action,
                  onTap: () => onTap(action),
                ),
              ),
            )
            .toList();

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < children.length ? 12 : 0),
                  child: Row(
                    children: [
                      children[i],
                      if (i + 1 < children.length) ...[
                        const SizedBox(width: 12),
                        children[i + 1],
                      ],
                    ],
                  ),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class BlockQuickAction {
  const BlockQuickAction({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final BlockQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

