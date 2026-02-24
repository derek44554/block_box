import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:block_app/blocks/file/pages/file_edit_page.dart';
import 'package:block_app/blocks/record/pages/record_edit_page.dart';
import 'package:block_app/blocks/service/pages/service_edit_page.dart';
import 'package:block_app/blocks/set/pages/set_edit_page.dart';
import 'package:block_app/blocks/user/pages/user_edit_page.dart';
import 'package:block_app/blocks/creed/pages/creed_edit_page.dart';
import 'package:block_app/blocks/article/pages/article_edit_page.dart';
import 'package:block_app/core/routing/app_router.dart';
import 'package:block_app/core/routing/route_names.dart';
import 'package:block_app/components/layout/create_block_sheet.dart';
import 'package:block_app/blocks/document/pages/document_edit_page.dart';
import 'package:block_app/core/models/block_model.dart';
import 'package:block_app/core/network/api/block_api.dart';
import 'package:block_app/state/connection_provider.dart';
import 'package:block_app/core/utils/helpers/platform_helper.dart';
import 'package:block_app/features/trace/services/auto_gps_service.dart';
import 'mac_home_page.dart';
import '../widgets/home_header.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _pastedBid = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 尝试自动创建GPS记录
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoCreateGps();
    });
  }

  Future<void> _tryAutoCreateGps() async {
    if (!mounted) return;
    final connectionProvider = context.read<ConnectionProvider>();
    await AutoGpsService.tryAutoCreateGpsRecord(context, connectionProvider);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handlePasteAndNavigate() async {
    if (_isLoading) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
      }
      return;
    }

    final isBid = RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(text);
    if (!isBid) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('剪贴板内容不是有效的 BID')));
      }
      return;
    }

    setState(() {
      _pastedBid = text;
      _isLoading = true;
    });

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: text);
      final data = response['data'];

      if (!mounted) return;

      if (data is Map<String, dynamic> && data.isNotEmpty) {
        final block = BlockModel(data: data);
        AppRouter.openBlockDetailPage(context, block);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('找不到对应的 Block')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取 Block 失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isMacOS) {
      return const MacHomePage();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(toolbarHeight: 0),
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final topGap = constraints.maxHeight * 0.18;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HomeHeader(),
                  SizedBox(height: topGap),
                  const Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Block',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildPasteButton(),
                  const SizedBox(height: 52),
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 10,
                    runSpacing: 16,
                    children: [
                      _FeatureButton(
                        icon: Icons.smart_toy_outlined,
                        label: 'AI',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.ai),
                      ),
                      _FeatureButton(
                        icon: Icons.star_border_rounded,
                        label: '收藏管理',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.collect),
                      ),
                      _FeatureButton(
                        icon: Icons.dashboard_outlined,
                        label: '聚集',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.aggregation),
                      ),
                      _FeatureButton(
                        icon: Icons.photo_album_outlined,
                        label: '相册',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.photo),
                      ),
                      _FeatureButton(
                        icon: Icons.music_note_outlined,
                        label: '音乐',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.music),
                      ),
                      _FeatureButton(
                        icon: Icons.history,
                        label: '痕迹',
                        onTap: () =>
                            Navigator.of(context).pushNamed(RouteNames.trace),
                      ),
                      _FeatureButton(
                        icon: Icons.add_circle_outline,
                        label: '创建',
                        onTap: () async {
                          final selected = await CreateBlockSheet.show(context);
                          if (!mounted || selected == null) return;

                          switch (selected) {
                            case CreateBlockOption.document:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DocumentEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.article:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ArticleEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.photo:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FileEditPage(isImageMode: true),
                                ),
                              );
                              break;
                            case CreateBlockOption.file:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FileEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.record:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RecordEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.collection:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SetEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.service:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ServiceEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.user:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UserEditPage(),
                                ),
                              );
                              break;
                            case CreateBlockOption.creed:
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CreedEditPage(
                                    block: BlockModel(data: {}),
                                  ),
                                ),
                              );
                              break;
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPasteButton() {
    return Align(
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: _handlePasteAndNavigate,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  height: 24,
                  child: _isLoading
                      ? Row(
                          children: const [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '正在获取...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _pastedBid.isEmpty ? '点此粘贴剪贴板内容' : _pastedBid,
                          style: TextStyle(
                            color: _pastedBid.isEmpty
                                ? Colors.white38
                                : Colors.white,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (_pastedBid.isNotEmpty && !_isLoading)
                GestureDetector(
                  onTap: () {
                    setState(() => _pastedBid = '');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.06),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 0.4,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
