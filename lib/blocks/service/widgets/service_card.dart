import 'package:flutter/material.dart';

import '../../../core/models/block_model.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/formatters/bid_formatter.dart';
import '../../../widgets/border/document_border.dart';
import '../utils/service_decryptor.dart';

class ServiceCard extends StatefulWidget {
  const ServiceCard({super.key, required this.block, this.onTap});

  final BlockModel block;
  final VoidCallback? onTap;

  @override
  State<ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<ServiceCard> {
  Map<String, dynamic>? _decryptedData;
  bool _isDecrypting = false;
  bool _isEncrypted = false;

  @override
  void initState() {
    super.initState();
    _checkAndDecrypt();
  }

  Future<void> _checkAndDecrypt() async {
    _isEncrypted = ServiceDecryptor.isEncrypted(widget.block);
    if (!_isEncrypted) return;

    setState(() => _isDecrypting = true);
    
    final result = await ServiceDecryptor.tryDecrypt(widget.block);
    
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
    final accountList = widget.block.list<dynamic>('account');
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

  String? _getTitle() {
    if (_decryptedData != null) {
      return _decryptedData!['name'] as String?;
    }
    return widget.block.maybeString('name');
  }

  String? _getIntro() {
    if (_decryptedData != null) {
      return _decryptedData!['intro'] as String?;
    }
    return widget.block.maybeString('intro');
  }

  @override
  Widget build(BuildContext context) {
    final title = _getTitle();
    final bid = widget.block.maybeString('bid');
    final url = _resolveUrl();
    final intro = _getIntro();
    final account = _parseAccount();
    final publicInfo = ServiceDecryptor.getPublicInfo(widget.block);

    return GestureDetector(
      onTap: widget.onTap ?? () {
        AppRouter.openBlockDetailPage(context, widget.block);
      },
      child: DocumentBorder(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '服务',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isDecrypting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Colors.greenAccent,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (_isEncrypted && _decryptedData == null) ...[
                // 显示公开信息
                if (publicInfo != null && publicInfo.isNotEmpty)
                  Text(
                    publicInfo,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    '此服务已加密，需要密钥才能查看',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
              ] else ...[
                if (title != null)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 18,
                          height: 1.3,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (url != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.link,
                          color: Colors.blue[300],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            formatUrl(url, maxLength: 30),
                            style: TextStyle(
                              color: Colors.blue[300],
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (intro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    intro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (account.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.account_circle_outlined,
                              color: Colors.white60,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Account',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...account.map((field) => _buildAccountField(field)),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 18),
              if (bid != null)
                Row(
                  children: [
                    Text(
                      formatBid(bid),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        letterSpacing: 2,
                      ),
                    ),
                    if (_isEncrypted) ...[
                      const Spacer(),
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountField(AccountField field) {
    final lowerKey = field.key.toLowerCase();
    final isSensitive = lowerKey.contains('password') || lowerKey.contains('pwd');
    final displayedValue = isSensitive ? '********' : field.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              field.key,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 0.5,
                ),
              ),
              child: Text(
                displayedValue,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountField {
  const AccountField({required this.key, required this.value});

  final String key;
  final String value;
}
