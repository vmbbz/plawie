import assert from 'node:assert/strict';

import {
  attributionFromUrl,
  classifyTrackedLink,
  createCapturePayload,
  isProductHuntAttribution,
  normalizeAnalyticsConfig,
  normalizeAttribution,
  normalizeSurface,
} from '../site/assets/js/product-analytics-core.mjs';

const config = normalizeAnalyticsConfig({
  enabled: true,
  host: 'https://eu.i.posthog.com/',
  projectKey: 'phc_public_test_token',
  releaseChannel: 'web-staging',
});
assert.deepEqual(config, {
  enabled: true,
  host: 'https://eu.i.posthog.com',
  projectKey: 'phc_public_test_token',
  releaseChannel: 'web-staging',
});
assert.deepEqual(normalizeAnalyticsConfig(config), config);
assert.equal(normalizeAnalyticsConfig({ enabled: false }), null);
assert.equal(normalizeAnalyticsConfig({
  enabled: true,
  host: 'http://eu.i.posthog.com',
  projectKey: 'phc_public_test_token',
  releaseChannel: 'web-staging',
}), null);
assert.equal(normalizeAnalyticsConfig({
  enabled: true,
  host: 'https://eu.i.posthog.com',
  projectKey: 'phx_personal_secret',
  releaseChannel: 'web-staging',
}), null);

const productHuntAttribution = attributionFromUrl(
  'https://plawie.app/?utm_source=ProductHunt&utm_medium=launch'
  + '&utm_campaign=producthunt_launch_2026&utm_term=private-search',
);
assert.deepEqual(productHuntAttribution, {
  source: 'producthunt',
  medium: 'launch',
  campaign: 'producthunt_launch_2026',
});
assert.equal(isProductHuntAttribution(productHuntAttribution), true);
assert.deepEqual(normalizeAttribution({
  source: 'untrusted-source-value',
  medium: 'untrusted-medium',
  campaign: 'untrusted-campaign',
}), {
  source: 'other',
  medium: 'referral',
  campaign: '',
});

assert.equal(
  classifyTrackedLink(
    'https://github.com/vmbbz/plawie/releases/download/v1/app.apk',
  ),
  'download_clicked',
);
assert.equal(
  classifyTrackedLink('https://github.com/vmbbz/plawie/releases/tag/v1'),
  'release_notes_opened',
);
assert.equal(
  classifyTrackedLink('https://malicious.example/vmbbz/plawie/releases/tag/v1'),
  null,
);
assert.equal(normalizeSurface('download_card'), 'download_card');
assert.equal(normalizeSurface('arbitrary-element-id'), 'unknown');

const payload = createCapturePayload({
  config,
  event: 'download_clicked',
  installationId: 'plawie-web-12345678-1234-1234-1234-123456789abc',
  sessionId: 'plawie-web-session-12345678-1234-1234-1234-123456789abc',
  eventId: 'plawie-web-event-12345678-1234-1234-1234-123456789abc',
  timestamp: '2026-08-16T12:00:00.000Z',
  attribution: productHuntAttribution,
  surface: 'hero',
});
assert.equal(payload.event, 'download_clicked');
assert.equal(payload.distinct_id.startsWith('plawie-web-'), true);
assert.equal(payload.properties.source, 'producthunt');
assert.equal(payload.properties.campaign, 'producthunt_launch_2026');
assert.equal(payload.properties.$process_person_profile, false);
assert.equal(payload.properties.$geoip_disable, true);
assert.equal(payload.properties.$session_id.startsWith('plawie-web-session-'), true);
const encodedPayload = JSON.stringify(payload);
for (const forbidden of [
  'private-search',
  'prompt',
  'transcript',
  'walletAddress',
  'referrer',
  'userAgent',
  'https://plawie.app/',
]) {
  assert.equal(encodedPayload.includes(forbidden), false);
}
assert.throws(() => createCapturePayload({
  config,
  event: 'arbitrary_event',
  installationId: 'plawie-web-12345678-1234-1234-1234-123456789abc',
  sessionId: 'plawie-web-session-12345678-1234-1234-1234-123456789abc',
  eventId: 'plawie-web-event-12345678-1234-1234-1234-123456789abc',
  timestamp: '2026-08-16T12:00:00.000Z',
  attribution: productHuntAttribution,
  surface: 'hero',
}), /Invalid product analytics capture input/);

console.log('Landing analytics contract: all checks passed');
