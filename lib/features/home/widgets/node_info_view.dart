import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:block_app/core/network/models/connection_model.dart';
import '../../../../../state/connection_provider.dart';
import '../pages/connection_status_page.dart';
import 'node_hero_status.dart';
import 'placeholder_message.dart';
import 'section_card.dart';

class NodeInfoView extends StatefulWidget {
  const NodeInfoView({super.key});

  @override
  State<NodeInfoView> createState() => _NodeInfoViewState();
}

class _NodeInfoViewState extends State<NodeInfoView> {
  @override
  void initState() {
    super.initState();
    // 页面加载时获取签名信息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<ConnectionProvider>();
        final connection = provider.activeConnection;
        if (connection != null) {
          provider.fetchSignature(connection.address);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次页面显示时都获取签名信息
    final provider = context.read<ConnectionProvider>();
    final connection = provider.activeConnection;
    if (connection != null && connection.signatureData == null) {
      provider.fetchSignature(connection.address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConnectionProvider>();
    final connection = provider.activeConnection;
    final nodeData = connection?.nodeData ?? const <String, dynamic>{};
    final data = nodeData['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final signatureData = connection?.signatureData ?? const <String, dynamic>{};
    
    // 签名信息在 signatureData['data'] 中
    final signatureInfo = signatureData['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};

    if (connection == null) {
      return const PlaceholderMessage(text: '暂无连接，请先添加连接');
    }

    if (connection.status == ConnectionStatus.connecting && nodeData.isEmpty) {
      return const PlaceholderMessage(text: '正在获取节点信息…');
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NodeHeroStatus(connection: connection),
          const SizedBox(height: 16),
          _buildConnectionStatusButton(context),
          const SizedBox(height: 28),
          SectionCard(
            title: '节点详情',
            items: [
              InfoItem(
                label: '节点标识',
                value: (nodeData['sender'] as String?)?.isNotEmpty == true
                    ? nodeData['sender'] as String
                    : '未提供',
              ),
              if (data['intro'] != null && (data['intro'] as String).isNotEmpty)
                InfoItem(
                  label: '节点介绍',
                  value: data['intro'] as String,
                ),
              InfoItem(
                label: 'IPFS 接口',
                value: (data['ipfs_api'] as String?)?.isNotEmpty == true ? data['ipfs_api'] as String : '未提供',
              ),
              InfoItem(
                label: '转发桥',
                value: (data['pivot'] as bool? ?? false) ? '已启用' : '未启用',
              ),
            ],
          ),
          if (signatureData.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionCard(
              title: '签名信息',
              items: [
                InfoItem(
                  label: '权限等级',
                  value: signatureInfo['permission_level']?.toString() ?? '未知',
                ),
                InfoItem(
                  label: '到期时间',
                  value: signatureInfo['validity_period'] as String? ?? '未提供',
                ),
              ],
            ),
          ],
          if (nodeData.isNotEmpty) ...[
            const SizedBox(height: 28),
            SectionCard(
              title: '原始数据',
              items: [
                InfoItem(
                  label: '响应体',
                  value: JsonEncoder.withIndent('  ').convert(data as Object),
                  isMono: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatusButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ConnectionStatusPage(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF1A1A1A).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hub_outlined,
                size: 20,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                '节点状态',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
