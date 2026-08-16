import {
  attributionFromUrl,
  captureUriForConfig,
  classifyTrackedLink,
  createCapturePayload,
  isProductHuntAttribution,
  normalizeAnalyticsConfig,
  normalizeAttribution,
  normalizeSurface,
} from './product-analytics-core.mjs';

(() => {
  'use strict';

  const config = normalizeAnalyticsConfig(window.__PLAWIE_PRODUCT_ANALYTICS__);
  if (!config || navigator.globalPrivacyControl === true) return;

  const consentKey = 'plawie-site-analytics-consent-v1';
  const installationIdKey = 'plawie-site-analytics-installation-id-v1';
  const attributionKey = 'plawie-site-analytics-attribution-v1';
  const sessionIdKey = 'plawie-site-analytics-session-id-v1';
  const sessionEventsKey = 'plawie-site-analytics-session-events-v1';
  const validConsent = new Set(['granted', 'denied']);
  const availableStorage = (name) => {
    try {
      return window[name];
    } catch (_) {
      return null;
    }
  };
  const local = availableStorage('localStorage');
  const session = availableStorage('sessionStorage');

  const storageRead = (storage, key) => {
    if (!storage) return null;
    try {
      return storage.getItem(key);
    } catch (_) {
      return null;
    }
  };

  const storageWrite = (storage, key, value) => {
    if (!storage) return false;
    try {
      storage.setItem(key, value);
      return storage.getItem(key) === value;
    } catch (_) {
      return false;
    }
  };

  const storageRemove = (storage, key) => {
    if (!storage) return;
    try {
      storage.removeItem(key);
    } catch (_) {
      // Storage denial is treated as analytics denial; product flow continues.
    }
  };

  const randomId = (prefix) => {
    const webCrypto = window.crypto;
    if (!webCrypto) return null;
    if (typeof webCrypto.randomUUID === 'function') {
      return `${prefix}${webCrypto.randomUUID()}`;
    }
    if (typeof webCrypto.getRandomValues !== 'function') return null;
    const bytes = webCrypto.getRandomValues(new Uint8Array(16));
    return `${prefix}${[...bytes].map((value) => value.toString(16).padStart(2, '0')).join('')}`;
  };

  const readConsent = () => {
    const consent = storageRead(local, consentKey);
    return validConsent.has(consent) ? consent : 'undecided';
  };

  const clearAnalyticsState = () => {
    storageRemove(local, installationIdKey);
    storageRemove(session, attributionKey);
    storageRemove(session, sessionIdKey);
    storageRemove(session, sessionEventsKey);
  };

  const ensureIdentifier = (storage, key, prefix) => {
    const existing = storageRead(storage, key);
    if (typeof existing === 'string'
        && existing.startsWith(prefix)
        && /^[A-Za-z0-9-]{16,128}$/.test(existing)) {
      return existing;
    }
    const generated = randomId(prefix);
    return generated && storageWrite(storage, key, generated) ? generated : null;
  };

  const readAttribution = () => {
    const current = attributionFromUrl(window.location.href);
    if (current.source !== 'direct') return current;
    const stored = storageRead(session, attributionKey);
    if (!stored) return current;
    try {
      return normalizeAttribution(JSON.parse(stored));
    } catch (_) {
      return current;
    }
  };

  const rememberAttribution = (attribution) => {
    storageWrite(session, attributionKey, JSON.stringify(attribution));
  };

  const capture = async (event, surface, attribution = readAttribution()) => {
    if (readConsent() !== 'granted') return false;
    const installationId = ensureIdentifier(
      local,
      installationIdKey,
      'plawie-web-',
    );
    const sessionId = ensureIdentifier(
      session,
      sessionIdKey,
      'plawie-web-session-',
    );
    const eventId = randomId('plawie-web-event-');
    if (!installationId || !sessionId || !eventId) return false;

    let payload;
    try {
      payload = createCapturePayload({
        config,
        event,
        installationId,
        sessionId,
        eventId,
        timestamp: new Date(),
        attribution,
        surface,
      });
    } catch (_) {
      return false;
    }

    try {
      const response = await fetch(captureUriForConfig(config), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        credentials: 'omit',
        referrerPolicy: 'no-referrer',
        keepalive: true,
      });
      return response.ok;
    } catch (_) {
      return false;
    }
  };

  const captureSessionOnce = (event, surface, attribution) => {
    const stored = storageRead(session, sessionEventsKey);
    let sent = [];
    try {
      sent = stored ? JSON.parse(stored) : [];
    } catch (_) {
      sent = [];
    }
    if (!Array.isArray(sent) || sent.includes(event)) return;
    sent = [...sent.filter((value) => typeof value === 'string').slice(-15), event];
    if (!storageWrite(session, sessionEventsKey, JSON.stringify(sent))) return;
    void capture(event, surface, attribution);
  };

  const captureEntryEvents = () => {
    if (readConsent() !== 'granted') return;
    const attribution = readAttribution();
    rememberAttribution(attribution);
    if (window.location.pathname === '/' || window.location.pathname === '/index.html') {
      captureSessionOnce('landing_viewed', 'hero', attribution);
      if (isProductHuntAttribution(attribution)) {
        captureSessionOnce('product_hunt_campaign_seen', 'hero', attribution);
      }
    }
  };

  const choicesButton = document.createElement('button');
  choicesButton.type = 'button';
  choicesButton.className = 'privacy-choices-button';
  choicesButton.textContent = 'Privacy choices';

  const panel = document.createElement('aside');
  panel.className = 'analytics-consent';
  panel.hidden = true;
  panel.setAttribute('role', 'dialog');
  panel.setAttribute('aria-modal', 'false');
  panel.setAttribute('aria-labelledby', 'analytics-consent-title');
  panel.innerHTML = `
    <div>
      <p class="eyebrow">Optional analytics</p>
      <h2 id="analytics-consent-title">Help improve Plawie?</h2>
      <p data-analytics-consent-copy></p>
      <p class="analytics-consent-detail">We measure a short allowlist of page, download, campaign, and reliability events. No advertising profile, session replay, prompts, wallet data, or account is involved.</p>
      <a href="/privacy/#analytics">Read the privacy details</a>
    </div>
    <div class="analytics-consent-actions">
      <button class="button button-primary" type="button" data-analytics-accept>Share anonymous analytics</button>
      <button class="button button-ghost" type="button" data-analytics-decline>Keep analytics off</button>
    </div>`;

  const copy = panel.querySelector('[data-analytics-consent-copy]');
  const acceptButton = panel.querySelector('[data-analytics-accept]');
  const declineButton = panel.querySelector('[data-analytics-decline]');

  const openChoices = () => {
    const consent = readConsent();
    copy.textContent = consent === 'granted'
      ? 'Anonymous product analytics is currently on. You can turn it off and remove this browser’s analytics ID.'
      : 'Analytics is off unless you explicitly choose to share it.';
    acceptButton.textContent = consent === 'granted'
      ? 'Keep analytics on'
      : 'Share anonymous analytics';
    declineButton.textContent = consent === 'granted'
      ? 'Turn analytics off'
      : 'Keep analytics off';
    panel.hidden = false;
    acceptButton.focus();
  };

  choicesButton.addEventListener('click', openChoices);
  acceptButton.addEventListener('click', () => {
    if (!storageWrite(local, consentKey, 'granted')) {
      copy.textContent = 'Your browser could not save this choice, so analytics remains off.';
      return;
    }
    panel.hidden = true;
    captureEntryEvents();
  });
  declineButton.addEventListener('click', () => {
    clearAnalyticsState();
    storageWrite(local, consentKey, 'denied');
    panel.hidden = true;
  });

  document.body.append(choicesButton, panel);
  if (readConsent() === 'undecided') openChoices();
  else if (readConsent() === 'granted') captureEntryEvents();

  document.addEventListener('click', (event) => {
    const link = event.target instanceof Element
      ? event.target.closest('a[href]')
      : null;
    if (!link) return;
    const trackedEvent = classifyTrackedLink(link.href, window.location.href);
    if (!trackedEvent || readConsent() !== 'granted') return;
    const attribution = readAttribution();
    const surface = normalizeSurface(
      link.dataset.analyticsSurface
      || (window.location.pathname.startsWith('/support') ? 'support' : 'unknown'),
    );
    void capture(trackedEvent, surface, attribution);
    if (trackedEvent === 'download_clicked' && isProductHuntAttribution(attribution)) {
      void capture('product_hunt_download_clicked', surface, attribution);
    }
  });
})();
