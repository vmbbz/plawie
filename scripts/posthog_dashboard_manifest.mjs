const WEB_CHANNEL = 'web-staging';
const ANDROID_CHANNEL = 'android-staging';

const releaseChannelFilter = (releaseChannel) => ({
  key: 'releaseChannel',
  value: [releaseChannel],
  operator: 'exact',
  type: 'event',
});

const eventNode = (event, { unique = false, label } = {}) => ({
  kind: 'EventsNode',
  event,
  name: event,
  ...(label ? { custom_name: label } : {}),
  ...(unique ? { math: 'dau' } : {}),
});

const trendsQuery = ({
  events,
  releaseChannel,
  interval = 'day',
  dateFrom = '-30d',
  breakdown,
  display = 'ActionsLineGraph',
  formula,
  axisPostfix,
}) => ({
  kind: 'InsightVizNode',
  source: {
    kind: 'TrendsQuery',
    series: events,
    version: 4,
    interval,
    dateRange: { date_from: dateFrom, explicitDate: false },
    properties: [releaseChannelFilter(releaseChannel)],
    trendsFilter: {
      display,
      showLegend: events.length > 1 || Boolean(breakdown),
      yAxisScaleType: 'linear',
      showValuesOnSeries: display === 'BoldNumber',
      smoothingIntervals: 1,
      showPercentStackView: false,
      aggregationAxisFormat: 'numeric',
      showAlertThresholdLines: false,
      ...(formula ? { formula } : {}),
      ...(axisPostfix ? { aggregationAxisPostfix: axisPostfix } : {}),
    },
    breakdownFilter: {
      breakdown_type: 'event',
      ...(breakdown ? { breakdown } : {}),
    },
    filterTestAccounts: false,
  },
});

const funnelQuery = ({
  events,
  releaseChannel,
  windowDays,
  visualization = 'steps',
}) => ({
  kind: 'InsightVizNode',
  source: {
    kind: 'FunnelsQuery',
    series: events.map((event) => eventNode(event)),
    version: 2,
    interval: 'day',
    dateRange: { date_from: '-30d', explicitDate: false },
    properties: [releaseChannelFilter(releaseChannel)],
    funnelsFilter: {
      layout: 'horizontal',
      exclusions: [],
      funnelVizType: visualization,
      funnelOrderType: 'ordered',
      funnelStepReference: 'total',
      funnelWindowInterval: windowDays,
      funnelWindowIntervalUnit: 'day',
      breakdownAttributionType: 'first_touch',
    },
    breakdownFilter: { breakdown_type: 'event' },
    filterTestAccounts: false,
  },
});

const retentionQuery = ({ startEvent, returnEvent }) => ({
  kind: 'InsightVizNode',
  source: {
    kind: 'RetentionQuery',
    version: 2,
    dateRange: { date_from: '-90d', explicitDate: false },
    properties: [releaseChannelFilter(ANDROID_CHANNEL)],
    retentionFilter: {
      period: 'Day',
      targetEntity: { id: startEvent, type: 'events' },
      retentionType: 'retention_first_time',
      totalIntervals: 31,
      returningEntity: { id: returnEvent, type: 'events' },
    },
    filterTestAccounts: false,
  },
});

const acquisitionInsights = [
  {
    name: 'Product Hunt campaign browser installations',
    description: 'Unique consented browser installations that reached the Product Hunt campaign landing surface.',
    query: trendsQuery({
      events: [eventNode('product_hunt_campaign_seen', { unique: true })],
      releaseChannel: WEB_CHANNEL,
    }),
  },
  {
    name: 'Product Hunt download browser installations',
    description: 'Unique consented browser installations that clicked the Product Hunt APK download.',
    query: trendsQuery({
      events: [eventNode('product_hunt_download_clicked', { unique: true })],
      releaseChannel: WEB_CHANNEL,
    }),
  },
  {
    name: 'Product Hunt landing to APK click',
    description: 'Same-browser Product Hunt campaign-to-download conversion; it does not join website and Android identities.',
    query: funnelQuery({
      events: ['product_hunt_campaign_seen', 'product_hunt_download_clicked'],
      releaseChannel: WEB_CHANNEL,
      windowDays: 1,
    }),
  },
  {
    name: 'All APK download browser installations by surface',
    description: 'Unique consented download-clicking browser installations broken down by the bounded site surface.',
    query: trendsQuery({
      events: [eventNode('download_clicked', { unique: true })],
      releaseChannel: WEB_CHANNEL,
      breakdown: 'surface',
    }),
  },
  {
    name: 'Release-note browser installations by source',
    description: 'Unique consented release-note visitors broken down by the bounded source dimension.',
    query: trendsQuery({
      events: [eventNode('release_notes_opened', { unique: true })],
      releaseChannel: WEB_CHANNEL,
      breakdown: 'source',
    }),
  },
];

