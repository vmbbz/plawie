import 'package:clawa/services/bridge/bridge_http_client.dart';
import 'package:clawa/services/bridge/bridge_funding_strategy.dart';
import 'package:clawa/services/bridge/bridge_models.dart';
import 'package:clawa/services/bridge/relay_deposit_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const baseDestination = '0x1111111111111111111111111111111111111111';
  const refundAddress = '0x2222222222222222222222222222222222222222';
  const sourceToken = '0x3333333333333333333333333333333333333333';
  const depositAddress = '0x4444444444444444444444444444444444444444';
  const requestId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const sourceHash =
      '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const destinationHash =
      '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  final now = DateTime.utc(2026, 8, 7, 14);

  test('posts the exact strict self-custody request and parses instruction',
      () async {
    final transport = _FakeTransport()..responses.add(_quoteResponse());
    final service = RelayDepositService(
      transport: transport,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    );

    final instruction = await service.createInstruction(_request());

    expect(transport.postUris.single, Uri.https('api.relay.link', '/quote/v2'));
    expect(transport.maxBytes.single, 256 * 1024);
    expect(transport.postBodies.single, <String, Object?>{
      'user': baseDestination,
      'originChainId': 1,
      'destinationChainId': 8453,
      'originCurrency': sourceToken,
      'destinationCurrency': BridgeConstants.baseUsdc,
      'amount': '1000000',
      'tradeType': 'EXACT_INPUT',
      'recipient': baseDestination,
      'refundTo': refundAddress,
      'useDepositAddress': true,
      'strict': true,
    });
    expect(instruction.requestId, requestId);
    expect(instruction.depositAddress, depositAddress);
    expect(instruction.minimumOutputUnits, '980000');
    expect(instruction.estimatedFeesUsd, closeTo(0.30, 0.000001));
    expect(instruction.createdAt, now);
    expect(instruction.expiresAt, now.add(const Duration(minutes: 10)));
  });

  test('rejects requests outside the strict self-custody boundary', () async {
    final cases = <({BridgeFundingRequest request, String code})>[
      (
        request: _request(selfCustodyConfirmed: false),
        code: 'self_custody_confirmation_required',
      ),
      (
        request: _request(refundAddress: null),
        code: 'refund_address_required',
      ),
      (
        request: _request(refundAddress: '0x1234'),
        code: 'invalid_refund_address',
      ),
      (
        request: _request(solverDepositable: false),
        code: 'unsupported_solver_currency',
      ),
      (
        request: _request(sourceChainId: 10),
        code: 'relay_source_chain_disabled',
      ),
      (
        request: _request(baseDestinationAddress: '0x1234'),
        code: 'invalid_base_destination',
      ),
      (
        request: _request(method: BridgeFundingMethod.connectedWallet),
        code: 'strategy_intent_mismatch',
      ),
    ];

    for (final item in cases) {
      final transport = _FakeTransport();
      await expectLater(
        RelayDepositService(
          transport: transport,
          supportedSourceChainIds: const <int>{1},
          clock: () => now,
        ).createInstruction(item.request),
        throwsA(_bridgeCode(item.code)),
        reason: item.code,
      );
      expect(transport.postBodies, isEmpty, reason: item.code);
    }
  });

  test('rejects missing or duplicate deposit steps', () async {
    for (final steps in <List<Object?>>[
      <Object?>[],
      <Object?>[_depositStep(), _depositStep()],
    ]) {
      final transport = _FakeTransport()
        ..responses.add(_quoteResponse(steps: steps));
      await expectLater(
        RelayDepositService(
          transport: transport,
          supportedSourceChainIds: const <int>{1},
          clock: () => now,
        ).createInstruction(_request()),
        throwsA(_bridgeCode('invalid_relay_deposit_step')),
      );
    }
  });

  test('rejects changed deposit, currency, amount, recipient or request ID',
      () async {
    final invalid = <Map<String, Object?>>[
      _quoteJson(depositAddress: '0x1234'),
      _quoteJson(inputChainId: 10),
      _quoteJson(inputAddress: '0x5555555555555555555555555555555555555555'),
      _quoteJson(inputAmount: '999999'),
      _quoteJson(outputChainId: 10),
      _quoteJson(outputAddress: '0x5555555555555555555555555555555555555555'),
      _quoteJson(recipient: '0x5555555555555555555555555555555555555555'),
      _quoteJson(requestId: ''),
      _quoteJson(refundTo: '0x5555555555555555555555555555555555555555'),
    ];

    for (final json in invalid) {
      final transport = _FakeTransport()..responses.add(_okResponse(json));
      await expectLater(
        RelayDepositService(
          transport: transport,
          supportedSourceChainIds: const <int>{1},
          clock: () => now,
        ).createInstruction(_request()),
        throwsA(isA<BridgeValidationException>()),
      );
    }
  });

  test('tracks by deposit address first and maps verified hashes', () async {
    final transport = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            <String, Object?>{
              'id': requestId,
              'status': 'success',
              'recipient': baseDestination,
              'originChainId': 1,
              'destinationChainId': 8453,
              'depositAddress': <String, Object?>{'address': depositAddress},
              'data': <String, Object?>{
                'inTxs': <Object?>[
                  <String, Object?>{
                    'hash': sourceHash,
                    'chainId': 1,
                    'amount': '1000000',
                  },
                ],
                'outTxs': <Object?>[
                  <String, Object?>{
                    'hash': destinationHash,
                    'chainId': 8453,
                    'amount': '990000',
                  },
                ],
              },
            },
          ],
        }),
      );
    final service = RelayDepositService(
      transport: transport,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    );

    final observation = await service.status(_receipt(now: now));

    expect(transport.getUris.single.path, '/requests/v2');
    expect(transport.getUris.single.queryParameters, <String, String>{
      'id': requestId,
      'depositAddress': depositAddress,
      'includeChildRequests': 'true',
      'originChainId': '1',
      'destinationChainId': '8453',
      'sortBy': 'updatedAt',
      'sortDirection': 'desc',
      'limit': '20',
    });
    expect(observation.state, BridgeFundingState.completed);
    expect(observation.sourceTransactionHash, sourceHash);
    expect(observation.destinationTransactionHash, destinationHash);
    expect(observation.actualOutputUnits, '990000');
  });

  test('address status ignores a hashless destination placeholder', () async {
    final request = _requestStatusJson(
      id: requestId,
      status: 'pending',
      updatedAt: '2026-08-07T14:01:00Z',
      outputAmount: null,
    );
    final data = request['data']! as Map<String, Object?>;
    data['outTxs'] = <Object?>[
      <String, Object?>{
        'hash': null,
        'chainId': 8453,
        'status': 'pending',
      },
    ];
    final transport = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[request],
        }),
      );

    final observation = await RelayDepositService(
      transport: transport,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    ).status(_receipt(now: now));

    expect(observation.state, BridgeFundingState.destinationPending);
    expect(observation.destinationTransactionHash, isNull);
  });

  test('strict status enforces evidenced underpayment and overpayment outcomes',
      () async {
    final invalidSuccess = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            _requestStatusJson(
              id: requestId,
              status: 'success',
              updatedAt: '2026-08-07T14:01:00Z',
              inputAmount: '900000',
              outputAmount: '890000',
            ),
          ],
        }),
      );
    await expectLater(
      RelayDepositService(
        transport: invalidSuccess,
        supportedSourceChainIds: const <int>{1},
        clock: () => now,
      ).status(_receipt(now: now)),
      throwsA(_bridgeCode('relay_status_mismatch')),
    );

    final underpaymentRefund = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            _requestStatusJson(
              id: requestId,
              status: 'refund',
              updatedAt: '2026-08-07T14:02:00Z',
              inputAmount: '900000',
              outputAmount: null,
            ),
          ],
        }),
      );
    final refunded = await RelayDepositService(
      transport: underpaymentRefund,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    ).status(_receipt(now: now));
    expect(refunded.state, BridgeFundingState.refunded);

    final overpaymentPendingRefund = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            _requestStatusJson(
              id: requestId,
              status: 'success',
              updatedAt: '2026-08-07T14:03:00Z',
              inputAmount: '1100000',
              outputAmount: '990000',
            ),
          ],
        }),
      );
    final pendingRefund = await RelayDepositService(
      transport: overpaymentPendingRefund,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    ).status(_receipt(now: now));
    expect(pendingRefund.state, BridgeFundingState.destinationPending);
    expect(pendingRefund.providerStatus, 'success_refund_pending');
  });

  test('strict success without exact input evidence remains unconfirmed',
      () async {
    final request = _requestStatusJson(
      id: requestId,
      status: 'success',
      updatedAt: '2026-08-07T14:01:00Z',
      outputAmount: '990000',
    );
    final data = request['data']! as Map<String, Object?>;
    final inputs = data['inTxs']! as List<Object?>;
    (inputs.single! as Map<String, Object?>).remove('amount');
    data.remove('metadata');
    final transport = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[request],
        }),
      );

    await expectLater(
      RelayDepositService(
        transport: transport,
        supportedSourceChainIds: const <int>{1},
        clock: () => now,
      ).status(_receipt(now: now)),
      throwsA(_bridgeCode('relay_status_mismatch')),
    );
  });

  test(
      'uses the newest child request and classifies fill plus refund as partial',
      () async {
    final transport = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            _requestStatusJson(
              id: requestId,
              status: 'success',
              updatedAt: '2026-08-07T14:01:00Z',
              outputAmount: '990000',
            ),
            _requestStatusJson(
              id: '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
              status: 'refund',
              updatedAt: '2026-08-07T14:02:00Z',
              outputAmount: null,
            ),
          ],
        }),
      );

    final observation = await RelayDepositService(
      transport: transport,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    ).status(_receipt(now: now));

    expect(observation.state, BridgeFundingState.partial);
    expect(observation.providerStatus, 'success_with_refund');
    expect(observation.actualOutputUnits, '990000');
  });

  test('falls back to request ID and maps every documented status', () async {
    final cases = <({String status, BridgeFundingState state})>[
      (status: 'waiting', state: BridgeFundingState.awaitingDeposit),
      (status: 'depositing', state: BridgeFundingState.depositDetected),
      (status: 'pending', state: BridgeFundingState.destinationPending),
      (status: 'submitted', state: BridgeFundingState.destinationPending),
      (status: 'delayed', state: BridgeFundingState.destinationPending),
      (status: 'success', state: BridgeFundingState.destinationPending),
      (status: 'refund', state: BridgeFundingState.refunded),
      (status: 'refunded', state: BridgeFundingState.refunded),
      (status: 'failure', state: BridgeFundingState.failed),
    ];

    for (final item in cases) {
      final transport = _FakeTransport()
        ..responses
            .add(_okResponse(const <String, Object?>{'requests': <Object?>[]}))
        ..responses.add(
          _okResponse(<String, Object?>{
            'status': item.status,
            'details': item.status == 'failure' ? 'NO_QUOTES' : null,
            'inTxHashes': const <String>[sourceHash],
            'txHashes': const <String>[destinationHash],
            'originChainId': 1,
            'destinationChainId': 8453,
          }),
        );
      final observation = await RelayDepositService(
        transport: transport,
        supportedSourceChainIds: const <int>{1},
        clock: () => now,
      ).status(_receipt(now: now));

      expect(observation.state, item.state, reason: item.status);
      expect(transport.getUris.last.path, '/intents/status/v3');
      expect(transport.getUris.last.queryParameters['requestId'], requestId);
    }
  });

  test('request-ID fallback rejects hashes from the wrong chain VM', () async {
    final wrongVmHash = List<String>.filled(80, '1').join();
    final transport = _FakeTransport()
      ..responses
          .add(_okResponse(const <String, Object?>{'requests': <Object?>[]}))
      ..responses.add(
        _okResponse(<String, Object?>{
          'status': 'success',
          'inTxHashes': <String>[wrongVmHash],
          'txHashes': const <String>[destinationHash],
          'originChainId': 1,
          'destinationChainId': 8453,
        }),
      );

    await expectLater(
      RelayDepositService(
        transport: transport,
        supportedSourceChainIds: const <int>{1},
        clock: () => now,
      ).status(_receipt(now: now)),
      throwsA(_bridgeCode('relay_status_mismatch')),
    );
  });

  test('rejects an unevidenced child without the persisted deposit address',
      () async {
    final child = _requestStatusJson(
      id: '0xdddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      status: 'refund',
      updatedAt: '2026-08-07T14:02:00Z',
      outputAmount: null,
    )..remove('depositAddress');
    final transport = _FakeTransport()
      ..responses.add(
        _okResponse(<String, Object?>{
          'requests': <Object?>[
            _requestStatusJson(
              id: requestId,
              status: 'success',
              updatedAt: '2026-08-07T14:01:00Z',
              outputAmount: '990000',
            ),
            child,
          ],
        }),
      );

    await expectLater(
      RelayDepositService(
        transport: transport,
        supportedSourceChainIds: const <int>{1},
        clock: () => now,
      ).status(_receipt(now: now)),
      throwsA(_bridgeCode('relay_status_mismatch')),
    );
  });

  test('Relay strategy rejects connected intents and submits only its quote',
      () async {
    final transport = _FakeTransport()..responses.add(_quoteResponse());
    final provider = RelayDepositService(
      transport: transport,
      supportedSourceChainIds: const <int>{1},
      clock: () => now,
    );
    final strategy = RelayDepositAddressStrategy(
      provider: provider,
      capabilitiesLoader: () async => _emptyCapabilities(now),
    );
    final request = _request();
    final estimate = await strategy.quote(request);
    final instruction = RelayDepositInstruction(
      requestId: estimate.quoteId,
      depositAddress: depositAddress,
      request: request,
      minimumOutputUnits: estimate.minimumOutputUnits,
      minimumOutputDisplay: estimate.minimumOutputDisplay,
      createdAt: estimate.quotedAt,
      expiresAt: estimate.expiresAt,
      estimatedFeesUsd: estimate.estimatedFeesUsd,
    );

    await expectLater(
      strategy.submit(
        ValidatedConnectedBridgeIntent(
          intentId: 'connected',
          request: request,
          quote: _dummyConnectedQuote(request, now),
        ),
      ),
      throwsA(_bridgeCode('strategy_intent_mismatch')),
    );
    final receipt = await strategy.submit(
      ValidatedRelayDepositIntent(
        intentId: 'relay-strategy-intent',
        request: request,
        instruction: instruction,
      ),
    );
    expect(receipt.state, BridgeFundingState.awaitingDeposit);
    expect(receipt.depositAddressExposed, isTrue);
  });
}

