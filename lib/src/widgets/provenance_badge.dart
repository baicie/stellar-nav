import 'package:astro_nav/src/design/tokens.dart';
import 'package:astro_nav/src/domain/models.dart';
import 'package:flutter/material.dart';

class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge({
    required this.provenance,
    this.compact = false,
    super.key,
  });

  final Provenance provenance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (provenance.nature) {
      DataNature.observed => AppColors.green,
      DataNature.derived => AppColors.blue,
      DataNature.simulated => AppColors.amber,
      DataNature.fictional => AppColors.coral,
    };
    final label = compact
        ? provenance.nature.shortLabelZh
        : provenance.nature.labelZh;
    return Semantics(
      label: '$label，${provenance.noteZh}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: color, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
