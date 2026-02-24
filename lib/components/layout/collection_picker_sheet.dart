import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/collect/models/collect_models.dart';
import '../../features/collect/providers/collect_provider.dart';


/// 收藏集合选择面板。
///
/// 以底部弹出的形式展示所有收藏集合及其条目，方便快速选择一个 BID。
/// 选择集合条目后会自动关闭并返回对应的 BID。
class CollectionPickerSheet extends StatelessWidget {
  const CollectionPickerSheet({super.key});

  static const double _cardRadius = 16;
  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CollectionPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).viewPadding.bottom;

    return ChangeNotifierProvider.value(
      value: context.read<CollectProvider>(),
      child: Padding(
        padding: EdgeInsets.only(bottom: safePadding),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.45,
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
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '收藏集合',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '选择一个条目后，即可快速填充到链接列表。',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Consumer<CollectProvider>(
                      builder: (context, provider, _) {
                        final entries = provider.entries;
                        if (entries.isEmpty) {
                          return const _EmptyView();
                        }
                        return ListView.builder(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return _CollectionCard(entry: entry);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.entry});

  final CollectEntry entry;

  @override
  Widget build(BuildContext context) {
    final items = entry.items;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181A),
        borderRadius: BorderRadius.circular(CollectionPickerSheet._cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.6),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          collapsedIconColor: Colors.white38,
          iconColor: Colors.white70,
          title: Text(entry.title, style: CollectionPickerSheet._titleStyle),
          subtitle: Text(
            '共 ${items.length} 条数据',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          children: [
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '暂无条目',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (final item in items)
                    _CollectionItemTile(
                      entryId: entry.id,
                      item: item,
                    ),
                ],
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _CollectionItemTile extends StatelessWidget {
  const _CollectionItemTile({required this.entryId, required this.item});

  final String entryId;
  final CollectItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(item.bid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                item.name.isNotEmpty ? item.name.characters.first.toUpperCase() : '#',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.bid,
                    style: const TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.collections_bookmark_outlined, color: Colors.white24, size: 42),
            SizedBox(height: 16),
            Text(
              '暂无收藏集合',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            SizedBox(height: 6),
            Text(
              '可以在收藏页面创建集合并添加条目。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
