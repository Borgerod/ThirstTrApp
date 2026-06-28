import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../models/species.dart';

/// The four round "mini care-tip" circles:
/// light exposure · watering level · fertilizing level · notable care tag.
class CareCircles extends StatelessWidget {
  const CareCircles({super.key, required this.species});
  final Species species;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _Circle(
          icon: _lightIcon(species.lightExposure),
          caption: species.lightExposure.label,
        ),
        _Circle(
          emoji: '💧',
          caption: 'Vann: ${species.wateringLevel.label}',
        ),
        _Circle(
          emoji: '🌱',
          caption: 'Gjødsel: ${species.fertilizingLevel.label}',
        ),
        _Circle(
          emoji: species.careTag.emoji,
          caption: species.careTag.label,
        ),
      ],
    );
  }

  static IconData _lightIcon(LightIntensity l) => switch (l) {
        LightIntensity.shaded => Icons.cloud_outlined,
        LightIntensity.indirect => Icons.wb_cloudy_outlined,
        LightIntensity.direct => Icons.wb_sunny_outlined,
      };
}

class _Circle extends StatelessWidget {
  const _Circle({this.icon, this.emoji, required this.caption});
  final IconData? icon;
  final String? emoji;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.secondaryContainer,
            child: icon != null
                ? Icon(icon, color: scheme.onSecondaryContainer)
                : Text(emoji ?? '', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
