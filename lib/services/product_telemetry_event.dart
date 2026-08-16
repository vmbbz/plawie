// Consent-aware, payload-redacted product measurement primitives.
//
// This file intentionally has no analytics SDK or network dependency. A later
// PostHog/Supabase adapter must consume this bounded contract rather than
// passing application payloads directly to a third party.

enum ProductTelemetryEventName {
  appFirstOpened,
  appOpened,
  appForegrounded,
  appActiveHeartbeat,
  gatewayReady,
  firstAgentTurnCompleted,
  agentTurnCompleted,
  voiceTurnCompleted,
  wakeWordEnabled,
  companionSessionStarted,
  avatarEquipped,
  onboardingCompleted,
  providerQuoteReceived,
  providerPaymentApproved,
  providerPaymentSubmitted,
  providerPaymentSettled,
  bridgeQuoteReceived,
  bridgeFeeDisplayed,
  bridgeApprovalStarted,
  bridgeSubmitted,
  bridgeSettled,
  avatarCreated,
  avatarValidationPassed,
  avatarMintStarted,
  avatarMinted,
  avatarListingCreated,
  avatarRentalStarted,
  avatarRentalExpired,
  commissionReconciled,
  gatewayFailed,
  voiceTranscriptionFailed,
  ttsFailed,
  foregroundServiceRestarted,
  supportReportSubmitted,
}

extension ProductTelemetryEventNameValue on ProductTelemetryEventName {
  String get wireName {
    switch (this) {
      case ProductTelemetryEventName.appFirstOpened:
        return 'app_first_opened';
      case ProductTelemetryEventName.appOpened:
        return 'app_opened';
      case ProductTelemetryEventName.appForegrounded:
        return 'app_foregrounded';
      case ProductTelemetryEventName.appActiveHeartbeat:
        return 'app_active_heartbeat';
      case ProductTelemetryEventName.gatewayReady:
        return 'gateway_ready';
      case ProductTelemetryEventName.firstAgentTurnCompleted:
        return 'first_agent_turn_completed';
      case ProductTelemetryEventName.agentTurnCompleted:
        return 'agent_turn_completed';
      case ProductTelemetryEventName.voiceTurnCompleted:
        return 'voice_turn_completed';
      case ProductTelemetryEventName.wakeWordEnabled:
        return 'wake_word_enabled';
      case ProductTelemetryEventName.companionSessionStarted:
        return 'companion_session_started';
      case ProductTelemetryEventName.avatarEquipped:
        return 'avatar_equipped';
      case ProductTelemetryEventName.onboardingCompleted:
        return 'onboarding_completed';
      case ProductTelemetryEventName.providerQuoteReceived:
        return 'provider_quote_received';
      case ProductTelemetryEventName.providerPaymentApproved:
        return 'provider_payment_approved';
      case ProductTelemetryEventName.providerPaymentSubmitted:
        return 'provider_payment_submitted';
      case ProductTelemetryEventName.providerPaymentSettled:
        return 'provider_payment_settled';
      case ProductTelemetryEventName.bridgeQuoteReceived:
        return 'bridge_quote_received';
      case ProductTelemetryEventName.bridgeFeeDisplayed:
        return 'bridge_fee_displayed';
      case ProductTelemetryEventName.bridgeApprovalStarted:
        return 'bridge_approval_started';
      case ProductTelemetryEventName.bridgeSubmitted:
        return 'bridge_submitted';
      case ProductTelemetryEventName.bridgeSettled:
        return 'bridge_settled';
      case ProductTelemetryEventName.avatarCreated:
        return 'avatar_created';
      case ProductTelemetryEventName.avatarValidationPassed:
        return 'avatar_validation_passed';
      case ProductTelemetryEventName.avatarMintStarted:
        return 'avatar_mint_started';
      case ProductTelemetryEventName.avatarMinted:
        return 'avatar_minted';
      case ProductTelemetryEventName.avatarListingCreated:
        return 'avatar_listing_created';
      case ProductTelemetryEventName.avatarRentalStarted:
        return 'avatar_rental_started';
      case ProductTelemetryEventName.avatarRentalExpired:
        return 'avatar_rental_expired';
      case ProductTelemetryEventName.commissionReconciled:
        return 'commission_reconciled';
      case ProductTelemetryEventName.gatewayFailed:
        return 'gateway_failed';
      case ProductTelemetryEventName.voiceTranscriptionFailed:
        return 'voice_transcription_failed';
      case ProductTelemetryEventName.ttsFailed:
        return 'tts_failed';
      case ProductTelemetryEventName.foregroundServiceRestarted:
        return 'foreground_service_restarted';
      case ProductTelemetryEventName.supportReportSubmitted:
        return 'support_report_submitted';
    }
  }
}