Matcher _bridgeCode(String code) => isA<BridgeValidationException>()
    .having((error) => error.code, 'code', code);

BridgeFundingRequest _request({
  BridgeFundingMethod method = BridgeFundingMethod.relayDeposit,
  int sourceChainId = 1,
  String? refundAddress = '0x2222222222222222222222222222222222222222',
  String baseDestinationAddress = '0x1111111111111111111111111111111111111111',
  bool selfCustodyConfirmed = true,
  bool solverDepositable = true,
}) =>
    BridgeFundingRequest(
      method: method,
      sourceChain: BridgeChain(
        id: sourceChainId,
        key: 'eth',
        name: 'Ethereum',
        type: BridgeChainType.evm,
        nativeTokenSymbol: 'ETH',
      ),
      sourceToken: BridgeToken(
        chainId: sourceChainId,
        address: '0x3333333333333333333333333333333333333333',
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: solverDepositable,
      ),
      amount: '1',
      amountUnits: '1000000',
      baseDestinationAddress: baseDestinationAddress,
      refundAddress: refundAddress,
      selfCustodyConfirmed: selfCustodyConfirmed,
    );

BridgeHttpResponse _quoteResponse({List<Object?>? steps}) =>
    _okResponse(_quoteJson(steps: steps));

Map<String, Object?> _quoteJson({
  List<Object?>? steps,
  String requestId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String depositAddress = '0x4444444444444444444444444444444444444444',
  int inputChainId = 1,
  String inputAddress = '0x3333333333333333333333333333333333333333',
  String inputAmount = '1000000',
  int outputChainId = 8453,
  String outputAddress = BridgeConstants.baseUsdc,
  String recipient = '0x1111111111111111111111111111111111111111',
  String refundTo = '0x2222222222222222222222222222222222222222',
}) =>
    <String, Object?>{
      'steps': steps ??
          <Object?>[
            _depositStep(
              requestId: requestId,
              depositAddress: depositAddress,
            ),
          ],
      'details': <String, Object?>{
        'recipient': recipient,
        'refundTo': refundTo,
        'currencyIn': <String, Object?>{
          'currency': <String, Object?>{
            'chainId': inputChainId,
            'address': inputAddress,
            'symbol': 'USDC',
            'decimals': 6,
          },
          'amount': inputAmount,
        },
        'currencyOut': <String, Object?>{
          'currency': <String, Object?>{
            'chainId': outputChainId,
            'address': outputAddress,
            'symbol': 'USDC',
            'decimals': 6,
          },
          'amount': '990000',
          'minimumAmount': '980000',
        },
        'timeEstimate': 120,
      },
      'fees': <String, Object?>{
        'gas': <String, Object?>{'amountUsd': '0.10'},
        'relayer': <String, Object?>{'amountUsd': '0.20'},
      },
    };

