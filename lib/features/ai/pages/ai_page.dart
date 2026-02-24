import 'package:flutter/material.dart';

import '../../../core/widgets/layouts/segmented_page_scaffold.dart';


class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SegmentedPageScaffold(
      title: 'AI',
      segments: const ['聊天', '应用'],
      pages: [
        _buildChatPage(),
        _buildAppPage(),
      ],
      initialIndex: 0,
      controlWidth: 140,
      headerPadding: const EdgeInsets.fromLTRB(24, 10, 24, 6),
    );
  }

  Widget _buildChatPage() {
    final messages = [
      const _Message(role: MessageRole.system, text: '您好，我是您的 Block AI 助手。'),
      const _Message(role: MessageRole.user, text: '帮我总结一下最近的 UI 调整重点。'),
      const _Message(
        role: MessageRole.assistant,
        text:
            '最近的重点包括：\n1. 收藏页集合卡片去除背景边框。\n2. 相册页新增四列布局，以及全屏预览动画。\n3. 新增 AI 页面入口，待接入更多功能。\n如需细节我可以继续展开。',
      ),
      const _Message(role: MessageRole.user, text: '这些改动是否已同步到功能页面？'),
      const _Message(role: MessageRole.assistant, text: '入口已在功能页面展示，如果需要我可以帮你检查具体路由。'),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            physics: const BouncingScrollPhysics(),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              final isUser = message.role == MessageRole.user;
              final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
              final bubbleColor = isUser
                  ? Colors.white.withOpacity(0.1)
                  : const Color(0xFF18181A);
              final textColor = Colors.white.withOpacity(isUser ? 0.95 : 0.82);

              return Align(
                alignment: alignment,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  margin: EdgeInsets.only(top: index == 0 ? 0 : 14),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 16),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(isUser ? 0.08 : 0.03),
                      width: 0.6,
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildAppPage() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            physics: const BouncingScrollPhysics(),
            children: const [
              _AppCard(
                title: 'Block Insight',
                description: '自动梳理 Block 数据结构，生成可视化报告。',
                icon: Icons.auto_awesome,
              ),
              SizedBox(height: 16),
              _AppCard(
                title: '快速任务',
                description: '根据聊天上下文生成待办任务列表。',
                icon: Icons.task_alt,
              ),
              SizedBox(height: 16),
              _AppCard(
                title: '交互脚本',
                description: '帮助你生成常用交互场景脚本与提示词。',
                icon: Icons.psychology_alt_outlined,
              ),
            ],
          ),
        ),
        _buildAppFooter(),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06), width: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.6),
              ),
              child: const Icon(Icons.photo_outlined, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _inputController.text.isEmpty ? '告诉我你想做什么…' : _inputController.text,
                        style: TextStyle(
                          color: _inputController.text.isEmpty ? Colors.white38 : Colors.white,
                          fontSize: 13,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppFooter() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05), width: 0.6)),
        ),
        child: Row(
          children: const [
            Icon(Icons.tips_and_updates, color: Colors.white54, size: 16),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '精选应用暂未开放交互，后续可在此快速启动。',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum MessageRole { user, assistant, system }

class _Message {
  const _Message({required this.role, required this.text});

  final MessageRole role;
  final String text;
}
