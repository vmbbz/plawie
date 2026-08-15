import 'dynamic_model_catalog.dart';

/// A same-provider replacement that has already completed Plawie's exact
/// mobile tool loop. This is a proposal only; it never changes selection or
/// resubmits a turn.
class ProviderCompatibleFallback {
  const ProviderCompatibleFallback({
    required this.modelId,
    required this.label,
    required this.providerId,
  });

  final String modelId;
  final String label;
  final String providerId;
}

class ProviderCompatibleFallbackPlanner {
  const ProviderCompatibleFallbackPlanner._();

  static ProviderCompatibleFallback? find({
    required DynamicCatalogSnapshot snapshot,
    required String selectedModelId,
    required bool requiresVision,
  }) {
    DynamicModelRecord? selected;
    DynamicProviderRecord? owner;
    for (final provider in snapshot.providers) {
      for (final model in provider.models) {
        if (model.id == selectedModelId) {
          selected = model;
          owner = provider;
          break;
        }
      }
      if (selected != null) break;
    }
    if (selected == null || owner == null) return null;

    final now = DateTime.now().toUtc();
    final candidates = owner.models.where((model) {
      if (model.id == selected!.id ||
          !model.liveAvailable ||
          !model.agentReady) {
        return false;
      }
      if (model.route != selected.route || model.providerId != owner!.id) {
        return false;
      }
      if ((requiresVision || selected.supportsVision == true) &&
          model.supportsVision != true) {
        return false;
      }
      final retirement = model.deprecationDate;
      return retirement == null || retirement.isAfter(now);
    }).toList(growable: false)
      ..sort((a, b) {
        if (a.recommended != b.recommended) return a.recommended ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    if (candidates.isEmpty) return null;
    final candidate = candidates.first;
    return ProviderCompatibleFallback(
      modelId: candidate.id,
      label: candidate.label,
      providerId: candidate.providerId,
    );
  }
}
