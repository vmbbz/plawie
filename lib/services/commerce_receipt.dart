import 'dart:convert';

import 'x402_payment_service.dart';
import 'commerce_fee_policy.dart';
import 'preferences_service.dart';

enum CommerceReceiptStatus {
  quoted,
  approvalRequired,
  submitted,
  settled,
  failed,
  uncertain,
  refunded,
  reconciled,
}

/// A local, redacted record of a commerce operation.
///
/// This is an operational receipt, not proof of Plawie revenue. In particular,
/// an x402 provider payment is recorded with a zero platform fee because the
/// provider owns the payment challenge and settlement facts. Realized revenue
/// must arrive later from a verified partner or chain reconciliation source.
class CommerceReceipt {
  factory CommerceReceipt({
    required String receiptId,
    required CommerceLane lane,
    required CommerceReceiptStatus status,
    required DateTime recordedAt,
    required String asset,
    required BigInt grossAmountUnits,
    required BigInt platformFeeUnits,
    required BigInt netAmountUnits,
    String? providerId,
    String? network,
    String? referenceId,
    String? errorCode,
    int? feeScheduleVersion,
    String? quoteId,
  }) {
    final normalizedReceiptId = receiptId.trim();
    final normalizedAsset = asset.trim();
    if (normalizedReceiptId.isEmpty || normalizedReceiptId.length > 160) {
      throw ArgumentError.value(receiptId, 'receiptId', 'must be 1-160 chars');
    }
    if (normalizedAsset.isEmpty || normalizedAsset.length > 128) {
      throw ArgumentError.value(asset, 'asset', 'must be 1-128 chars');
    }
    if (grossAmountUnits < BigInt.zero ||
        platformFeeUnits < BigInt.zero ||
        netAmountUnits < BigInt.zero) {
      throw ArgumentError('Commerce amounts cannot be negative.');
    }
    if (platformFeeUnits > grossAmountUnits ||
        netAmountUnits != grossAmountUnits - platformFeeUnits) {
      throw ArgumentError(
        'Commerce fee and net amounts must reconcile to the gross amount.',
      );
    }
    if (feeScheduleVersion != null && feeScheduleVersion <= 0) {
      throw ArgumentError.value(
        feeScheduleVersion,
        'feeScheduleVersion',
        'must be positive when supplied',
      );
    }

    return CommerceReceipt._(
      receiptId: normalizedReceiptId,
      lane: lane,
      status: status,
      recordedAt: recordedAt.toUtc(),
      asset: normalizedAsset,
      grossAmountUnits: grossAmountUnits,
      platformFeeUnits: platformFeeUnits,
      netAmountUnits: netAmountUnits,
      providerId: _bounded(providerId),
      network: _bounded(network),
      referenceId: _bounded(referenceId, maxLength: 256),
      errorCode: _bounded(errorCode),
      feeScheduleVersion: feeScheduleVersion,
      quoteId: _bounded(quoteId),
    );
  }

  const CommerceReceipt._({
    required this.receiptId,
    required this.lane,
    required this.status,
    required this.recordedAt,
    required this.asset,
    required this.grossAmountUnits,
    required this.platformFeeUnits,
    required this.netAmountUnits,
    this.providerId,
    this.network,
    this.referenceId,
    this.errorCode,
    this.feeScheduleVersion,
    this.quoteId,
  });

  static const int maxReceipts = 100;

  final String receiptId;
  final CommerceLane lane;
  final CommerceReceiptStatus status;
  final DateTime recordedAt;
  final String asset;
  final BigInt grossAmountUnits;
  final BigInt platformFeeUnits;
  final BigInt netAmountUnits;
  final String? providerId;
  final String? network;
  final String? referenceId;
  final String? errorCode;
  final int? feeScheduleVersion;
  final String? quoteId;

