import assert from 'node:assert/strict';

import {
  postHogDashboardManifest,
  validatePostHogDashboardManifest,
} from './posthog_dashboard_manifest.mjs';

const counts = validatePostHogDashboardManifest();
assert.deepEqual(counts, { dashboards: 4, insights: 22 });

const dashboardByName = new Map(
  postHogDashboardManifest.map((dashboard) => [dashboard.name, dashboard]),
);
assert.equal(dashboardByName.get('Plawie — Acquisition — Staging')?.insights.length, 5);
assert.equal(dashboardByName.get('Plawie — Android Activation — Staging')?.insights.length, 9);
assert.equal(dashboardByName.get('Plawie — Voice and Gateway — Staging')?.insights.length, 6);
assert.equal(dashboardByName.get('Plawie — Retention — Staging')?.insights.length, 2);

const allInsights = postHogDashboardManifest.flatMap((dashboard) => dashboard.insights);
const activeNow = allInsights.find((insight) => insight.name === 'Active Android installations now (approx.)');
assert.equal(activeNow.query.source.dateRange.date_from, '-10m');
assert.equal(activeNow.query.source.trendsFilter.display, 'BoldNumber');

const dailyActive = allInsights.find((insight) => insight.name === 'Daily active Android installations');
assert.equal(dailyActive.query.source.series[0].event, 'app_foregrounded');
assert.equal(dailyActive.query.source.series[0].math, 'dau');

const retention = allInsights.find((insight) => insight.name === 'First-open Android retention');
assert.equal(retention.query.source.retentionFilter.targetEntity.id, 'app_first_opened');
assert.equal(retention.query.source.retentionFilter.returningEntity.id, 'app_foregrounded');
assert.equal(retention.query.source.retentionFilter.period, 'Day');

console.log('PostHog dashboard manifest: all checks passed');
