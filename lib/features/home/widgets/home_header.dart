import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:block_app/core/network/models/connection_model.dart';
import '../../../state/connection_provider.dart';
import '../../settings/pages/settings_page.dart';
import '../pages/home_connection_page.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final connection = provider.activeConnection;
    final status = connection?.status ?? ConnectionStatus.offline;
    final displayAddress = _formatAddress(connection?.address);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const HomeConnectionPage(),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedStatusDot(status: status),
                const SizedBox(width: 8),
                Text(
                  displayAddress,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
        const SizedBox(width: 12),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SettingsPage(),
            ),
          ),
          icon: const Icon(Icons.settings, color: Colors.white70, size: 18),
          splashRadius: 20,
        ),
        ],
      ),
    );
  }

  String _formatAddress(String? address) {
    if (address == null || address.isEmpty) {
      return '点击添加连接';
    }
    var value = address.replaceFirst(RegExp(r'^https?://'), '');
    final colonIndex = value.indexOf(':');
    if (colonIndex != -1) {
      value = value.substring(0, colonIndex);
    }
    return value;
  }
}

class _AnimatedStatusDot extends StatefulWidget {
  const _AnimatedStatusDot({required this.status});

  final ConnectionStatus status;

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (_shouldAnimate(widget.status)) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate(widget.status)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _shouldAnimate(ConnectionStatus status) {
    return status == ConnectionStatus.connected || status == ConnectionStatus.connecting;
  }

  Color _statusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF4CAF50);
      case ConnectionStatus.connecting:
        return const Color(0xFF26C6DA);
      case ConnectionStatus.offline:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(widget.status);
    if (!_shouldAnimate(widget.status)) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final delta = (progress - 0.5).abs();
        final scaleValue = 1.0 + 0.24 * (0.5 - delta);
        final blur = 6.0 + 14.0 * (0.5 - delta);
        final opacity = 0.35 + 0.5 * (0.5 - delta);
        return Transform.scale(
          scale: scaleValue,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(opacity),
                  blurRadius: blur,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

