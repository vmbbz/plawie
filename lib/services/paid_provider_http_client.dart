import 'dart:io';

import 'paid_provider_proxy_models.dart';

/// Exact upstream origin policy for paid-provider traffic. Callers must still
/// disable redirect following on every request.
class PaidProviderUpstreamPolicy {
  const PaidProviderUpstreamPolicy._();

  static const Map<PaidProviderId, String> _hosts = {
    PaidProviderId.venice: 'api.venice.ai',
    PaidProviderId.blockrun: 'blockrun.ai',
  };

  static Uri validate(Uri uri, {required PaidProviderId provider}) {
    if (uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.host != _hosts[provider] ||
        (uri.hasPort && uri.port != HttpClient.defaultHttpsPort)) {
      throw const PaidProviderProxyException(
        'Paid-provider upstream origin is not allowed.',
        code: 'upstream_origin_not_allowed',
      );
    }
    return uri;
  }
}
