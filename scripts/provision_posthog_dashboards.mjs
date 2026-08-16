import {
  postHogDashboardManifest,
  validatePostHogDashboardManifest,
} from './posthog_dashboard_manifest.mjs';

const managedMarker = 'Managed by scripts/provision_posthog_dashboards.mjs.';
const checkOnly = process.argv.includes('--check');
const executeQueries = process.argv.includes('--execute-queries');

const apiKey = process.env.POSTHOG_PERSONAL_API_KEY?.trim();
const projectId = process.env.POSTHOG_PROJECT_ID?.trim() ?? '';
const apiHost = (process.env.POSTHOG_API_HOST?.trim() || 'https://eu.posthog.com').replace(/\/$/, '');

if (!apiKey) throw new Error('POSTHOG_PERSONAL_API_KEY is required.');
if (!/^\d+$/.test(projectId)) throw new Error('POSTHOG_PROJECT_ID must be numeric.');
if (!['https://eu.posthog.com', 'https://us.posthog.com'].includes(apiHost)) {
  throw new Error('POSTHOG_API_HOST must be an official PostHog EU or US private API origin.');
}

const manifestCounts = validatePostHogDashboardManifest();

async function request(path, { method = 'GET', body } = {}) {
  const response = await fetch(`${apiHost}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'Plawie-dashboard-provisioner',
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const text = await response.text();
  let payload = null;
  if (text) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = text;
    }
  }
  if (!response.ok) {
    const detail = typeof payload === 'string' ? payload : JSON.stringify(payload);
    throw new Error(`${method} ${path} failed (${response.status}): ${detail}`);
  }
  return payload;
}

async function listAll(path) {
  const results = [];
  let next = `${path}${path.includes('?') ? '&' : '?'}limit=500`;
  while (next) {
    const page = await request(next);
    results.push(...(page.results ?? []));
    if (!page.next) break;
    const nextUrl = new URL(page.next);
    if (nextUrl.origin !== apiHost) throw new Error('PostHog pagination left the configured API origin.');
    next = `${nextUrl.pathname}${nextUrl.search}`;
  }
  return results;
}

function managedDescription(description) {
  return `${managedMarker} ${description}`;
}

function canonicalJson(value) {
  if (Array.isArray(value)) return value.map(canonicalJson);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonicalJson(value[key])]),
    );
  }
  return value;
}

function findExactlyOne(items, name, type) {
  const matches = items.filter((item) => item.name === name && !item.deleted);
  if (matches.length > 1) throw new Error(`Multiple ${type} objects are named ${name}.`);
  return matches[0] ?? null;
}

await request('/api/users/@me/');

const dashboardPath = `/api/projects/${projectId}/dashboards/`;
const insightPath = `/api/projects/${projectId}/insights/`;
const dashboards = await listAll(dashboardPath);
const insights = await listAll(`${insightPath}?include_dashboards=true`);

let createdDashboards = 0;
let updatedDashboards = 0;
let createdInsights = 0;
let updatedInsights = 0;
const provisioned = [];

for (const dashboardSpec of postHogDashboardManifest) {
  let dashboard = findExactlyOne(dashboards, dashboardSpec.name, 'dashboard');
  const dashboardBody = {
    name: dashboardSpec.name,
    description: managedDescription(dashboardSpec.description),
    pinned: true,
  };

  if (!dashboard) {
    if (checkOnly) throw new Error(`Missing managed dashboard: ${dashboardSpec.name}`);
    dashboard = await request(dashboardPath, { method: 'POST', body: dashboardBody });
    dashboards.push(dashboard);
    createdDashboards++;
  } else {
    if (!dashboard.description?.startsWith(managedMarker)) {
      throw new Error(`Refusing to overwrite unmanaged dashboard: ${dashboardSpec.name}`);
    }
    const dashboardChanged = dashboard.description !== dashboardBody.description || dashboard.pinned !== true;
    if (dashboardChanged) {
      if (checkOnly) throw new Error(`Managed dashboard drift: ${dashboardSpec.name}`);
      dashboard = await request(`${dashboardPath}${dashboard.id}/`, {
        method: 'PATCH',
        body: dashboardBody,
      });
      updatedDashboards++;
    }
  }

  const dashboardInsightIds = [];
  for (const insightSpec of dashboardSpec.insights) {
    let insight = findExactlyOne(insights, insightSpec.name, 'insight');
    const insightBody = {
      name: insightSpec.name,
      description: managedDescription(insightSpec.description),
      query: insightSpec.query,
      dashboards: [dashboard.id],
      tags: ['plawie', 'staging', 'managed'],
    };

    if (!insight) {
      if (checkOnly) throw new Error(`Missing managed insight: ${insightSpec.name}`);
      insight = await request(insightPath, { method: 'POST', body: insightBody });
      insights.push(insight);
      createdInsights++;
    } else {
      if (!insight.description?.startsWith(managedMarker)) {
        throw new Error(`Refusing to overwrite unmanaged insight: ${insightSpec.name}`);
      }
      const currentDashboardIds = (insight.dashboards ?? []).map(Number).sort((a, b) => a - b);
      const expectedDashboardIds = [Number(dashboard.id)];
      const insightChanged =
        insight.description !== insightBody.description ||
        JSON.stringify(canonicalJson(insight.query)) !==
          JSON.stringify(canonicalJson(insightBody.query)) ||
        JSON.stringify(currentDashboardIds) !== JSON.stringify(expectedDashboardIds);
      if (insightChanged) {
        if (checkOnly) throw new Error(`Managed insight drift: ${insightSpec.name}`);
        insight = await request(`${insightPath}${insight.id}/`, {
          method: 'PATCH',
          body: insightBody,
        });
        updatedInsights++;
      }
    }

    if (executeQueries) {
      await request(`/api/projects/${projectId}/query/`, {
        method: 'POST',
        body: { query: insightSpec.query.source },
      });
    }
    dashboardInsightIds.push(Number(insight.id));
  }

  const verifiedDashboard = await request(`${dashboardPath}${dashboard.id}/`);
  const attachedInsightIds = new Set(
    (verifiedDashboard.tiles ?? [])
      .map((tile) => Number(tile.insight?.id))
      .filter(Number.isFinite),
  );
  const missingIds = dashboardInsightIds.filter((id) => !attachedInsightIds.has(id));
  if (missingIds.length > 0) {
    throw new Error(`Dashboard ${dashboardSpec.name} is missing ${missingIds.length} managed insight tile(s).`);
  }
  provisioned.push({
    id: dashboard.id,
    name: dashboard.name,
    insightCount: dashboardInsightIds.length,
  });
}

console.log(JSON.stringify({
  mode: checkOnly ? 'check' : 'provision',
  executeQueries,
  expected: manifestCounts,
  createdDashboards,
  updatedDashboards,
  createdInsights,
  updatedInsights,
  dashboards: provisioned,
}, null, 2));
