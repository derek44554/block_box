import 'package:flutter/material.dart';

import 'api_keys_page.dart';
import '../../collect/pages/collect_backup_page.dart';


/// 设置页面
/// 
/// 提供各种应用设置选项的入口
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // 账户与安全分组
            _buildSectionHeader('账户与安全'),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              icon: Icons.key_outlined,
              title: '密钥管理',
              subtitle: '管理 API 密钥',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ApiKeysPage(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.security_outlined,
              title: '隐私设置',
              subtitle: '管理隐私和数据安全',
              onTap: () {
                // TODO: 跳转到隐私设置页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.lock_outline,
              title: '密码与验证',
              subtitle: '修改密码和双因素验证',
              onTap: () {
                // TODO: 跳转到密码设置页面
              },
            ),

            const SizedBox(height: 32),

            // 应用设置分组
            _buildSectionHeader('应用设置'),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              icon: Icons.palette_outlined,
              title: '主题设置',
              subtitle: '自定义应用外观',
              onTap: () {
                // TODO: 跳转到主题设置页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.language_outlined,
              title: '语言设置',
              subtitle: '选择应用语言',
              onTap: () {
                // TODO: 跳转到语言设置页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.notifications_outlined,
              title: '通知设置',
              subtitle: '管理通知偏好',
              onTap: () {
                // TODO: 跳转到通知设置页面
              },
            ),

            const SizedBox(height: 32),

            // 数据与存储分组
            _buildSectionHeader('数据与存储'),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              icon: Icons.bookmark_outlined,
              title: '收藏备份',
              subtitle: '导出和导入收藏数据',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CollectBackupPage(),
                  ),
                );
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.cloud_outlined,
              title: '同步设置',
              subtitle: '管理数据同步',
              onTap: () {
                // TODO: 跳转到同步设置页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.storage_outlined,
              title: '存储管理',
              subtitle: '查看和清理缓存',
              onTap: () {
                // TODO: 跳转到存储管理页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.backup_outlined,
              title: '备份与恢复',
              subtitle: '备份和恢复数据',
              onTap: () {
                // TODO: 跳转到备份设置页面
              },
            ),

            const SizedBox(height: 32),

            // 关于分组
            _buildSectionHeader('关于'),
            const SizedBox(height: 12),
            _buildSettingItem(
              context,
              icon: Icons.info_outline,
              title: '关于应用',
              subtitle: '版本信息和更新',
              onTap: () {
                // TODO: 跳转到关于页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.help_outline,
              title: '帮助与反馈',
              subtitle: '获取帮助或提供反馈',
              onTap: () {
                // TODO: 跳转到帮助页面
              },
            ),
            _buildSettingItem(
              context,
              icon: Icons.description_outlined,
              title: '服务条款',
              subtitle: '查看服务条款和隐私政策',
              onTap: () {
                // TODO: 跳转到服务条款页面
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// 构建设置项
  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
