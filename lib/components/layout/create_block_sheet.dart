import 'package:flutter/material.dart';

enum CreateBlockOption { document, article, photo, file, record, collection, service, user, creed }

typedef CreateBlockCallback = void Function(CreateBlockOption option);

/// 底部弹窗：选择要创建的块类型。
class CreateBlockSheet extends StatelessWidget {
  const CreateBlockSheet({super.key});

  static Future<CreateBlockOption?> show(
    BuildContext context, {
    CreateBlockCallback? onSelected,
  }) async {
    final result = await showModalBottomSheet<CreateBlockOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateBlockSheet(),
    );
    if (result != null) {
      onSelected?.call(result);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.6,
      minChildSize: 0.3,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111112),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                '创建新块',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: const [
                    _OptionTile(
                      option: CreateBlockOption.document,
                      icon: Icons.description_outlined,
                      title: '文档',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.article,
                      icon: Icons.article_outlined,
                      title: '文章',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.photo,
                      icon: Icons.image_outlined,
                      title: '照片',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.file,
                      icon: Icons.attach_file_outlined,
                      title: '文件',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.record,
                      icon: Icons.folder_open_outlined,
                      title: '档案',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.collection,
                      icon: Icons.collections_bookmark_outlined,
                      title: '集合',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.service,
                      icon: Icons.public_outlined,
                      title: '服务',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.user,
                      icon: Icons.person_outline,
                      title: '用户',
                    ),
                    _OptionTile(
                      option: CreateBlockOption.creed,
                      icon: Icons.format_quote,
                      title: '信条',
                    ),
                  ],
                ),
              ),
              SizedBox(height: bottomPadding > 0 ? bottomPadding : 12),
            ],
          ),
        );
      },
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.icon,
    required this.title,
  });

  final CreateBlockOption option;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).pop(option),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF18181A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.6,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white70, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
