import 'package:flutter/material.dart';

/// 通用的分页骨架，提供顶部分段控制和页面切换。
class SegmentedPageScaffold extends StatefulWidget {
  const SegmentedPageScaffold({
    super.key,
    required this.title,
    required this.segments,
    required this.pages,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.backgroundColor = Colors.black,
    this.headerPadding = const EdgeInsets.fromLTRB(24, 10, 24, 10),
    this.controlWidth,
    this.controlHeight = 34,
    this.bottomSafeArea = false,
    this.onTitleTap,
    this.floatingActionButton,
    this.actions,
  }) : assert(segments.length == pages.length, 'segments 数量需与 pages 对齐');

  final String title;
  final List<String> segments;
  final List<Widget> pages;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;
  final Color backgroundColor;
  final EdgeInsets headerPadding;
  final double? controlWidth;
  final double controlHeight;
  final bool bottomSafeArea;
  final VoidCallback? onTitleTap;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  State<SegmentedPageScaffold> createState() => _SegmentedPageScaffoldState();
}

class _SegmentedPageScaffoldState extends State<SegmentedPageScaffold> {
  late final PageController _controller;
  late int _currentIndex;

  static const TextStyle _defaultTitleStyle = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.segments.length - 1;
    _currentIndex = widget.initialIndex.clamp(0, maxIndex);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSegmentTap(int index) {
    // 允许重复点击当前选中的标签页
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
    _updateIndex(index);
  }

  void _updateIndex(int index) {
    // 允许重复调用相同索引，以便触发回调
    setState(() {
      _currentIndex = index;
    });
    widget.onIndexChanged?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(toolbarHeight: 0),
      body: SafeArea(
        top: true,
        bottom: widget.bottomSafeArea,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: widget.headerPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTitle(),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.actions != null) ...[
                          ...widget.actions!,
                          const SizedBox(width: 16),
                        ],
                        PageSegmentedControl(
                          controller: _controller,
                          options: widget.segments,
                          currentIndex: _currentIndex,
                          width: widget.controlWidth,
                          height: widget.controlHeight,
                          onSegmentTap: _handleSegmentTap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: _updateIndex,
                children: widget.pages.map((page) => _KeepAlivePage(child: page)).toList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildTitle() {
    if (widget.title.isEmpty) {
      return const SizedBox(width: 40);
    }

    final text = Text(
      widget.title,
      style: _defaultTitleStyle,
    );

    final onTap = widget.onTitleTap;
    if (onTap == null) {
      return text;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: widget.title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: text,
        ),
      ),
    );
  }
}

/// 分段控制器，用于多个页面顶部的 PageView 选项切换。
class PageSegmentedControl extends StatelessWidget {
  const PageSegmentedControl({
    super.key,
    required this.controller,
    required this.options,
    required this.currentIndex,
    this.width,
    this.height = 34,
    this.onSegmentTap,
    this.animationDuration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOut,
  }) : assert(options.length >= 2, '至少需要两个选项');

  final PageController controller;
  final List<String> options;
  final int currentIndex;
  final double? width;
  final double height;
  final ValueChanged<int>? onSegmentTap;
  final Duration animationDuration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? (options.length * 60).toDouble();

    return SizedBox(
      width: effectiveWidth,
      height: height,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final maxIndex = (options.length - 1).toDouble();
          final page = controller.hasClients
              ? (controller.page ?? currentIndex.toDouble()).clamp(0, maxIndex)
              : currentIndex.toDouble();

          return LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / options.length;
              final indicatorLeft = segmentWidth * page;

              return Stack(
                children: [
                  Positioned(
                    left: indicatorLeft,
                    top: 2,
                    bottom: 2,
                    width: segmentWidth,
                    child: AnimatedContainer(
                      duration: animationDuration,
                      curve: curve,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1F),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(options.length, (index) {
                      final isActive = controller.hasClients
                          ? ((controller.page ?? currentIndex.toDouble()).round() == index)
                          : currentIndex == index;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            controller.animateToPage(
                              index,
                              duration: animationDuration,
                              curve: curve,
                            );
                            onSegmentTap?.call(index);
                          },
                          child: Center(
                            child: Text(
                              options[index],
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.white54,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// 包装 Widget，使 PageView 中的页面保持状态不被销毁
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
