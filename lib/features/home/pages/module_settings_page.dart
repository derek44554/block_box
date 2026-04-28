import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api/api_client.dart';
import '../../../state/connection_provider.dart';

class ModuleSettingsPage extends StatefulWidget {
  const ModuleSettingsPage({super.key});

  @override
  State<ModuleSettingsPage> createState() => _ModuleSettingsPageState();
}

class _ModuleSettingsPageState extends State<ModuleSettingsPage> {
  bool _isLoading = false;
  String? _errorMessage;
  List<_LocalModule> _modules = const [];
  final Set<String> _updatingModuleNames = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchModuleInfo();
      }
    });
  }

  Future<void> _fetchModuleInfo() async {
    debugPrint('=== 开始获取模块设置 ===');

    final provider = context.read<ConnectionProvider>();
    final connection = provider.activeConnection;

    if (connection == null) {
      debugPrint('模块设置请求失败: 暂无连接');
      if (mounted) {
        setState(() {
          _errorMessage = '暂无连接';
          _isLoading = false;
          _modules = const [];
        });
      }
      debugPrint('=== 获取模块设置结束 ===');
      return;
    }

    debugPrint('当前连接: ${connection.address}');
    debugPrint('请求路由: /apps/apps/all');

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final api = ApiClient(connectionProvider: provider);
      final response = await api.postToBridge(
        routing: '/apps/apps/all',
        data: const <String, dynamic>{},
      );

      _printModuleInfo(response);

      final modules = _parseModules(response);
      if (!mounted) return;
      setState(() {
        _modules = modules;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('获取模块设置失败: $error');
      debugPrint('堆栈跟踪: $stackTrace');

      if (!mounted) return;
      setState(() {
        _errorMessage = '获取模块设置失败: $error';
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取模块设置失败: $error')));
    } finally {
      debugPrint('=== 获取模块设置结束 ===');
    }
  }

  List<_LocalModule> _parseModules(Map<String, dynamic> response) {
    final rawItems = _extractModuleItems(response);

    return rawItems
        .whereType<Map>()
        .map((item) => _LocalModule.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<dynamic> _extractModuleItems(Object? source) {
    if (source is List) {
      return source;
    }

    if (source is Map) {
      for (final key in const [
        'data',
        'items',
        'apps',
        'modules',
        'list',
        'v',
      ]) {
        if (!source.containsKey(key)) continue;
        final items = _extractModuleItems(source[key]);
        if (items.isNotEmpty) {
          return items;
        }
      }

      final values = source.values.toList();
      if (values.isNotEmpty && values.every((value) => value is Map)) {
        return source.entries.map((entry) {
          final item = Map<String, dynamic>.from(entry.value as Map);
          item.putIfAbsent('name', () => entry.key.toString());
          return item;
        }).toList();
      }
    }

    return const <dynamic>[];
  }

  Future<void> _setModuleEnabled(_LocalModule module, bool enabled) async {
    final name = module.name.trim();
    if (name.isEmpty || name == '未命名模块') {
      _showMessage('模块名称无效，无法操作');
      return;
    }

    if (module.isProtectedCoreModule) {
      _showMessage('apps 模块为核心模块，禁止操作');
      return;
    }

    if (_updatingModuleNames.contains(name)) {
      return;
    }

    final provider = context.read<ConnectionProvider>();
    final route = enabled ? '/apps/apps/enable' : '/apps/apps/disable';

    setState(() {
      _updatingModuleNames.add(name);
    });

    try {
      debugPrint('=== 开始${enabled ? '开启' : '关闭'}模块 ===');
      debugPrint('请求路由: $route');
      debugPrint('模块名称: $name');

      final api = ApiClient(connectionProvider: provider);
      final response = await api.postToBridge(
        routing: route,
        data: {'name': name},
      );

      _printRouteResponse(route, response);

      if (!mounted) return;
      setState(() {
        _modules = _modules
            .map(
              (item) =>
                  item.name == name ? item.copyWith(enabled: enabled) : item,
            )
            .toList();
      });
      _showMessage(enabled ? '模块已开启' : '模块已关闭');

      await _fetchModuleInfo();
    } catch (error, stackTrace) {
      debugPrint('${enabled ? '开启' : '关闭'}模块失败: $error');
      debugPrint('堆栈跟踪: $stackTrace');
      if (!mounted) return;
      _showMessage('${enabled ? '开启' : '关闭'}模块失败: $error');
    } finally {
      debugPrint('=== ${enabled ? '开启' : '关闭'}模块结束 ===');
      if (mounted) {
        setState(() {
          _updatingModuleNames.remove(name);
        });
      }
    }
  }

  void _printModuleInfo(Map<String, dynamic> response) {
    _printRouteResponse('/apps/apps/all', response);
  }

  void _printRouteResponse(String route, Map<String, dynamic> response) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(response);
    debugPrint('模块设置响应 $route:');

    const chunkSize = 900;
    for (var start = 0; start < prettyJson.length; start += chunkSize) {
      var end = start + chunkSize;
      if (end > prettyJson.length) {
        end = prettyJson.length;
      }
      debugPrint(prettyJson.substring(start, end));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('模块设置')),
      body: RefreshIndicator(onRefresh: _fetchModuleInfo, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _modules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _modules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        children: [
          _ModulePlaceholder(
            icon: Icons.error_outline,
            title: '获取失败',
            message: _errorMessage!,
          ),
        ],
      );
    }

    if (_modules.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        children: const [
          _ModulePlaceholder(
            icon: Icons.extension_off_outlined,
            title: '暂无模块',
            message: '当前节点没有返回模块配置',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      itemBuilder: (context, index) {
        final module = _modules[index];
        return _ModuleCard(
          module: module,
          isUpdating: _updatingModuleNames.contains(module.name),
          onEnabledChanged: module.isProtectedCoreModule
              ? null
              : (enabled) => _setModuleEnabled(module, enabled),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemCount: _modules.length,
    );
  }
}

class _LocalModule {
  const _LocalModule({
    required this.name,
    required this.version,
    required this.enabled,
    required this.github,
  });

  final String name;
  final String? version;
  final bool enabled;
  final String? github;

  bool get isProtectedCoreModule => name.trim().toLowerCase() == 'apps';

  factory _LocalModule.fromJson(Map<String, dynamic> json) {
    return _LocalModule(
      name:
          _readText(json, const ['name', 'app_name', 'module', 'id']) ??
          '未命名模块',
      version: (json['version'] as String?)?.trim(),
      enabled: _readEnabled(json),
      github: (json['github'] as String?)?.trim(),
    );
  }

  _LocalModule copyWith({bool? enabled}) {
    return _LocalModule(
      name: name,
      version: version,
      enabled: enabled ?? this.enabled,
      github: github,
    );
  }

  static String? _readText(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static bool _readEnabled(Map<String, dynamic> json) {
    final enabledValue = _firstValue(json, const [
      'enabled',
      'enable',
      'is_enabled',
      'active',
      'is_active',
    ]);
    final parsedEnabled = _parseBool(enabledValue);
    if (parsedEnabled != null) {
      return parsedEnabled;
    }

    final disabledValue = _firstValue(json, const [
      'disabled',
      'disable',
      'is_disabled',
      'is_disable',
      'closed',
    ]);
    final parsedDisabled = _parseBool(disabledValue);
    if (parsedDisabled != null) {
      return !parsedDisabled;
    }

    final status = _readText(json, const ['status', 'state'])?.toLowerCase();
    if (status != null) {
      if (const [
        'disabled',
        'disable',
        'off',
        'closed',
        'inactive',
        'stopped',
      ].contains(status)) {
        return false;
      }
      if (const [
        'enabled',
        'enable',
        'on',
        'open',
        'active',
        'running',
      ].contains(status)) {
        return true;
      }
    }

    return true;
  }

  static Object? _firstValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key)) {
        return json[key];
      }
    }
    return null;
  }

  static bool? _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (const [
        'true',
        '1',
        'yes',
        'y',
        'enabled',
        'enable',
        'on',
        'open',
        'active',
        'running',
      ].contains(normalized)) {
        return true;
      }
      if (const [
        'false',
        '0',
        'no',
        'n',
        'disabled',
        'disable',
        'off',
        'closed',
        'inactive',
        'stopped',
      ].contains(normalized)) {
        return false;
      }
    }
    return null;
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.isUpdating,
    required this.onEnabledChanged,
  });

  final _LocalModule module;
  final bool isUpdating;
  final ValueChanged<bool>? onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = module.isProtectedCoreModule
        ? Colors.amberAccent
        : module.enabled
        ? Colors.greenAccent
        : Colors.white38;
    final statusLabel = module.isProtectedCoreModule
        ? '核心模块'
        : module.enabled
        ? '已启用'
        : '已关闭';
    final version = module.version?.isNotEmpty == true
        ? module.version!
        : '未提供';
    final github = module.github?.isNotEmpty == true ? module.github! : '未提供';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.extension_outlined,
                  color: Colors.tealAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(color: statusColor, label: statusLabel),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 32,
                child: isUpdating
                    ? const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Switch(
                        value: module.enabled,
                        onChanged: onEnabledChanged,
                        activeThumbColor: Colors.greenAccent,
                        activeTrackColor: Colors.greenAccent.withValues(
                          alpha: 0.28,
                        ),
                        inactiveThumbColor: Colors.white70,
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.16,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ModuleInfoRow(label: '版本', value: version),
          const SizedBox(height: 8),
          _ModuleInfoRow(label: 'GitHub', value: github),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ModuleInfoRow extends StatelessWidget {
  const _ModuleInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Colors.white54),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
