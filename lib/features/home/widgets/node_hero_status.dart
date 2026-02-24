import 'package:flutter/material.dart';

import 'package:block_app/core/network/models/connection_model.dart';

class NodeHeroStatus extends StatefulWidget {
  const NodeHeroStatus({super.key, required this.connection});

  final ConnectionModel connection;

  @override
  State<NodeHeroStatus> createState() => _NodeHeroStatusState();
}

class _NodeHeroStatusState extends State<NodeHeroStatus> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0,
      upperBound: 1,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant NodeHeroStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate(widget.connection.status)) {
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
    final status = widget.connection.status;
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _AnimatedStatusDot(
            controller: _controller,
            color: statusColor,
            animate: _shouldAnimate(status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatAddress(widget.connection.address),
                  style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 0.4),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusText(status),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAddress(String address) {
    var value = address.replaceFirst(RegExp(r'^https?://'), '');
    final colonIndex = value.indexOf(':');
    if (colonIndex != -1) {
      value = value.substring(0, colonIndex);
    }
    return value;
  }

  static String _statusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中…';
      case ConnectionStatus.offline:
        return '未连接';
    }
  }
}

class _AnimatedStatusDot extends StatelessWidget {
  const _AnimatedStatusDot({required this.controller, required this.color, required this.animate});

  final AnimationController controller;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = animate ? controller.value : 0.0;
        final delta = (progress - 0.5).abs();
        final scale = animate ? 1.0 + 0.18 * (0.5 - delta) : 1.0;
        final blur = animate ? 8.0 + 16.0 * (0.5 - delta) : 6.0;
        final opacity = animate ? 0.35 + 0.45 * (0.5 - delta) : 0.25;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
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
