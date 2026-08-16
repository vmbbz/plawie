import { randomUUID } from 'node:crypto';

import {
  captureUriForConfig,
  createCapturePayload,
  normalizeAnalyticsConfig,
} from '../site/assets/js/product-analytics-core.mjs';

const config = normalizeAnalyticsConfig({
  enabled: true,
  host: process.env.PLAWIE_POSTHOG_HOST ?? '',
  projectKey: process.env.PLAWIE_POSTHOG_PROJECT_KEY ?? '',
  releaseChannel: process.env.PLAWIE_SITE_RELEASE_CHANNEL ?? 'web-staging',
});
if (!config || config.releaseChannel !== 'web-staging') {
  throw new Error(
    'Staging verification requires a valid public PostHog project token, '
    + 'official ingest host, and PLAWIE_SITE_RELEASE_CHANNEL=web-staging.',
  );
}

const nonce = randomUUID();
const payload = createCapturePayload({
  config,
  event: 'landing_viewed',
  installationId: `plawie-web-${nonce}`,
  sessionId: `plawie-web-session-${randomUUID()}`,
  eventId: `plawie-web-event-${randomUUID()}`,
  timestamp: new Date(),
  attribution: { source: 'direct', medium: 'direct' },
  surface: 'unknown',
});

const response = await fetch(captureUriForConfig(config), {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(payload),
  credentials: 'omit',
  referrerPolicy: 'no-referrer',
  signal: AbortSignal.timeout(8000),
});
if (!response.ok) {
  throw new Error(`PostHog staging capture failed with HTTP ${response.status}.`);
}

console.log('PostHog staging capture accepted; inspect landing_viewed in Live events.');
