import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clawa/services/gateway_runtime.dart';
import 'package:clawa/services/preferences_service.dart';

void main() {
  test('paid proxy preparation precedes Gateway start and follows Gateway stop',
      () async {
    final source =
        await File('lib/services/gateway_service.dart').readAsString();
    final attachStart = source.indexOf('Future<void> attachOrStart(');
    final attachEnd = source.indexOf('Future<void> start() async', attachStart);
    final attach = source.substring(attachStart, attachEnd);
    expect(attach.indexOf('_preparePaidProviderRouting('), isNonNegative);
    expect(
        attach.indexOf('final success = await _runtime.start('), isNonNegative);
    expect(
      attach.indexOf('_preparePaidProviderRouting('),
      lessThan(attach.indexOf('final success = await _runtime.start(')),
    );

    final stopStart = source.indexOf('Future<void> stop() async');
    final stopEnd = source.indexOf('void _startHealthCheck()', stopStart);
    final stop = source.substring(stopStart, stopEnd);
    expect(stop.indexOf('await _runtime.stop()'), isNonNegative);
    expect(
      stop.indexOf('_retirePaidProviderRoutingAfterGatewayStop()'),
      isNonNegative,
    );
    expect(
      stop.indexOf('await _runtime.stop()'),
      lessThan(
        stop.indexOf('_retirePaidProviderRoutingAfterGatewayStop()'),
      ),
    );

    final retireStart = source.indexOf(
      'Future<void> _retirePaidProviderRoutingAfterGatewayStop()',
    );
    final retireEnd = source.indexOf(
      'Future<bool> _preparePaidProviderRoutingOnce(',
      retireStart,
    );
    final retire = source.substring(retireStart, retireEnd);
    expect(retire.indexOf('removeGatewayCapabilities(config)'), isNonNegative);
    expect(retire.indexOf('await _writeConfig(config)'), isNonNegative);
    expect(
      retire.indexOf('await _writeConfig(config)'),
      lessThan(retire.indexOf('stopAfterGateway(gatewayStopped: true)')),
      reason: 'persisted capabilities must be scrubbed before rotation',
    );
  });

  test('wallet-funded routing does not change the native production owner', () {
    expect(
      GatewayRuntimeRegistry.current.id,
      PreferencesService.gatewayRuntimeOwnerNativeProduction,
    );
    expect(
      GatewayRuntimeRegistry.current,
      isNot(same(GatewayRuntimeRegistry.prootRollback)),
    );
  });

  test('paid routing compares semantic config instead of JSON key order',
      () async {
    final source =
        await File('lib/services/gateway_service.dart').readAsString();
    final prepareStart = source.indexOf(
      'Future<bool> _preparePaidProviderRoutingOnce(',
    );
    final prepareEnd = source.indexOf(
      'bool get _hasGatewayConfigTransition',
      prepareStart,
    );
    final prepare = source.substring(prepareStart, prepareEnd);

    expect(
      prepare,
      contains('final before = canonicalGatewayConfigSignature(config);'),
    );
    expect(
      prepare,
      contains('canonicalGatewayConfigSignature(config) != before'),
    );
    expect(prepare, isNot(contains('jsonEncode(config) != before')));
  });
}
