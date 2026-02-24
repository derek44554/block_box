import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../blocks/file/pages/file_edit_page.dart';
import '../../../blocks/record/pages/record_edit_page.dart';
import '../../../blocks/service/pages/service_edit_page.dart';
import '../../../blocks/set/pages/set_edit_page.dart';
import '../../../blocks/user/pages/user_edit_page.dart';
import '../../../blocks/creed/pages/creed_edit_page.dart';
import '../../../blocks/article/pages/article_edit_page.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/routing/app_router.dart';
import '../../../components/layout/create_block_sheet.dart';
import '../../../blocks/document/pages/document_edit_page.dart';
import '../../../core/models/block_model.dart';
import '../../../core/network/api/block_api.dart';
import '../../../state/connection_provider.dart';
import '../../aggregation/pages/aggregation_page.dart';
import '../../ai/pages/ai_page.dart';
import '../../collect/pages/collect_page.dart';
import '../../music/pages/music_page.dart';
import '../../photo/pages/photo_page.dart';
import '../../trace/pages/trace_page.dart';
import '../widgets/home_header.dart';
import '../widgets/mac_menu_button.dart';

enum MacHomeSection { overview, aggregation, ai, photo, music, collect, trace }

class MacHomePage extends StatefulWidget {
  const MacHomePage({super.key});

  @override
  State<MacHomePage> createState() => _MacHomePageState();
}

class _MacHomePageState extends State<MacHomePage> {
  static const List<_MacMenuItem> _menuItems = [
    _MacMenuItem(
      section: MacHomeSection.overview,
      label: '总览',
      description: '概览当前连接状态以及快捷操作，快速进入 Block 世界。',
      highlights: ['粘贴 BID', '创建 Block', '关注连接'],
      icon: Icons.blur_linear,
      accentColor: Color(0xFF86A1FF),
    ),
    _MacMenuItem(
      section: MacHomeSection.ai,
      label: 'AI 助手',
      description: '使用 Block AI 快速总结、生成指令与脚本，提升处理效率。',
      highlights: ['多段上下文', '嵌入式总结', '脚本草稿'],
      icon: Icons.smart_toy_outlined,
      accentColor: Color(0xFFB388FF),
      routeName: RouteNames.ai,
    ),
    _MacMenuItem(
      section: MacHomeSection.collect,
      label: '收藏',
      description: '管理常用 Block 集合，把重要链接和条目集中整理。',
      highlights: ['多组收藏', '双栏布局', '按需加载'],
      icon: Icons.star_border_rounded,
      accentColor: Color(0xFF4DD0E1),
      routeName: RouteNames.collect,
    ),
    _MacMenuItem(
      section: MacHomeSection.aggregation,
      label: '聚集',
      description: '按 Model 类型聚合块，快速筛选和查看特定类型的内容。',
      highlights: ['类型分组', '数量统计', '快捷筛选'],
      icon: Icons.dashboard_outlined,
      accentColor: Color(0xFF81C784),
      routeName: RouteNames.aggregation,
    ),
    _MacMenuItem(
      section: MacHomeSection.photo,
      label: '相册',
      description: '浏览照片资源，支持拖拽、预览与集合管理。',
      highlights: ['四列瀑布流', '快捷筛选', '全屏预览'],
      icon: Icons.photo_album_outlined,
      accentColor: Color(0xFFFFB74D),
      routeName: RouteNames.photo,
    ),
    _MacMenuItem(
      section: MacHomeSection.music,
      label: '音乐',
      description: '播放和管理音乐集合，支持播放列表与集合管理。',
      highlights: ['音乐播放', '播放列表', '集合管理'],
      icon: Icons.music_note_outlined,
      accentColor: Color(0xFFFF6B9D),
      routeName: RouteNames.music,
    ),
    _MacMenuItem(
      section: MacHomeSection.trace,
      label: '痕迹',
      description: '记录和追踪操作痕迹，便于管理和回溯。',
      highlights: ['操作记录', '痕迹追踪', '数据管理'],
      icon: Icons.timeline,
      accentColor: Color(0xFF9C27B0),
      routeName: RouteNames.trace,
    ),
  ];

  MacHomeSection _activeSection = MacHomeSection.overview;
  MacHomeSection? _previousSection;
  final Map<MacHomeSection, Widget> _embeddedPageCache = {};
  final GlobalKey<NavigatorState> _contentNavigatorKey =
      GlobalKey<NavigatorState>();
  bool _isMenuSwitching = false;
  
