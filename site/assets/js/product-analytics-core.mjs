const supportedHosts = new Set([
  'https://eu.i.posthog.com',
  'https://us.i.posthog.com',
]);

const supportedEvents = new Set([
  'landing_viewed',
  'download_clicked',
  'release_notes_opened',
  'product_hunt_campaign_seen',
  'product_hunt_download_clicked',
]);

const supportedSurfaces = new Set([
  'hero',
  'download_card',
  'footer',
  'support',
  'privacy',
  'unknown',
]);

const sourceAliases = new Map([
  ['producthunt', 'producthunt'],
  ['product_hunt', 'producthunt'],
  ['product-hunt', 'producthunt'],
  ['x', 'x'],
  ['twitter', 'x'],
  ['github', 'github'],
  ['organic', 'organic'],
  ['direct', 'direct'],
]);

const supportedMediums = new Set([
  'launch',
  'social',
  'referral',
  'organic',
  'direct',
]);

const supportedCampaigns = new Set([
  'producthunt_launch_2026',
]);

const bounded = (value, maximum) => {
  if (typeof value !== 'string') return '';
  const normalized = value.trim().toLowerCase();
  return normalized.length <= maximum ? normalized : '';
};

export const normalizeAnalyticsConfig = (rawConfig) => {
  if (!rawConfig || rawConfig.enabled !== true) return null;
  const host = typeof rawConfig.host === 'string'
    ? rawConfig.host.trim().replace(/\/+$/, '')
    : '';
  const projectKey = typeof rawConfig.projectKey === 'string'
    ? rawConfig.projectKey.trim()
    : '';
  const releaseChannel = typeof rawConfig.releaseChannel === 'string'
    ? rawConfig.releaseChannel.trim()
    : '';

  if (!supportedHosts.has(host)
      || !/^phc_[A-Za-z0-9_-]{4,196}$/.test(projectKey)
      || !/^web-[A-Za-z0-9._-]{1,28}$/.test(releaseChannel)) {
    return null;
  }

  return Object.freeze({
    enabled: true,
    host,
    projectKey,
    releaseChannel,
  });
};

export const captureUriForConfig = (config) => `${config.host}/i/v0/e/`;

export const normalizeAttribution = (rawAttribution = {}) => {
  const rawSource = bounded(rawAttribution.source, 32);
  const source = sourceAliases.get(rawSource) ?? (rawSource ? 'other' : 'direct');
  const rawMedium = bounded(rawAttribution.medium, 32);
  const defaultMedium = source === 'producthunt'
    ? 'launch'
    : source === 'direct'
      ? 'direct'
      : 'referral';
  const medium = supportedMediums.has(rawMedium) ? rawMedium : defaultMedium;
  const rawCampaign = bounded(rawAttribution.campaign, 64);
  const campaign = supportedCampaigns.has(rawCampaign)
    ? rawCampaign
    : source === 'producthunt'
      ? 'producthunt_launch_2026'
      : '';

  return Object.freeze({ source, medium, campaign });
};

export const attributionFromUrl = (value) => {
  let url;
  try {
    url = value instanceof URL ? value : new URL(value);
  } catch (_) {
    return normalizeAttribution();
  }
  return normalizeAttribution({
    source: url.searchParams.get('utm_source') ?? '',
    medium: url.searchParams.get('utm_medium') ?? '',
    campaign: url.searchParams.get('utm_campaign') ?? '',
  });
};

export const isProductHuntAttribution = (attribution) => (
  normalizeAttribution(attribution).source === 'producthunt'
);

export const normalizeSurface = (value) => {
  const normalized = bounded(value, 32);
  return supportedSurfaces.has(normalized) ? normalized : 'unknown';
};

export const classifyTrackedLink = (href, baseUrl = 'https://plawie.app/') => {
  let url;
  try {
    url = new URL(href, baseUrl);
  } catch (_) {
    return null;
  }
  if (url.protocol !== 'https:' || url.hostname !== 'github.com') return null;
  if (url.pathname.startsWith('/vmbbz/plawie/releases/download/')) {
    return 'download_clicked';
  }
  if (url.pathname.startsWith('/vmbbz/plawie/releases/tag/')) {
    return 'release_notes_opened';
  }
  return null;
};

const validIdentifier = (value, prefix) => (
  typeof value === 'string'
  && value.startsWith(prefix)
  && /^[A-Za-z0-9-]{16,128}$/.test(value)
);

export const createCapturePayload = ({
  config,
  event,
  installationId,
  sessionId,
  eventId,
  timestamp,
  attribution,
  surface,
}) => {
  if (!config
      || !supportedEvents.has(event)
      || !validIdentifier(installationId, 'plawie-web-')
      || !validIdentifier(sessionId, 'plawie-web-session-')
      || !validIdentifier(eventId, 'plawie-web-event-')) {
    throw new TypeError('Invalid product analytics capture input.');
  }
  const occurredAt = new Date(timestamp);
  if (Number.isNaN(occurredAt.getTime())) {
    throw new TypeError('Invalid product analytics timestamp.');
  }
  const safeAttribution = normalizeAttribution(attribution);

  return {
    api_key: config.projectKey,
    event,
    distinct_id: installationId,
    timestamp: occurredAt.toISOString(),
    properties: {
      schemaVersion: 1,
      platform: 'web',
      releaseChannel: config.releaseChannel,
      source: safeAttribution.source,
      medium: safeAttribution.medium,
      ...(safeAttribution.campaign ? { campaign: safeAttribution.campaign } : {}),
      surface: normalizeSurface(surface),
      plawieEventId: eventId,
      '$session_id': sessionId,
      '$process_person_profile': false,
      '$geoip_disable': true,
    },
  };
};
