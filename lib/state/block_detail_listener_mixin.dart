import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/block_model.dart';
import 'block_provider.dart';

/// Mixin for detail pages to listen to BlockProvider updates
/// 
/// This mixin provides automatic BlockProvider listening for detail pages.
/// When a Block is updated anywhere in the app, all detail pages showing
/// that Block will automatically update their UI.
/// 
/// Usage:
/// ```dart
/// class _MyDetailPageState extends State<MyDetailPage> with BlockDetailListenerMixin {
///   @override
///   String? get blockBid => widget.block.bid;
///   
///   @override
///   void onBlockUpdated(BlockModel updatedBlock) {
///     setState(() {
///       _blockData = Map<String, dynamic>.from(updatedBlock.data);
///     });
///   }
/// }
/// ```
mixin BlockDetailListenerMixin<T extends StatefulWidget> on State<T> {
  VoidCallback? _blockProviderListener;

  /// Override this to return the BID of the Block being displayed
  String? get blockBid;

  /// Override this to handle Block updates
  /// This will be called when BlockProvider notifies of an update
  void onBlockUpdated(BlockModel updatedBlock);

  /// Optional: Override to control when updates should be applied
  /// Return false to skip the update (e.g., when user is editing)
  bool shouldUpdateBlock() => true;

  /// Call this in initState to start listening
  void startBlockProviderListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _blockProviderListener = _onBlockProviderUpdate;
        context.read<BlockProvider>().addListener(_blockProviderListener!);
      }
    });
  }

  /// Call this in dispose to stop listening
  void stopBlockProviderListener() {
    if (_blockProviderListener != null) {
      try {
        context.read<BlockProvider>().removeListener(_blockProviderListener!);
      } catch (e) {
        // Listener removal failed
      }
      _blockProviderListener = null;
    }
  }

  void _onBlockProviderUpdate() {
    if (!mounted) return;

    final bid = blockBid;
    if (bid == null || bid.isEmpty) return;

    if (!shouldUpdateBlock()) {
      return;
    }

    try {
      final blockProvider = context.read<BlockProvider>();
      final updatedBlock = blockProvider.getBlock(bid);

      if (updatedBlock != null) {
        onBlockUpdated(updatedBlock);
      }
    } catch (e) {
      // Error in update handler
    }
  }
}