  // BID input field state management
  final TextEditingController _bidInputController = TextEditingController();
  final FocusNode _bidInputFocusNode = FocusNode();
  bool _isBidInputValid = false;
  bool _isFetchingFromInput = false;

  @override
  void initState() {
    super.initState();
    _previousSection = _activeSection;
  }

  @override
  void dispose() {
    _bidInputController.dispose();
    _bidInputFocusNode.dispose();
    super.dispose();
  }

  void _onSectionChanged(MacHomeSection newSection) {
    // 允许重复点击相同的导航选项来重新进入页面
    _previousSection = _activeSection;
    setState(() {
      _isMenuSwitching = true;
      _activeSection = newSection;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _contentNavigatorKey.currentState;
      if (navigator != null) {
        // 如果是重复点击相同选项，先清空导航栈再重新加载
        if (newSection == _previousSection) {
          // 重复点击：清空导航栈并重新加载页面
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          // 不同选项：正常替换页面
          navigator.pushReplacementNamed('/');
        }
      }
      if (mounted) {
        setState(() {
          _isMenuSwitching = false;
        });
      }
    });
  }

  void _handleBackButton() {
    final navigator = _contentNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      // 如果无法返回，则回到总览页面
      _onSectionChanged(MacHomeSection.overview);
    }
  }

  // BID input validation methods
  bool _validateBidInput(String input) {
    // 检查长度和十六进制格式
    return input.length == 32 && RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(input);
  }

  void _onBidInputChanged(String value) {
    setState(() {
      _isBidInputValid = _validateBidInput(value);
    });
  }

  Future<void> _handleBidInputSubmit() async {
    final input = _bidInputController.text.trim();
    if (!_validateBidInput(input)) return;
    
    await _fetchAndNavigateToBlock(input);
  }

  Future<void> _fetchAndNavigateToBlock(String bid) async {
    if (_isFetchingFromInput) return;

    setState(() {
      _isFetchingFromInput = true;
    });

    try {
      final provider = context.read<ConnectionProvider>();
      final api = BlockApi(connectionProvider: provider);
      final response = await api.getBlock(bid: bid);
      final data = response['data'];

      if (!mounted) return;

      if (data is Map<String, dynamic> && data.isNotEmpty) {
        final block = BlockModel(data: data);
        
        // 直接使用内容区域的Navigator
        final contentNavigator = _contentNavigatorKey.currentState;
        if (contentNavigator != null) {
          AppRouter.openBlockDetailPage(context, block, navigator: contentNavigator);
        } else {
          AppRouter.openBlockDetailPage(context, block);
        }
        
        // Clear the input field after successful navigation
        _bidInputController.clear();
        setState(() {
          _isBidInputValid = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到对应的 Block')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取 Block 失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingFromInput = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: true,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 1280;
            final padding = EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 16,
              vertical: isCompact ? 12 : 20,
            );
            final menuWidth = isCompact ? 180.0 : 220.0;

            return Padding(
              padding: padding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: menuWidth,
                    child: _buildSidebarMenu(isCompact),
                  ),
                  SizedBox(width: isCompact ? 12 : 20),
                  Expanded(child: _buildContentArea(textTheme, isCompact)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSidebarMenu(bool isCompact) {
    final items = _menuItems;
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        isCompact ? 12 : 16,
        12,
        isCompact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.02),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 返回按钮区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: _handleBackButton,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : 6,
                  ),
                  child: MacMenuButton(
                    icon: item.icon,
                    label: item.label,
                    isActive: item.section == _activeSection,
                    onTap: () => _onSectionChanged(item.section),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _handleCreateBlock,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                side: BorderSide(color: Colors.white.withOpacity(0.18)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新建'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(TextTheme textTheme, bool isCompact) {
    return MacContentNavigatorProvider(
      navigatorKey: _contentNavigatorKey,
      child: Navigator(
        key: _contentNavigatorKey,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            Widget page;
            if (_activeSection == MacHomeSection.overview) {
              page = _buildOverviewColumn(textTheme, isCompact);
            } else {
              page = _buildEmbeddedPageFrame(isCompact);
            }
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) => page,
              settings: const RouteSettings(name: '/'),
              transitionDuration: _isMenuSwitching ? Duration.zero : const Duration(milliseconds: 260),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            );
          }
          // 其他路由由直接 push 的 MaterialPageRoute 处理
          return null;
        },
      ),
    );
  }

  Widget _buildOverviewColumn(TextTheme textTheme, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeHeader(),
        SizedBox(height: isCompact ? 80 : 120),
        _buildBidInputField(),
      ],
    );
  }

  Widget _buildEmbeddedPageFrame(bool isCompact) {
    final borderRadius = BorderRadius.circular(isCompact ? 28 : 36);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey('section-${_activeSection.name}'),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          color: Colors.black.withOpacity(0.55),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Theme(
            data: Theme.of(context).copyWith(
              scaffoldBackgroundColor: Colors.transparent,
              canvasColor: Colors.transparent,
            ),
            child: Builder(
              builder: (context) {
                // 使用 Builder 确保 context 指向嵌套 Navigator
                return _buildSectionPage(_activeSection);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionPage(MacHomeSection section) {
    // 如果是重复点击相同选项，清除缓存以重新创建页面
    if (section == _previousSection && _embeddedPageCache.containsKey(section)) {
      _embeddedPageCache.remove(section);
    }
    
    return _embeddedPageCache.putIfAbsent(section, () {
      switch (section) {
        case MacHomeSection.aggregation:
          return const AggregationPage();
        case MacHomeSection.ai:
          return const AIPage();
        case MacHomeSection.photo:
          return const PhotoPage();
        case MacHomeSection.music:
          return const MusicPage();
        case MacHomeSection.collect:
          return const CollectPage();
        case MacHomeSection.trace:
          return const TracePage();
        case MacHomeSection.overview:
          return const SizedBox.shrink();
      }
    });
  }

  Widget _buildBidInputField() {
    // Determine border color based on validation state
    Color borderColor;
    if (_bidInputController.text.isEmpty) {
      borderColor = Colors.white.withOpacity(0.24);
    } else if (_isBidInputValid) {
      borderColor = Colors.green.withOpacity(0.6);
    } else {
      borderColor = Colors.red.withOpacity(0.6);
    }

    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 320,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: TextField(
          controller: _bidInputController,
          focusNode: _bidInputFocusNode,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          decoration: InputDecoration(
            hintText: '输入 32 位 BID',
            hintStyle: TextStyle(
              color: Colors.white38,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-fA-F0-9]')),
            LengthLimitingTextInputFormatter(32),
          ],
          onChanged: _onBidInputChanged,
          onSubmitted: (_) => _handleBidInputSubmit(),
        ),
      ),
    );
  }

  Future<void> _handleCreateBlock() async {
    final selected = await CreateBlockSheet.show(context);
    if (!mounted || selected == null) return;

    Widget page;
    switch (selected) {
      case CreateBlockOption.document:
        page = const DocumentEditPage();
        break;
      case CreateBlockOption.article:
        page = const ArticleEditPage();
        break;
      case CreateBlockOption.photo:
        page = FileEditPage(isImageMode: true);
        break;
      case CreateBlockOption.file:
        page = const FileEditPage();
        break;
      case CreateBlockOption.record:
        page = const RecordEditPage();
        break;
      case CreateBlockOption.collection:
        page = const SetEditPage();
        break;
      case CreateBlockOption.service:
        page = const ServiceEditPage();
        break;
      case CreateBlockOption.user:
        page = const UserEditPage();
        break;
      case CreateBlockOption.creed:
        page = CreedEditPage(block: BlockModel(data: {}));
        break;
    }

    _contentNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => page));
  }
}

class _MacMenuItem {
  const _MacMenuItem({
    required this.section,
    required this.label,
    required this.description,
    required this.highlights,
    required this.icon,
    required this.accentColor,
    this.routeName,
  });

  final MacHomeSection section;
  final String label;
  final String description;
  final List<String> highlights;
  final IconData icon;
  final Color accentColor;
  final String? routeName;
}

class MacContentNavigatorProvider extends InheritedWidget {
  const MacContentNavigatorProvider({
    super.key,
    required this.navigatorKey,
    required super.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  static NavigatorState? of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<MacContentNavigatorProvider>();
    return provider?.navigatorKey.currentState;
  }

  @override
  bool updateShouldNotify(MacContentNavigatorProvider oldWidget) {
    return navigatorKey != oldWidget.navigatorKey;
  }
}