Map<String, Object?> _depositStep({
  String requestId =
      '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  String depositAddress = '0x4444444444444444444444444444444444444444',
}) =>
    <String, Object?>{
      'id': 'deposit',
      'kind': 'transaction',
      'requestId': requestId,
      'depositAddress': depositAddress,
      'items': <Object?>[
        <String, Object?>{
          'status': 'incomplete',
          'check': <String, Object?>{
            'endpoint': '/intents/status/v3?requestId=$requestId',
            'method': 'GET',
          },
        },
      ],
    };

BridgeHttpResponse _okResponse(Object? json) => BridgeHttpResponse(
      statusCode: 200,
      headers: const <String, String>{},
      json: json,
    );

Map<String, Object?> _requestStatusJson({
  required String id,
  required String status,
  required String updatedAt,
  String? inputAmount,
  required String? outputAmount,
}) =>
    <String, Object?>{
      'id': id,
      'status': status,
      'updatedAt': updatedAt,
      'recipient': '0x1111111111111111111111111111111111111111',
      'originChainId': 1,
      'destinationChainId': 8453,
      'depositAddress': <String, Object?>{
        'address': '0x4444444444444444444444444444444444444444',
      },
      'data': <String, Object?>{
        'inTxs': <Object?>[
          <String, Object?>{
            'hash':
                '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            'chainId': 1,
            'amount':
                inputAmount ?? (status == 'refund' ? '100000' : '1000000'),
          },
        ],
        'outTxs': outputAmount == null
            ? <Object?>[]
            : <Object?>[
                <String, Object?>{
                  'hash':
                      '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
                  'chainId': 8453,
                  'amount': outputAmount,
                },
              ],
        'metadata': <String, Object?>{
          'currencyIn': <String, Object?>{
            'currency': <String, Object?>{
              'chainId': 1,
              'address': '0x3333333333333333333333333333333333333333',
            },
            'amount':
                inputAmount ?? (status == 'refund' ? '100000' : '1000000'),
          },
        },
      },
    };

