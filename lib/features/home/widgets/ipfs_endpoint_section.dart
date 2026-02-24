import 'package:flutter/material.dart';

class IpfsEndpointSection extends StatefulWidget {
  const IpfsEndpointSection({super.key, this.initialValue, required this.onSubmitted});

  final String? initialValue;
  final ValueChanged<String?> onSubmitted;

  @override
  State<IpfsEndpointSection> createState() => _IpfsEndpointSectionState();
}

class _IpfsEndpointSectionState extends State<IpfsEndpointSection> {
  late final TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void didUpdateWidget(covariant IpfsEndpointSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    widget.onSubmitted(text.isEmpty ? null : text);
    setState(() {
      _isEditing = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'IPFS 接口地址',
                style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.6),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                  });
                },
                child: Text(
                  _isEditing ? '取消' : '编辑',
                  style: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FocusScope(
            onFocusChange: (hasFocus) {
              if (!hasFocus && _isEditing) {
                _handleSubmit();
              }
            },
            child: TextField(
              controller: _controller,
              enabled: _isEditing,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: '例如：https://127.0.0.1:5001/api/v0',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(_isEditing ? 0.06 : 0.03),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _handleSubmit(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.initialValue?.isNotEmpty == true
                      ? widget.initialValue!
                      : '当前未设置 IPFS 地址',
                  style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 0.4),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isEditing)
                ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(82, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('保存'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
