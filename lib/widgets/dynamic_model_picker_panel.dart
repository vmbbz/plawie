import 'package:flutter/material.dart';

import '../services/dynamic_model_catalog.dart';
import '../services/wallet_funded_provider_readiness.dart';

typedef WalletProviderBalanceRefresh
    = Future<Map<String, WalletFundedProviderReadiness>> Function(
  String providerId,
);

typedef DynamicModelCatalogRefresh = Future<DynamicCatalogSnapshot> Function(
  String providerId,
);

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
/// catalog truth separately from wallet/payment readiness. An injected balance
/// refresher may perform a read-only, device-authenticated provider check in
/// place; payment, top-up, transport, and wallet actions remain parent-owned.
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
    this.autoRefreshWalletBalances = false,
    this.onRefreshProviderBalance,
    this.onRefreshModels,
    this.onTestTools,
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
  final bool autoRefreshWalletBalances;
  final WalletProviderBalanceRefresh? onRefreshProviderBalance;
  final DynamicModelCatalogRefresh? onRefreshModels;
  final ValueChanged<DynamicModelRecord>? onTestTools;

  @override
  State<DynamicModelPickerPanel> createState() =>
      _DynamicModelPickerPanelState();
}

class _DynamicModelPickerPanelState extends State<DynamicModelPickerPanel> {
  String _query = '';
  late final Set<String> _expanded;
  late DynamicCatalogSnapshot _snapshot;
  late Map<String, WalletFundedProviderReadiness> _walletReadiness;
  final Set<String> _busyProviders = <String>{};
  final Set<String> _busyCatalogProviders = <String>{};
  String? _balanceStatus;
  String? _catalogStatus;
  bool _showAllModels = false;
  bool _autoRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _expanded = <String>{...widget.initiallyExpandedProviderIds};
    _snapshot = widget.snapshot;
    _walletReadiness = <String, WalletFundedProviderReadiness>{
      ...widget.walletReadiness,
    };
    _scheduleAutomaticBalanceRefresh();
  }

  @override
  void didUpdateWidget(covariant DynamicModelPickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletReadiness != widget.walletReadiness) {
      _walletReadiness = <String, WalletFundedProviderReadiness>{
        ...widget.walletReadiness,
      };
      _scheduleAutomaticBalanceRefresh();
    }
    if (oldWidget.snapshot != widget.snapshot) {
      _snapshot = widget.snapshot;
    }
  }

  void _scheduleAutomaticBalanceRefresh() {
    if (!widget.autoRefreshWalletBalances ||
        widget.onRefreshProviderBalance == null ||
        _autoRefreshScheduled) {
      return;
    }
    final providers = _walletReadiness.values
        .where((readiness) =>
            readiness.state == WalletFundedProviderState.balanceUnknown &&
            readiness.primaryAction ==
                WalletFundedProviderAction.refreshBalance)
        .map((readiness) => readiness.providerId)
        .toList(growable: false);
    if (providers.isEmpty) return;
    _autoRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final providerId in providers) {
        if (!mounted) return;
        await _refreshProviderBalance(providerId, automatic: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedQuery = _query.trim().toLowerCase();
    final groups = _snapshot.providers
        .map((provider) {
          final candidateModels = (_showAllModels
                  ? provider.models
                  : provider.models
                      .where((model) => model.supportsToolCalls == true))
              .toList()
            ..sort(_compareModels);
          final providerMatches = normalizedQuery.isEmpty ||
              provider.label.toLowerCase().contains(normalizedQuery) ||
              provider.id.toLowerCase().contains(normalizedQuery);
          final models = providerMatches
              ? candidateModels
              : candidateModels
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
        for (final provider in _snapshot.providers) {
          for (final model in provider.models) {
            if (model.id == modelId) {
              final readiness = _walletReadiness[provider.id];
              if (!model.liveAvailable) return;
              if (readiness == null || readiness.canSelectModels) {
                widget.onSelected(model);
              } else if (readiness.primaryAction !=
                  WalletFundedProviderAction.none) {
                _runProviderAction(
                  provider.id,
                  readiness.primaryAction,
                );
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
              _snapshot.state == DynamicCatalogSnapshotState.stale
                  ? 'Showing cached provider metadata'
                  : 'Provider refresh failed · showing the last usable catalog',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                key: const Key('model-filter-agent'),
                label: const Text('Agent candidates'),
                selected: !_showAllModels,
                onSelected: (selected) {
                  if (selected) setState(() => _showAllModels = false);
                },
              ),
              FilterChip(
                key: const Key('model-filter-all'),
                label: const Text('All chat models'),
                selected: _showAllModels,
                onSelected: (selected) {
                  if (selected) setState(() => _showAllModels = true);
                },
              ),
              Text(
                _showAllModels
                    ? 'Every live chat route'
                    : 'Routes reporting tool support; verification is separate',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          if (_catalogStatus != null) ...[
            const SizedBox(height: 8),
            _statusBanner(
              context,
              key: const Key('model-catalog-status'),
              message: _catalogStatus!,
              busy: _busyCatalogProviders.isNotEmpty,
            ),
          ],
          if (_balanceStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('provider-balance-status'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.tealAccent.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                children: [
                  if (_busyProviders.isNotEmpty) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ] else ...[
                    const Icon(Icons.info_outline_rounded, size: 16),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _balanceStatus!,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
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
      _snapshot.state == DynamicCatalogSnapshotState.stale ||
      _snapshot.state == DynamicCatalogSnapshotState.error;

  Widget _providerGroup(
    BuildContext context,
    DynamicProviderRecord provider,
    List<DynamicModelRecord> models,
    String normalizedQuery,
  ) {
    final readiness = _walletReadiness[provider.id];
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
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${models.length} models · ${_connectionLabel(provider.connectionState)} · ${_catalogLabel(provider)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                if (widget.onRefreshModels != null)
                  _refreshModelsButton(provider),
              ],
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
                        onPressed: _busyProviders.contains(provider.id)
                            ? null
                            : () => _runProviderAction(
                                  provider.id,
                                  readiness.primaryAction,
                                ),
                        child: _busyProviders.contains(provider.id)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(readiness.primaryActionLabel),
                      ),
                    if (widget.onRefreshModels != null)
                      _refreshModelsButton(provider),
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
    final blocked =
        model.liveAvailable && readiness != null && !readiness.canSelectModels;
    final enabled = model.liveAvailable;
    final retirement =
        model.deprecationDate?.toIso8601String().split('T').first;
    final subtitle = !model.liveAvailable
        ? model.unavailableReason ?? 'This catalog entry is informational.'
        : blocked
            ? '${readiness.title} — ${readiness.detail}'
            : '${model.readinessLabel} · ${model.id}${retirement == null ? '' : ' · retires $retirement'}'
                '${model.capabilityDetail == null ? '' : '\n${model.capabilityDetail}'}';
    final canTestTools = widget.onTestTools != null &&
        enabled &&
        !blocked &&
        !model.agentReady &&
        model.supportsToolCalls != false;
    return RadioListTile<String>(
      key: Key('model-option-${model.id}'),
      dense: true,
      enabled: enabled,
      title: Text(model.label, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.labelSmall,
        maxLines: blocked || model.capabilityDetail != null ? 3 : null,
        overflow: model.liveAvailable ? TextOverflow.ellipsis : null,
      ),
      secondary: blocked
          ? const Icon(Icons.lock_clock_rounded, size: 18, color: Colors.amber)
          : canTestTools
              ? TextButton.icon(
                  key: Key('model-tool-test-${model.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () => widget.onTestTools!(model),
                  icon: const Icon(Icons.science_outlined, size: 16),
                  label: Text(
                    model.toolReadiness == ModelToolReadiness.incompatible
                        ? 'Retest tools'
                        : 'Verify tools',
                  ),
                )
              : !model.liveAvailable && model.deprecationDate != null
                  ? const Icon(Icons.event_busy_rounded,
                      size: 18, color: Colors.amber)
                  : model.agentReady
                      ? const Tooltip(
                          message: 'Complete tool loop verified',
                          child: Icon(Icons.verified_rounded,
                              size: 18, color: Colors.greenAccent),
                        )
                      : null,
      value: model.id,
    );
  }

  void _runProviderAction(
    String providerId,
    WalletFundedProviderAction action,
  ) {
    if (action == WalletFundedProviderAction.refreshBalance &&
        widget.onRefreshProviderBalance != null) {
      _refreshProviderBalance(providerId, automatic: false);
      return;
    }
    widget.onProviderAction(providerId, action);
  }

  Future<void> _refreshProviderBalance(
    String providerId, {
    required bool automatic,
  }) async {
    if (_busyProviders.contains(providerId) ||
        widget.onRefreshProviderBalance == null) {
      return;
    }
    var label = providerId;
    for (final provider in _snapshot.providers) {
      if (provider.id == providerId) {
        label = provider.label;
        break;
      }
    }
    setState(() {
      _busyProviders.add(providerId);
      _balanceStatus = automatic
          ? 'Securely checking $label balance… Approve the device authentication request to continue.'
          : 'Refreshing $label balance securely…';
    });
    try {
      final refreshed = await widget.onRefreshProviderBalance!(providerId);
      if (!mounted) return;
      final readiness = refreshed[providerId];
      setState(() {
        _walletReadiness = <String, WalletFundedProviderReadiness>{
          ..._walletReadiness,
          ...refreshed,
        };
        _balanceStatus = switch (readiness?.state) {
          WalletFundedProviderState.ready ||
          WalletFundedProviderState.balanceLow =>
            '$label balance refreshed. Available models are ready to select.',
          WalletFundedProviderState.balanceDepleted =>
            '$label balance refreshed. Top up before selecting a model.',
          _ => readiness?.detail ??
              '$label balance refresh finished. Review its current status below.',
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _balanceStatus =
            '$label balance was not refreshed. Use its check-balance action to try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _busyProviders.remove(providerId));
      }
    }
  }

  Widget _refreshModelsButton(DynamicProviderRecord provider) {
    final busy = _busyCatalogProviders.contains(provider.id);
    return TextButton.icon(
      key: Key('provider-refresh-models-${provider.id}'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      onPressed: busy ? null : () => _refreshModels(provider),
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 15),
      label: Text(busy ? 'Refreshing…' : 'Refresh live models'),
    );
  }

  Future<void> _refreshModels(DynamicProviderRecord provider) async {
    final callback = widget.onRefreshModels;
    if (callback == null || _busyCatalogProviders.contains(provider.id)) {
      return;
    }
    setState(() {
      _busyCatalogProviders.add(provider.id);
      _catalogStatus = 'Refreshing ${provider.label} model metadata…';
    });
    try {
      final refreshed = await callback(provider.id);
      if (!mounted) return;
      setState(() {
        _snapshot = refreshed;
        _catalogStatus =
            '${provider.label} catalog refreshed. Provider metadata is current; verify tools before using Agent mode.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _catalogStatus =
            '${provider.label} catalog refresh failed. Showing the last usable catalog.';
      });
    } finally {
      if (mounted) {
        setState(() => _busyCatalogProviders.remove(provider.id));
      }
    }
  }

  Widget _statusBanner(
    BuildContext context, {
    required Key key,
    required String message,
    required bool busy,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          if (busy) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Icon(Icons.info_outline_rounded, size: 16),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(message, style: theme.textTheme.labelSmall)),
        ],
      ),
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

  int _compareModels(DynamicModelRecord a, DynamicModelRecord b) {
    final aCreated = a.providerCreatedAt;
    final bCreated = b.providerCreatedAt;
    if (aCreated != null && bCreated != null) {
      final byDate = bCreated.compareTo(aCreated);
      if (byDate != 0) return byDate;
    } else if (aCreated != null) {
      return -1;
    } else if (bCreated != null) {
      return 1;
    }
    final byReadiness = _toolReadinessRank(b.toolReadiness)
        .compareTo(_toolReadinessRank(a.toolReadiness));
    if (byReadiness != 0) return byReadiness;
    return a.label.toLowerCase().compareTo(b.label.toLowerCase());
  }

  int _toolReadinessRank(ModelToolReadiness readiness) => switch (readiness) {
        ModelToolReadiness.loopVerified => 4,
        ModelToolReadiness.schemaAccepted => 3,
        ModelToolReadiness.providerAdvertised => 2,
        ModelToolReadiness.unknown => 1,
        ModelToolReadiness.incompatible => 0,
      };

  String _catalogLabel(DynamicProviderRecord provider) {
    final base = switch (provider.catalogState) {
      DynamicProviderCatalogState.fresh => 'Live catalog',
      DynamicProviderCatalogState.stale => 'Cached catalog',
      DynamicProviderCatalogState.offlineFallback => 'Offline fallback',
      DynamicProviderCatalogState.unavailable => 'Catalog unavailable',
    };
    final refreshed = provider.lastRefreshedAt;
    if (refreshed == null) return base;
    final date = refreshed.toLocal().toIso8601String().split('T').first;
    return '$base · $date';
  }
}
