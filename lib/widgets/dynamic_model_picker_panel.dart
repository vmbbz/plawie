import 'package:flutter/material.dart';

import '../services/dynamic_model_catalog.dart';
import '../services/wallet_funded_provider_readiness.dart';

class DynamicModelPickerLocalOption {
  const DynamicModelPickerLocalOption({
    required this.id,
    required this.label,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String subtitle;
}

/// Shared searchable provider/model surface for Chat and Settings. It renders
/// catalog truth separately from wallet/payment readiness and never performs a
/// provider action itself.
class DynamicModelPickerPanel extends StatefulWidget {
  const DynamicModelPickerPanel({
    super.key,
    required this.snapshot,
    required this.currentModelId,
    required this.walletReadiness,
    required this.onSelected,
    required this.onProviderAction,
    this.localOption,
    this.onLocalSelected,
    this.initiallyExpandedProviderIds = const <String>{},
    this.autofocusSearch = false,
  });

  final DynamicCatalogSnapshot snapshot;
  final String currentModelId;
  final Map<String, WalletFundedProviderReadiness> walletReadiness;
  final ValueChanged<DynamicModelRecord> onSelected;
  final void Function(String providerId, WalletFundedProviderAction action)
      onProviderAction;
  final DynamicModelPickerLocalOption? localOption;
  final ValueChanged<String>? onLocalSelected;
  final Set<String> initiallyExpandedProviderIds;
  final bool autofocusSearch;

  @override
  State<DynamicModelPickerPanel> createState() =>
      _DynamicModelPickerPanelState();
}

class _DynamicModelPickerPanelState extends State<DynamicModelPickerPanel> {
  String _query = '';
  late final Set<String> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = <String>{...widget.initiallyExpandedProviderIds};
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final groups = widget.snapshot.providers
        .map((provider) {
          final providerMatches = normalizedQuery.isEmpty ||
              provider.label.toLowerCase().contains(normalizedQuery) ||
              provider.id.toLowerCase().contains(normalizedQuery);
          final models = providerMatches
              ? provider.models
              : provider.models
                  .where((model) =>
                      model.label.toLowerCase().contains(normalizedQuery) ||
                      model.id.toLowerCase().contains(normalizedQuery))
                  .toList(growable: false);
          return (provider: provider, models: models);
        })
        .where((group) => group.models.isNotEmpty)
        .toList(growable: false);

    return RadioGroup<String>(
      groupValue: widget.currentModelId,
      onChanged: (modelId) {
        if (modelId == null) return;
        final local = widget.localOption;
        if (local != null && local.id == modelId) {
          widget.onLocalSelected?.call(modelId);
          return;
        }
        for (final provider in widget.snapshot.providers) {
          for (final model in provider.models) {
            if (model.id == modelId) {
              final readiness = widget.walletReadiness[provider.id];
              if (model.liveAvailable &&
                  (readiness == null || readiness.canSelectModels)) {
                widget.onSelected(model);
              }
              return;
            }
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('model-picker-search'),
            autofocus: widget.autofocusSearch,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search models or providers',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (_showsStaleWarning) ...[
            const SizedBox(height: 8),
            Text(
              widget.snapshot.state == DynamicCatalogSnapshotState.stale
                  ? 'Showing cached provider metadata'
                  : 'Provider refresh failed · showing the last usable catalog',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (widget.localOption != null) ...[
                  _sectionLabel(context, 'ON-DEVICE'),
                  RadioListTile<String>(
                    key: Key('model-option-${widget.localOption!.id}'),
                    dense: true,
                    title: Text(widget.localOption!.label),
                    subtitle: Text(
                      widget.localOption!.subtitle,
                      style: theme.textTheme.labelSmall,
                    ),
                    value: widget.localOption!.id,
                  ),
                  const Divider(),
                ],
                if (groups.isNotEmpty)
                  _sectionLabel(context, 'CLOUD PROVIDERS'),
                ...groups.map((group) => _providerGroup(
                      context,
                      group.provider,
                      group.models,
                      normalizedQuery,
                    )),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No cached models match that search.'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _showsStaleWarning =>
      widget.snapshot.state == DynamicCatalogSnapshotState.stale ||
      widget.snapshot.state == DynamicCatalogSnapshotState.error;

  Widget _providerGroup(
    BuildContext context,
    DynamicProviderRecord provider,
    List<DynamicModelRecord> models,
    String normalizedQuery,
  ) {
    final readiness = widget.walletReadiness[provider.id];
    final isExpanded =
        normalizedQuery.isNotEmpty || _expanded.contains(provider.id);
    return ExpansionTile(
      key: PageStorageKey<String>(
        'models-${provider.id}-search-${normalizedQuery.isNotEmpty}',
      ),
      initiallyExpanded: isExpanded,
      onExpansionChanged: (value) {
        setState(() {
          if (value) {
            _expanded.add(provider.id);
          } else {
            _expanded.remove(provider.id);
          }
        });
      },
      tilePadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(
              provider.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (readiness != null) _walletBadge(context),
        ],
      ),
      subtitle: readiness == null
          ? Text(
              '${models.length} models · ${_connectionLabel(provider.connectionState)} · ${_catalogLabel(provider.catalogState)}',
              style: Theme.of(context).textTheme.labelSmall,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  readiness.title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: readiness.needsAttention
                            ? Colors.amber
                            : Colors.greenAccent,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  readiness.detail,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(readiness.catalogLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    Text(readiness.transportLabel,
                        style: Theme.of(context).textTheme.labelSmall),
                    if (readiness.primaryAction !=
                        WalletFundedProviderAction.none)
                      TextButton(
                        key: Key('provider-action-${provider.id}'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onPressed: () => widget.onProviderAction(
                          provider.id,
                          readiness.primaryAction,
                        ),
                        child: Text(readiness.primaryActionLabel),
                      ),
                  ],
                ),
              ],
            ),
      children: isExpanded
          ? models
              .map((model) => _modelTile(context, model, readiness))
              .toList(growable: false)
          : const <Widget>[],
    );
  }

  Widget _modelTile(
    BuildContext context,
    DynamicModelRecord model,
    WalletFundedProviderReadiness? readiness,
  ) {
    final enabled = model.liveAvailable && (readiness?.canSelectModels ?? true);
    final subtitle = !model.liveAvailable
        ? model.unavailableReason ?? 'This catalog entry is informational.'
        : '${model.agentReady ? 'Agent-ready' : 'Tool support unknown'} · ${model.id}';
    return RadioListTile<String>(
      key: Key('model-option-${model.id}'),
      dense: true,
      enabled: enabled,
      title: Text(model.label, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelSmall,
        overflow: model.liveAvailable ? TextOverflow.ellipsis : null,
      ),
      value: model.id,
    );
  }

  Widget _walletBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0052FF).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF5B8CFF).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'WALLET FUNDED',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF7EA2FF),
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
        ),
      );

  String _connectionLabel(DynamicProviderConnectionState state) =>
      switch (state) {
        DynamicProviderConnectionState.unknown => 'Status unknown',
        DynamicProviderConnectionState.connected => 'Connected',
        DynamicProviderConnectionState.needsConfiguration => 'Key required',
        DynamicProviderConnectionState.unavailable => 'Unavailable',
        DynamicProviderConnectionState.error => 'Connection error',
      };

  String _catalogLabel(DynamicProviderCatalogState state) => switch (state) {
        DynamicProviderCatalogState.fresh => 'Live catalog',
        DynamicProviderCatalogState.stale => 'Cached catalog',
        DynamicProviderCatalogState.offlineFallback => 'Offline fallback',
        DynamicProviderCatalogState.unavailable => 'Catalog unavailable',
      };
}
