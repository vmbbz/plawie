import 'model_provider_catalog.dart';

/// Applies Plawie's fail-closed plugin boundary to a native OpenClaw config.
///
/// The Android bootstrap separately provisions and SHA-256 verifies each
/// app-owned plugin. This policy only permits those fixed app-private paths,
/// plus the explicitly reviewed plugins that ship inside upstream OpenClaw.
/// It never accepts a plugin path or install record from persisted config.
abstract final class NativeGatewayPluginPolicy {
  static const String verifiedPluginRoot =
      'native-node-embedded/full-openclaw/verified-plugins';

  static void apply(
    Map<String, dynamic> config, {
    required Set<String> retainedProviderIds,
    required String filesDir,
  }) {
    final verifiedPluginIds = retainedProviderIds
        .map(
          (providerId) => ModelProviderCatalog
              .nativeGatewayVerifiedPluginByProvider[providerId],
        )
        .whereType<String>()
        .where(ModelProviderCatalog.nativeGatewayVerifiedPluginIds.contains)
        .toSet();
    final allowedIds = <String>{
      ...ModelProviderCatalog.nativeGatewayBundledPluginIds,
      ...verifiedPluginIds,
    };
    final allowed = allowedIds.toList()..sort();

    final rawPlugins = config['plugins'];
    final plugins = rawPlugins is Map
        ? Map<String, dynamic>.from(rawPlugins)
        : <String, dynamic>{};
    config['plugins'] = plugins;

    plugins['allow'] = allowed;
    plugins.remove('installs');

    if (verifiedPluginIds.isEmpty) {
      plugins.remove('load');
    } else {
      final normalizedFilesDir = filesDir.replaceAll(RegExp(r'/+$'), '');
      final paths = verifiedPluginIds
          .map((id) => '$normalizedFilesDir/$verifiedPluginRoot/$id')
          .toList(growable: false)
        ..sort();
      plugins['load'] = <String, dynamic>{'paths': paths};
    }

    final rawEntries = plugins['entries'];
    final entries = rawEntries is Map
        ? Map<String, dynamic>.from(rawEntries)
        : <String, dynamic>{};
    for (final rawId in entries.keys.toList(growable: false)) {
      final id = rawId.trim().toLowerCase();
      if (!allowedIds.contains(id)) entries.remove(rawId);
    }
    for (final pluginId in verifiedPluginIds) {
      entries[pluginId] = const <String, dynamic>{'enabled': true};
    }
    if (entries.isEmpty) {
      plugins.remove('entries');
    } else {
      plugins['entries'] = entries;
    }

    final rawSlots = plugins['slots'];
    final slots = rawSlots is Map
        ? Map<String, dynamic>.from(rawSlots)
        : <String, dynamic>{};
    for (final rawSlot in slots.keys.toList(growable: false)) {
      final selectedId = slots[rawSlot]?.toString().trim().toLowerCase();
      if (selectedId == null ||
          selectedId == 'none' ||
          !allowedIds.contains(selectedId)) {
        slots.remove(rawSlot);
      }
    }
    if (slots.isEmpty) {
      plugins.remove('slots');
    } else {
      plugins['slots'] = slots;
    }
  }
}
