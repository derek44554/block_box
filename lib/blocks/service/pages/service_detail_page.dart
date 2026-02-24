import 'package:flutter/material.dart';

import '../../../core/models/block_model.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../common/block_detail_page.dart';
import '../utils/service_decryptor.dart';
import '../../../state/block_detail_listener_mixin.dart';


class ServiceDetailPage extends StatefulWidget {
  const ServiceDetailPage({super.key, required this.block});

  final BlockModel block;

  @override
  State<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends State<ServiceDetailPage> with BlockDetailListenerMixin {
  Map<String, dynamic>? _decryptedData;
  bool _isDecrypting = false;
  bool _isEncrypted = false;
  late BlockModel _currentBlock;

  @override
  String? get blockBid => widget.block.bid;

  @override
  void onBlockUpdated(BlockModel updatedBlock) {
    setState(() {
      _currentBlock = updatedBlock;
      // Re-check encryption status with updated block
      _checkAndDecrypt();
    });
  }

  @override
  void initState() {
    super.initState();
    _currentBlock = widget.block;
    startBlockProviderListener();
    _checkAndDecrypt();
  }

  @override
  void dispose() {
    stopBlockProviderListener();
    super.dispose();
  }

  Future<void> _checkAndDecrypt() async {
    _isEncrypted = ServiceDecryptor.isEncrypted(_currentBlock);
    if (!_isEncrypted) return;

    setState(() => _isDecrypting = true);
    
    final result = await ServiceDecryptor.tryDecrypt(_currentBlock);
    
    if (mounted) {
      setState(() {
        _decryptedData = result?.data;
        _isDecrypting = false;
      });
    }
  }

  List<AccountField> _parseAccount() {
    // 如果已解密，使用解密后的数据
    if (_decryptedData != null) {
      final accountList = _decryptedData!['account'];
      if (accountList is List) {
        return accountList
            .map((item) {
              if (item is Map<String, dynamic>) {
                final key = item['k'];
                final value = item['v'];
                if (key is String && value is String) {
                  return AccountField(key: key, value: value);
                }
              }
              return null;
            })
            .whereType<AccountField>()
            .toList();
      }
      return [];
    }

    // 否则使用原始数据
    final accountList = _currentBlock.list<dynamic>('account');
    return accountList
        .map((item) {
          if (item is Map<String, dynamic>) {
            final key = item['k'];
            final value = item['v'];
            if (key is String && value is String) {
              return AccountField(key: key, value: value);
            }
          }
          return null;
        })
        .whereType<AccountField>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
      body: _buildServiceDetailPage(),
    );
  }

  Widget _buildServiceDetailPage() {
    final title = _decryptedData?['name'] as String? ?? widget.block.maybeString('name');
    final intro = _decryptedData?['intro'] as String? ?? widget.block.maybeString('intro');
    final url = _resolveUrl();
    final bid = widget.block.maybeString('bid');
    final account = _parseAccount();
    final tags = _resolveTags();
    final publicInfo = ServiceDecryptor.getPublicInfo(_currentBlock);

    return Container(
      color: Colors.black,
      child: RefreshIndicator(
        onRefresh: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlockDetailPage(block: _currentBlock),
            ),
          );
        },
        color: Colors.white,
        backgroundColor: Colors.grey.shade900,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(),
                  const SizedBox(height: 48),
                  if (_isDecrypting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: Colors.greenAccent,
                              strokeWidth: 2,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '正在解密...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isEncrypted && _decryptedData == null) ...[
                    // 显示公开信息
                    if (publicInfo != null && publicInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          publicInfo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            '此服务已加密，需要密钥才能查看',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                  ] else ...[
                    if (title != null) _buildTitle(title),
                    if (url != null) _buildUrl(url),
                    if (intro != null) _buildIntro(intro),
                    if (publicInfo != null && publicInfo.isNotEmpty) _buildPublicSection(publicInfo),
                    if (account.isNotEmpty) _buildAccountSection(account),
                    if (tags.isNotEmpty) _buildTags(tags),
                  ],
                  if (bid != null) _buildBid(bid),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              '服务',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildUrl(String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: SelectableText(
        formatUrl(url),
        style: TextStyle(
          color: Colors.blue[300],
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildIntro(String intro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Text(
        intro,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildAccountSection(List<AccountField> account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '账户信息',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...account.map((field) => _buildAccountField(field)),
        ],
      ),
    );
  }

  Widget _buildAccountField(AccountField field) {
    final keyLower = field.key.toLowerCase();
    final isSensitive = keyLower.contains('password') || keyLower.contains('pwd');
    final displayedValue = field.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              field.key,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 14,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SelectableText(
              displayedValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBid(String bid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 36, top: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BID',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            formatBid(bid),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'monospace',
              letterSpacing: 0.8,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(List<String> tags) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: tags
            .map(
              (tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 0.6),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPublicSection(String public) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '公开信息',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Text(
            public,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.6,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String? _resolveUrl() {
    // 如果已解密，使用解密后的数据
    if (_decryptedData != null) {
      final website = _decryptedData!['website'];
      if (website is String && website.trim().isNotEmpty) {
        return website.trim();
      }
      return null;
    }

    // 否则使用原始数据
    final direct = widget.block.maybeString('website') ?? widget.block.maybeString('url');
    if (direct != null && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final links = widget.block.list<dynamic>('link');
    for (final entry in links) {
      if (entry is String && entry.trim().isNotEmpty) {
        // 忽略 BID 格式的链接
        if (RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(entry.trim())) {
          continue;
        }
        return entry.trim();
      }
      if (entry is Map<String, dynamic>) {
        final value = entry['url'] ?? entry['value'];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }

  List<String> _resolveTags() {
    final primary = _currentBlock.list<String>('tag');
    if (primary.isNotEmpty) {
      return primary;
    }
    final secondary = _currentBlock.list<String>('tag');
    if (secondary.isNotEmpty) {
      return secondary;
    }
    return const [];
  }
}

class AccountField {
  const AccountField({required this.key, required this.value});

  final String key;
  final String value;
}
