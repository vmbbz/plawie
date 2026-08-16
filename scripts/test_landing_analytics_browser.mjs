import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { pathToFileURL } from 'node:url';

class MemoryStorage {
  constructor() {
    this.values = new Map();
  }

  getItem(key) {
    return this.values.has(key) ? this.values.get(key) : null;
  }

  setItem(key, value) {
    this.values.set(key, String(value));
  }

  removeItem(key) {
    this.values.delete(key);
  }
}

class FakeElement {
  constructor(tagName = 'div') {
    this.tagName = tagName.toUpperCase();
    this.dataset = {};
    this.hidden = false;
    this.handlers = new Map();
    this.childrenBySelector = new Map();
    this.textContent = '';
    this.className = '';
  }

  addEventListener(type, handler) {
    this.handlers.set(type, handler);
  }

  setAttribute() {}

  focus() {
    this.focused = true;
  }

  querySelector(selector) {
    if (!this.childrenBySelector.has(selector)) {
      this.childrenBySelector.set(selector, new FakeElement('button'));
    }
    return this.childrenBySelector.get(selector);
  }

  closest(selector) {
    return selector === 'a[href]' && this.href ? this : null;
  }

  click() {
    this.handlers.get('click')?.({ target: this });
  }
}

const localStorage = new MemoryStorage();
const sessionStorage = new MemoryStorage();
const appended = [];
const documentHandlers = new Map();
const document = {
  body: {
    append(...elements) {
      appended.push(...elements);
    },
  },
  createElement(tagName) {
    return new FakeElement(tagName);
  },
  addEventListener(type, handler) {
    documentHandlers.set(type, handler);
  },
};
const navigator = { globalPrivacyControl: false };
const window = {
  __PLAWIE_PRODUCT_ANALYTICS__: {
    enabled: true,
    host: 'https://eu.i.posthog.com',
    projectKey: 'phc_public_browser_test',
    releaseChannel: 'web-staging',
  },
  crypto: webcrypto,
  location: {
    href: 'https://plawie.app/?utm_source=producthunt&utm_medium=launch'
      + '&utm_campaign=producthunt_launch_2026&utm_term=never-send-this',
    pathname: '/',
  },
  localStorage,
  sessionStorage,
};
const requests = [];

Object.assign(globalThis, {
  Element: FakeElement,
  document,
  fetch: async (url, options) => {
    requests.push({ url, options });
    return { ok: true };
  },
  window,
});
Object.defineProperty(globalThis, 'navigator', {
  configurable: true,
  value: navigator,
});

await import(
  `${pathToFileURL('site/assets/js/product-analytics.js').href}?browser-contract=1`
);

assert.equal(appended.length, 2);
const [, panel] = appended;
const acceptButton = panel.querySelector('[data-analytics-accept]');
const declineButton = panel.querySelector('[data-analytics-decline]');
assert.equal(panel.hidden, false);
assert.equal(requests.length, 0, 'no pre-consent request');
assert.equal(
  localStorage.getItem('plawie-site-analytics-installation-id-v1'),
  null,
  'no pre-consent analytics identity',
);

acceptButton.click();
await new Promise((resolve) => setImmediate(resolve));
assert.equal(localStorage.getItem('plawie-site-analytics-consent-v1'), 'granted');
assert.match(
  localStorage.getItem('plawie-site-analytics-installation-id-v1'),
  /^plawie-web-/,
);
assert.equal(requests.length, 2);
const captured = requests.map(({ url, options }) => ({
  url,
  body: JSON.parse(options.body),
}));
assert.deepEqual(
  captured.map(({ body }) => body.event).sort(),
  ['landing_viewed', 'product_hunt_campaign_seen'],
);
for (const request of captured) {
  assert.equal(request.url, 'https://eu.i.posthog.com/i/v0/e/');
  assert.equal(request.body.properties.$process_person_profile, false);
  assert.equal(request.body.properties.$geoip_disable, true);
  assert.equal(request.body.properties.source, 'producthunt');
  assert.equal(JSON.stringify(request.body).includes('never-send-this'), false);
}

const downloadLink = new FakeElement('a');
downloadLink.href = 'https://github.com/vmbbz/plawie/releases/download/v1/app.apk';
downloadLink.dataset.analyticsSurface = 'hero';
documentHandlers.get('click')({ target: downloadLink });
await new Promise((resolve) => setImmediate(resolve));
assert.deepEqual(
  requests.slice(2).map(({ options }) => JSON.parse(options.body).event).sort(),
  ['download_clicked', 'product_hunt_download_clicked'],
);

declineButton.click();
assert.equal(localStorage.getItem('plawie-site-analytics-consent-v1'), 'denied');
assert.equal(
  localStorage.getItem('plawie-site-analytics-installation-id-v1'),
  null,
);
documentHandlers.get('click')({ target: downloadLink });
await new Promise((resolve) => setImmediate(resolve));
assert.equal(requests.length, 4, 'opt-out stops new requests');

appended.length = 0;
navigator.globalPrivacyControl = true;
await import(
  `${pathToFileURL('site/assets/js/product-analytics.js').href}?browser-contract=2`
);
assert.equal(appended.length, 0, 'Global Privacy Control suppresses analytics UI');
assert.equal(requests.length, 4, 'Global Privacy Control suppresses analytics requests');

console.log('Landing analytics browser consent: all checks passed');
