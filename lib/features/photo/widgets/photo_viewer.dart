import 'package:flutter/material.dart';

import '../../../core/routing/app_router.dart';
import '../models/photo_models.dart';
import 'zoomable_image.dart';

class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<PhotoImage> photos;
  final int initialIndex;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late final AnimationController _animationController;
  Animation<Offset>? _animation;

  late int _current;
  Offset _dragOffset = Offset.zero;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 100),
        )..addListener(() {
          if (_animation != null) {
            setState(() {
              _dragOffset = _animation!.value;
            });
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    // Swipe down to dismiss
    if (_dragOffset.dy > 100 || velocity > 800) {
      setState(() => _isDismissing = true);
      Navigator.of(context).pop();
      return;
    }

    // Swipe up to open details page
    if (_dragOffset.dy < -100 || velocity < -800) {
      final currentPhoto = widget.photos[_current];
      final block = currentPhoto.block;
      if (block != null) {
        AppRouter.openBlockDetailPage(
          context,
          block,
          initialImageBytes: currentPhoto.previewBytes,
          initialImageVariant: currentPhoto.previewVariant,
        );
      }
      // Reset drag offset after navigation attempt
      _resetDrag();
      return;
    }

    // Animate back to center if not dismissed
    _resetDrag();
  }

  void _resetDrag() {
    _animation = Tween<Offset>(begin: _dragOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final opacity = (1 - (_dragOffset.dy.abs() / size.height)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(opacity),
      body: Opacity(
        opacity: _isDismissing ? 0.0 : 1.0,
        child: GestureDetector(
          onVerticalDragStart: (_) {
            _animationController.stop();
          },
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.delta;
            });
          },
          onVerticalDragEnd: _onVerticalDragEnd,
          child: Transform.translate(
            offset: _dragOffset,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  physics: _dragOffset == Offset.zero
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    if (!mounted) return;
                    setState(() {
                      _current = index;
                    });
                  },
                  itemCount: widget.photos.length,
                  itemBuilder: (context, index) {
                    final photo = widget.photos[index];
                    return Hero(
                      tag: photo.heroTag,
                      child: ZoomableImage(photo: photo),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.photos[_current].title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.photos[_current].time,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