class ProductTelemetryEvent {
  factory ProductTelemetryEvent({
    required ProductTelemetryEventName name,
    required DateTime occurredAt,
    String? releaseVersion,
    String? releaseChannel,
    Map<String, Object?> properties = const <String, Object?>{},
  }) {
    return ProductTelemetryEvent._(
      name: name,
      occurredAt: occurredAt.toUtc(),
      releaseVersion: _bounded(releaseVersion, maxLength: 64),
      releaseChannel: _bounded(releaseChannel, maxLength: 32),
      properties: _sanitizeProperties(properties),
    );
  }

  const ProductTelemetryEvent._({
    required this.name,
    required this.occurredAt,
    required this.releaseVersion,
    required this.releaseChannel,
    required this.properties,
  });

  static const int schemaVersion = 1;

  /// Only bounded operational dimensions belong in analytics.
  static const Set<String> allowedPropertyKeys = <String>{
    'providerId',
    'lane',
    'status',
    'outcome',
    'errorCode',
    'source',
    'mode',
    'routeTool',
    'network',
    'asset',
    'amountBucket',
    'durationBucket',
    'feeScheduleVersion',
    'reconciled',
    'surface',
  };

  final ProductTelemetryEventName name;
  final DateTime occurredAt;
  final String? releaseVersion;
  final String? releaseChannel;
  final Map<String, Object> properties;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'name': name.wireName,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (releaseVersion != null) 'releaseVersion': releaseVersion,
        if (releaseChannel != null) 'releaseChannel': releaseChannel,
        if (properties.isNotEmpty) 'properties': properties,
      };

  factory ProductTelemetryEvent.fromJson(Map<String, dynamic> json) {
    final name = _eventNameFromWire(json['name']);
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final properties = json['properties'];
    if ((json['schemaVersion'] as num?)?.toInt() != schemaVersion ||
        name == null ||
        occurredAt == null) {
      throw const FormatException('Invalid product telemetry event.');
    }
    if (properties != null && properties is! Map) {
      throw const FormatException('Telemetry properties must be an object.');
    }
    return ProductTelemetryEvent(
      name: name,
      occurredAt: occurredAt,
      releaseVersion: json['releaseVersion']?.toString(),
      releaseChannel: json['releaseChannel']?.toString(),
      properties: properties == null
          ? const <String, Object?>{}
          : Map<String, Object?>.from(
              properties.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
    );
  }
}

typedef ProductTelemetrySender = Future<void> Function(
  Map<String, dynamic> event,
);

/// The app can construct events without an account. Sending begins only after
/// explicit consent, and failures never affect the product flow.
class ProductTelemetryRecorder {
  ProductTelemetryRecorder({
    required ProductTelemetrySender sender,
    this.consentGranted = false,
  }) : _sender = sender;

  final ProductTelemetrySender _sender;
  bool consentGranted;

  Future<void> record(ProductTelemetryEvent event) async {
    if (!consentGranted) return;
    try {
      await _sender(event.toJson());
    } catch (_) {
      // Analytics must never become a product dependency or reveal a failure
      // in the user-facing flow.
    }
  }
}

Map<String, Object> _sanitizeProperties(Map<String, Object?> properties) {
  final sanitized = <String, Object>{};
  for (final entry in properties.entries) {
    if (!ProductTelemetryEvent.allowedPropertyKeys.contains(entry.key)) {
      throw ArgumentError.value(
        entry.key,
        'properties',
        'is not an approved telemetry property',
      );
    }
    final value = entry.value;
    if (value is String) {
      sanitized[entry.key] = _bounded(value, maxLength: 128) ?? '';
    } else if (value is bool) {
      sanitized[entry.key] = value;
    } else if (value is int) {
      if (value < 0 || value > 9007199254740991) {
        throw ArgumentError.value(
          value,
          entry.key,
          'must be a bounded non-negative integer',
        );
      }
      sanitized[entry.key] = value;
    } else {
      throw ArgumentError.value(
        value,
        entry.key,
        'must be a bounded string, boolean, or integer',
      );
    }
  }
  return Map<String, Object>.unmodifiable(sanitized);
}

String? _bounded(String? value, {required int maxLength}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw ArgumentError.value(value, 'value', 'exceeds $maxLength characters');
  }
  return normalized;
}

ProductTelemetryEventName? _eventNameFromWire(dynamic raw) {
  final name = raw?.toString();
  if (name == null) return null;
  for (final candidate in ProductTelemetryEventName.values) {
    if (candidate.wireName == name) return candidate;
  }
  return null;
}