BridgeFundingReceipt _receipt({required DateTime now}) => BridgeFundingReceipt(
      schemaVersion: 2,
      intentId: 'relay-intent',
      method: BridgeFundingMethod.relayDeposit,
      provider: 'relay',
      state: BridgeFundingState.awaitingDeposit,
      sourceChainId: 1,
      sourceTokenAddress: '0x3333333333333333333333333333333333333333',
      sourceTokenSymbol: 'USDC',
      sourceAmountUnits: '1000000',
      baseDestinationAddress: '0x1111111111111111111111111111111111111111',
      refundAddress: '0x2222222222222222222222222222222222222222',
      depositAddress: '0x4444444444444444444444444444444444444444',
      providerRequestId:
          '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      minimumOutputUnits: '980000',
      providerStatus: 'waiting',
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      depositAddressExposed: true,
    );

BridgeCapabilitySnapshot _emptyCapabilities(DateTime now) =>
    BridgeCapabilitySnapshot(
      schemaVersion: 1,
      refreshedAt: now,
      connectedChains: const <BridgeChain>[],
      relayChains: const <BridgeChain>[],
      connectedTokensByChain: const <int, List<BridgeToken>>{},
      relayTokensByChain: const <int, List<BridgeToken>>{},
      availabilityReasons: const <String, String>{},
    );

