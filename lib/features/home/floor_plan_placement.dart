import 'package:flutter/material.dart';

/// Placement-time interactions for the floor-plan ("gulvplan") builder.
///
/// The builder computes an item's [FloorPosition] from where it is dropped on
/// the room canvas. For plants it additionally needs to know whether the pot
/// stands on the floor or is raised (table/shelf) — this drives the
/// heating-cable warm-from-below term in the watering model. Call
/// [promptPlantElevation] right after the drop and store the result in
/// `plant.onFloor`.
///
/// Returns `true` for on-floor, `false` for raised, or `null` if the user
/// cancelled the placement.
Future<bool?> promptPlantElevation(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hvor står planten?'),
        content: const Text(
          'Står planten på gulvet eller er den hevet (bord, hylle, henger)? '
          'Dette påvirker om gulvvarme regnes inn i vanningsplanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hevet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('På gulvet'),
          ),
        ],
      ),
    );