const activationInsights = [
  {
    name: 'Daily active Android installations',
    description: 'Unique consented Android installations with a visible foreground or PiP session, grouped daily.',
    query: trendsQuery({
      events: [eventNode('app_foregrounded', { unique: true })],
      releaseChannel: ANDROID_CHANNEL,
    }),
  },
  {
    name: 'Weekly active Android installations',
    description: 'Unique consented Android installations with a visible foreground or PiP session, grouped weekly.',
    query: trendsQuery({
      events: [eventNode('app_foregrounded', { unique: true })],
      releaseChannel: ANDROID_CHANNEL,
      interval: 'week',
      dateFrom: '-90d',
    }),
  },
  {
    name: 'Active Android installations now (approx.)',
    description: 'Unique consented installations with a visible-use heartbeat in the last ten minutes; approximate, not exact presence.',
    query: trendsQuery({
      events: [eventNode('app_active_heartbeat', { unique: true })],
      releaseChannel: ANDROID_CHANNEL,
      interval: 'hour',
      dateFrom: '-10m',
      display: 'BoldNumber',
    }),
  },
  {
    name: 'Measured first opens',
    description: 'First measurable consented app opens by anonymous Android installation.',
    query: trendsQuery({
      events: [eventNode('app_first_opened', { unique: true })],
      releaseChannel: ANDROID_CHANNEL,
    }),
  },
  {
    name: 'First-open to first value',
    description: 'Ordered seven-day activation funnel from measured first open through the first successful agent turn.',
    query: funnelQuery({
      events: [
        'app_first_opened',
        'onboarding_completed',
        'gateway_ready',
        'first_agent_turn_completed',
      ],
      releaseChannel: ANDROID_CHANNEL,
      windowDays: 7,
    }),
  },
  {
    name: 'Time to first value',
    description: 'Elapsed time through the same ordered seven-day activation funnel.',
    query: funnelQuery({
      events: [
        'app_first_opened',
        'onboarding_completed',
        'gateway_ready',
        'first_agent_turn_completed',
      ],
      releaseChannel: ANDROID_CHANNEL,
      windowDays: 7,
      visualization: 'time_to_convert',
    }),
  },
  {
    name: 'Successful turns by runtime lane',
    description: 'Successful agent-turn count broken down by the bounded local or Gateway runtime lane.',
    query: trendsQuery({
      events: [eventNode('agent_turn_completed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'lane',
    }),
  },
  {
    name: 'Successful turns by provider',
    description: 'Successful agent-turn count broken down by the bounded provider catalog identifier.',
    query: trendsQuery({
      events: [eventNode('agent_turn_completed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'providerId',
    }),
  },
  {
    name: 'Successful turns by input type',
    description: 'Successful agent-turn count broken down by the bounded text, image, or video input mode.',
    query: trendsQuery({
      events: [eventNode('agent_turn_completed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'mode',
    }),
  },
];

const voiceAndGatewayInsights = [
  {
    name: 'Voice transcription success rate',
    description: 'Successful voice turns divided by successful plus failed transcriptions; no denominator means no evidence.',
    query: trendsQuery({
      events: [
        eventNode('voice_turn_completed', { label: 'A' }),
        eventNode('voice_transcription_failed', { label: 'B' }),
      ],
      releaseChannel: ANDROID_CHANNEL,
      formula: '100 * A / (A + B)',
      axisPostfix: '%',
    }),
  },
  {
    name: 'Voice outcomes by mode',
    description: 'Successful and failed voice-turn counts broken down by manual or continuous mode.',
    query: trendsQuery({
      events: [eventNode('voice_turn_completed'), eventNode('voice_transcription_failed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'mode',
    }),
  },
  {
    name: 'Voice outcomes by surface',
    description: 'Successful and failed voice-turn counts broken down by chat or PiP surface.',
    query: trendsQuery({
      events: [eventNode('voice_turn_completed'), eventNode('voice_transcription_failed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'surface',
    }),
  },
  {
    name: 'Voice failures by category',
    description: 'Voice transcription failure count broken down by the bounded error category.',
    query: trendsQuery({
      events: [eventNode('voice_transcription_failed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'errorCode',
    }),
  },
  {
    name: 'Gateway state transitions',
    description: 'Gateway ready and failure transitions broken down by native Gateway or explicit PRoot rollback mode.',
    query: trendsQuery({
      events: [eventNode('gateway_ready'), eventNode('gateway_failed')],
      releaseChannel: ANDROID_CHANNEL,
      breakdown: 'mode',
    }),
  },
  {
    name: 'TTS failures per 100 turns',
    description: 'Bounded TTS incidents per one hundred successful agent turns; no denominator means no evidence.',
    query: trendsQuery({
      events: [
        eventNode('tts_failed', { label: 'A' }),
        eventNode('agent_turn_completed', { label: 'B' }),
      ],
      releaseChannel: ANDROID_CHANNEL,
      formula: '100 * A / B',
      axisPostfix: '%',
    }),
  },
];

const retentionInsights = [
  {
    name: 'First-open Android retention',
    description: 'Daily D1-D30 return to visible app use after the first measurable consented open.',
    query: retentionQuery({
      startEvent: 'app_first_opened',
      returnEvent: 'app_foregrounded',
    }),
  },
  {
    name: 'Activated installation retention',
    description: 'Daily return to successful agent use after an installation reaches its first successful turn.',
    query: retentionQuery({
      startEvent: 'first_agent_turn_completed',
      returnEvent: 'agent_turn_completed',
    }),
  },
];

export const postHogDashboardManifest = [
  {
    name: 'Plawie — Acquisition — Staging',
    description: 'Consented anonymous website acquisition signals. Website and Android identities are intentionally not joined.',
    insights: acquisitionInsights,
  },
  {
    name: 'Plawie — Android Activation — Staging',
    description: 'Consented active Android installations, first value, and successful agent-turn usage.',
    insights: activationInsights,
  },
  {
    name: 'Plawie — Voice and Gateway — Staging',
    description: 'Bounded reliability and usage outcomes for voice, TTS, and Gateway runtime transitions.',
    insights: voiceAndGatewayInsights,
  },
  {
    name: 'Plawie — Retention — Staging',
    description: 'Anonymous installation retention after first open and first successful agent value.',
    insights: retentionInsights,
  },
];

export function validatePostHogDashboardManifest(manifest = postHogDashboardManifest) {
  const dashboardNames = new Set();
  const insightNames = new Set();
  for (const dashboard of manifest) {
    if (!dashboard.name || dashboardNames.has(dashboard.name)) {
      throw new Error(`Invalid or duplicate dashboard name: ${dashboard.name}`);
    }
    dashboardNames.add(dashboard.name);
    if (!Array.isArray(dashboard.insights) || dashboard.insights.length === 0) {
      throw new Error(`Dashboard has no insights: ${dashboard.name}`);
    }
    for (const insight of dashboard.insights) {
      if (!insight.name || insightNames.has(insight.name)) {
        throw new Error(`Invalid or duplicate insight name: ${insight.name}`);
      }
      insightNames.add(insight.name);
      if (insight.query?.kind !== 'InsightVizNode' || !insight.query.source?.kind) {
        throw new Error(`Invalid insight query: ${insight.name}`);
      }
      const filters = insight.query.source.properties ?? [];
      const releaseFilter = filters.find((filter) => filter.key === 'releaseChannel');
      if (!releaseFilter || releaseFilter.operator !== 'exact' || releaseFilter.type !== 'event') {
        throw new Error(`Missing release-channel isolation: ${insight.name}`);
      }
      const forbiddenKeys = new Set([
        'prompt',
        'transcript',
        'walletAddress',
        'apiKey',
        'url',
      ]);
      const stack = [insight.query];
      while (stack.length > 0) {
        const value = stack.pop();
        if (!value || typeof value !== 'object') continue;
        for (const [key, child] of Object.entries(value)) {
          if (forbiddenKeys.has(key)) {
            throw new Error(`Forbidden analytics field ${key}: ${insight.name}`);
          }
          stack.push(child);
        }
      }
    }
  }
  return {
    dashboards: dashboardNames.size,
    insights: insightNames.size,
  };
}