BridgeExecutableQuote _dummyConnectedQuote(
  BridgeFundingRequest request,
  DateTime now,
) =>
    BridgeExecutableQuote(
      estimate: BridgeEstimate(
        provider: 'lifi',
        quoteId: 'dummy',
        request: request,
        minimumOutputUnits: '1',
        minimumOutputDisplay: '0.000001',
        routeTool: 'dummy',
        quotedAt: now,
        expiresAt: now.add(const Duration(minutes: 1)),
      ),
      connectedSourceAddress: '0x2222222222222222222222222222222222222222',
      destinationChainId: BridgeConstants.baseChainId,
      destinationToken: const BridgeToken(
        chainId: BridgeConstants.baseChainId,
        address: BridgeConstants.baseUsdc,
        symbol: 'USDC',
        decimals: 6,
        solverDepositable: false,
      ),
      payload: const EvmBridgeExecutionPayload(
        chainId: 1,
        from: '0x2222222222222222222222222222222222222222',
        to: '0x3333333333333333333333333333333333333333',
        valueHex: '0x0',
        dataHex: '0x',
        gasLimitHex: '0x5208',
        approvalAddress: null,
      ),
      fingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

final class _FakeTransport implements BridgeHttpTransport {
  final List<BridgeHttpResponse> responses = <BridgeHttpResponse>[];
  final List<Uri> getUris = <Uri>[];
  final List<Uri> postUris = <Uri>[];
  final List<Map<String, Object?>> postBodies = <Map<String, Object?>>[];
  final List<int> maxBytes = <int>[];

  @override
  Future<BridgeHttpResponse> getJson(
    Uri uri, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) async {
    getUris.add(uri);
    this.maxBytes.add(maxBytes);
    return responses.removeAt(0);
  }

  @override
  Future<BridgeHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    int maxBytes = 262144,
    Map<String, String> headers = const <String, String>{},
  }) async {
    postUris.add(uri);
    postBodies.add(body);
    this.maxBytes.add(maxBytes);
    return responses.removeAt(0);
  }
}
