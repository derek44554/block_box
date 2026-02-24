import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:block_app/core/network/models/connection_model.dart';
import '../../../../../state/connection_provider.dart';
import 'package:block_app/core/widgets/dialogs/app_dialog.dart';
import 'package:block_app/core/widgets/dialogs/confirmation_dialog.dart';

import 'ipfs_endpoint_section.dart';

class ConnectionListView extends StatelessWidget {
  const ConnectionListView({super.key});

  void _showConnectionDialog(BuildContext context, {ConnectionModel? initial}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ConnectionFormDialog(initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Consumer<ConnectionProvider>(
          builder: (context, provider, _) {
            final connections = provider.connections;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IpfsEndpointSection(
                  initialValue: provider.ipfsEndpoint,
                  onSubmitted: (value) => provider.updateIpfsEndpoint(value),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: connections.isEmpty
                      ? const _EmptyPlaceholder()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: connections.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final item = connections[index];
                            return _ConnectionCard(
                              item: item,
                              onSelect: () =>
                                  provider.selectConnection(item.address),
                              onEdit: () =>
                                  _showConnectionDialog(context, initial: item),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _showConnectionDialog(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: Colors.white.withOpacity(0.16)),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    '添加连接',
                    style: TextStyle(letterSpacing: 0.6),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.item,
    required this.onSelect,
    required this.onEdit,
  });

  final ConnectionModel item;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  Color get _accentColor {
    switch (item.status) {
      case ConnectionStatus.connected:
        return const Color(0xFF4CAF50);
      case ConnectionStatus.connecting:
        return const Color(0xFF26C6DA);
      case ConnectionStatus.offline:
        return Colors.grey;
    }
  }

  Color get _backgroundColor {
    if (item.isActive) {
      return Colors.white.withOpacity(0.08);
    }
    return Colors.white.withOpacity(0.04);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(item.isActive ? 0.18 : 0.08),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      if (item.enableIpfsStorage)
                        _IpfsBadge(isActive: item.isActive),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.address,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.settings, color: Colors.white70, size: 18),
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _IpfsBadge extends StatelessWidget {
  const _IpfsBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = isActive
        ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
        : [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.12)];
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.hub_outlined, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'IPFS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_off, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            '暂无连接，请点击右下方添加',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionFormDialog extends StatefulWidget {
  const _ConnectionFormDialog({this.initial});

  final ConnectionModel? initial;

  bool get isEditing => initial != null;

  @override
  State<_ConnectionFormDialog> createState() => _ConnectionFormDialogState();
}

class _ConnectionFormDialogState extends State<_ConnectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _keyController;
  late final TextEditingController _ipfsPasswordController;
  bool _enableIpfsStorage = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _addressController = TextEditingController(
      text: widget.initial?.address ?? '',
    );
    _keyController = TextEditingController(
      text: widget.initial?.keyBase64 ?? '',
    );
    _ipfsPasswordController = TextEditingController(
      text: widget.initial?.ipfsUploadPassword ?? '',
    );
    _enableIpfsStorage = widget.initial?.enableIpfsStorage ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _keyController.dispose();
    _ipfsPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final provider = context.read<ConnectionProvider>();
    final navigator = Navigator.of(context);
    final connection = widget.initial!;

    navigator.pop();

    final confirm = await showConfirmationDialog(
      context: context,
      title: '确认删除连接？',
      content: Text(
        '连接 "${connection.name}" 删除后不可恢复。',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      confirmText: '删除',
      isDestructive: true,
    );

    if (confirm == true) {
      await provider.removeConnection(connection.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ConnectionProvider>();
    return AppDialog(
      title: widget.isEditing ? '编辑连接' : '新增连接',
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppDialogTextField(
              controller: _nameController,
              label: '连接名称',
              hintText: '例如：生产环境',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入连接名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppDialogTextField(
              controller: _addressController,
              label: '服务地址',
              hintText: 'https://example.com',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入服务地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppDialogTextField(
              controller: _keyController,
              label: '密钥',
              hintText: 'base64 字符串',
              initialObscureText: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入密钥';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _IpfsStorageToggle(
              value: _enableIpfsStorage,
              onChanged: (value) => setState(() => _enableIpfsStorage = value),
            ),
            if (_enableIpfsStorage) ...[
              const SizedBox(height: 14),
              AppDialogTextField(
                controller: _ipfsPasswordController,
                label: 'IPFS 上传密码',
                hintText: '用于 IPFS 文件上传的密码',
                initialObscureText: true,
              ),
            ],
            if (widget.isEditing) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _handleDelete,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: const Color(0xFFE55C5C),
                  side: BorderSide(
                    color: const Color(0xFFE55C5C).withOpacity(0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除此连接'),
              ),
            ],
          ],
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.12)),
                foregroundColor: Colors.white70,
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) {
                        return;
                      }
                      setState(() => _isSubmitting = true);
                      if (widget.isEditing) {
                        await provider.updateConnection(
                          widget.initial!,
                          widget.initial!.copyWith(
                            name: _nameController.text.trim(),
                            address: _addressController.text.trim(),
                            keyBase64: _keyController.text.trim(),
                            enableIpfsStorage: _enableIpfsStorage,
                            ipfsUploadPassword: _ipfsPasswordController.text.trim().isEmpty 
                                ? null 
                                : _ipfsPasswordController.text.trim(),
                          ),
                        );
                      } else {
                        await provider.addConnection(
                          ConnectionModel(
                            name: _nameController.text.trim(),
                            address: _addressController.text.trim(),
                            keyBase64: _keyController.text.trim(),
                            status: ConnectionStatus.offline,
                            enableIpfsStorage: _enableIpfsStorage,
                            ipfsUploadPassword: _ipfsPasswordController.text.trim().isEmpty 
                                ? null 
                                : _ipfsPasswordController.text.trim(),
                          ),
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _IpfsStorageToggle extends StatelessWidget {
  const _IpfsStorageToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '启用 IPFS 存储',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '启用后，将在此连接下优先使用 IPFS 进行文件存储。',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.white24,
          ),
        ],
      ),
    );
  }
}
