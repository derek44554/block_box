import 'package:flutter/material.dart';

class MacSectionPanel extends StatelessWidget {
  const MacSectionPanel({
    super.key,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.highlights,
    required this.body,
    this.primaryLabel,
    this.onPrimaryTap,
  });

  final String title;
  final String description;
  final Color accentColor;
  final List<String> highlights;
  final Widget body;
  final String? primaryLabel;
  final VoidCallback? onPrimaryTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = Colors.white.withOpacity(0.92);
    final secondaryColor = Colors.white.withOpacity(0.65);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: secondaryColor,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: highlights
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withOpacity(0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        color: accentColor.withOpacity(0.9),
                        fontSize: 11.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.04),
                    width: 0.8,
                  ),
                ),
                child: body,
              ),
            ),
          ),
          if (primaryLabel != null && onPrimaryTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimaryTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(primaryLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
