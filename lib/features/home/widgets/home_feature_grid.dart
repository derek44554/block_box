import 'package:flutter/material.dart';

typedef FeatureTapCallback = void Function(HomeFeature feature);

class HomeFeatureGrid extends StatelessWidget {
  const HomeFeatureGrid({
    super.key,
    required this.features,
    required this.onTap,
  });

  final List<HomeFeature> features;
  final FeatureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 16,
      children: features
          .map(
            (feature) => Container(
              width: 104,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.06),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onTap(feature),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(feature.icon, color: Colors.white, size: 17),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        feature.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 0.4,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class HomeFeature {
  const HomeFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