  /// Converts an existing redacted x402 receipt without treating user spend
  /// as Plawie revenue.
  factory CommerceReceipt.fromX402(X402PaymentReceipt receipt) {
    final amount = BigInt.tryParse(receipt.amount ?? '');
    if (amount == null || amount < BigInt.zero) {
      throw const FormatException('x402 receipt amount is invalid.');
    }
    return CommerceReceipt(
      receiptId: 'x402:${receipt.intentId}',
      lane: CommerceLane.providerTopUp,
      status: _statusFromX402(receipt.state),
      recordedAt: receipt.recordedAt,
      asset: receipt.asset ?? 'unknown',
      grossAmountUnits: amount,
      platformFeeUnits: BigInt.zero,
      netAmountUnits: amount,
      providerId: receipt.providerId,
      network: receipt.network,
      referenceId: receipt.transactionHash,
      errorCode: receipt.errorCode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'receiptId': receiptId,
        'lane': lane.name,
        'status': status.name,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'asset': asset,
        'grossAmountUnits': grossAmountUnits.toString(),
        'platformFeeUnits': platformFeeUnits.toString(),
        'netAmountUnits': netAmountUnits.toString(),
        if (providerId != null) 'providerId': providerId,
        if (network != null) 'network': network,
        if (referenceId != null) 'referenceId': referenceId,
        if (errorCode != null) 'errorCode': errorCode,
        if (feeScheduleVersion != null)
          'feeScheduleVersion': feeScheduleVersion,
        if (quoteId != null) 'quoteId': quoteId,
      };

  factory CommerceReceipt.fromJson(Map<String, dynamic> json) {
    final lane = _enumByName(CommerceLane.values, json['lane']);
    final status = _enumByName(CommerceReceiptStatus.values, json['status']);
    final recordedAt = DateTime.tryParse(json['recordedAt']?.toString() ?? '');
    final gross = BigInt.tryParse(json['grossAmountUnits']?.toString() ?? '');
    final fee = BigInt.tryParse(json['platformFeeUnits']?.toString() ?? '');
    final net = BigInt.tryParse(json['netAmountUnits']?.toString() ?? '');
    if (lane == null ||
        status == null ||
        recordedAt == null ||
        gross == null ||
        fee == null ||
        net == null) {
      throw const FormatException('Invalid commerce receipt.');
    }
    return CommerceReceipt(
      receiptId: json['receiptId']?.toString() ?? '',
      lane: lane,
      status: status,
      recordedAt: recordedAt,
      asset: json['asset']?.toString() ?? '',
      grossAmountUnits: gross,
      platformFeeUnits: fee,
      netAmountUnits: net,
      providerId: json['providerId']?.toString(),
      network: json['network']?.toString(),
      referenceId: json['referenceId']?.toString(),
      errorCode: json['errorCode']?.toString(),
      feeScheduleVersion: (json['feeScheduleVersion'] as num?)?.toInt(),
      quoteId: json['quoteId']?.toString(),
    );
  }
}

class CommerceReceiptStore {
  CommerceReceiptStore({PreferencesService? preferences})
      : _preferences = preferences ?? PreferencesService();

  final PreferencesService _preferences;

  Future<List<CommerceReceipt>> read() async {
    await _preferences.init();
    final receipts = <CommerceReceipt>[];
    for (final encoded in _preferences.commerceReceipts) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          receipts.add(CommerceReceipt.fromJson(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          ));
        }
      } catch (_) {
        // Ignore one corrupt local record instead of hiding all receipts.
      }
    }
    receipts.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return receipts.take(CommerceReceipt.maxReceipts).toList(growable: false);
  }

  Future<void> append(CommerceReceipt receipt) async {
    final current = await read();
    final encoded = <String>[
      jsonEncode(receipt.toJson()),
      ...current
          .where((item) => item.receiptId != receipt.receiptId)
          .map((item) => jsonEncode(item.toJson())),
    ].take(CommerceReceipt.maxReceipts).toList(growable: false);
    await _preferences.setCommerceReceipts(encoded);
  }
}

CommerceReceiptStatus _statusFromX402(X402PaymentState state) {
  switch (state) {
    case X402PaymentState.challengeReceived:
    case X402PaymentState.awaitingHumanApproval:
    case X402PaymentState.awaitingWalletUnlock:
    case X402PaymentState.signing:
      return CommerceReceiptStatus.approvalRequired;
    case X402PaymentState.submitted:
      return CommerceReceiptStatus.submitted;
    case X402PaymentState.settled:
      return CommerceReceiptStatus.settled;
    case X402PaymentState.uncertain:
      return CommerceReceiptStatus.uncertain;
    case X402PaymentState.rejected:
    case X402PaymentState.expired:
    case X402PaymentState.blockedByPolicy:
    case X402PaymentState.approvalBusy:
    case X402PaymentState.failed:
      return CommerceReceiptStatus.failed;
  }
}

T? _enumByName<T extends Enum>(List<T> values, dynamic raw) {
  final name = raw?.toString();
  if (name == null) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

String? _bounded(String? value, {int maxLength = 128}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.length > maxLength) {
    throw ArgumentError.value(value, 'value', 'exceeds $maxLength characters');
  }
  return normalized;
}
