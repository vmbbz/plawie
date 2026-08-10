(() => {
  'use strict';

  const root = document.documentElement;
  root.classList.remove('no-js');
  root.classList.add('js');

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  const motionStorageKey = 'plawie-motion-preference';
  const motionPreferenceControls = [...document.querySelectorAll('[data-motion-select]')];
  const validMotionPreferences = new Set(['system', 'full', 'reduced']);
  const readMotionPreference = () => {
    try {
      const stored = window.localStorage.getItem(motionStorageKey);
      return validMotionPreferences.has(stored) ? stored : 'system';
    } catch (_) {
      return 'system';
    }
  };
  let motionPreference = readMotionPreference();
  const motionAllowed = () => motionPreference === 'full'
    || (motionPreference === 'system' && !reduceMotion.matches);
  const syncMotionState = () => {
    root.dataset.motionPreference = motionPreference;
    root.dataset.motion = motionAllowed() ? 'full' : 'reduced';
    motionPreferenceControls.forEach((control) => { control.value = motionPreference; });
  };
  syncMotionState();

  motionPreferenceControls.forEach((control) => {
    control.addEventListener('change', () => {
      const nextPreference = control.value;
      if (!validMotionPreferences.has(nextPreference) || nextPreference === motionPreference) return;
      try {
        window.localStorage.setItem(motionStorageKey, nextPreference);
      } catch (_) {
        // The current page can still honor the choice when storage is unavailable.
      }
      motionPreference = nextPreference;
      syncMotionState();
      window.location.reload();
    });
  });
  const header = document.querySelector('[data-header]');
  const menuButton = document.querySelector('[data-menu-button]');
  const mobileNav = document.querySelector('[data-mobile-nav]');
  const productTabs = [...document.querySelectorAll('[role="tab"][data-demo-target]')];
  const allDemoControls = [...document.querySelectorAll('[data-demo-target]')];
  const panels = [...document.querySelectorAll('[data-demo-panel]')];
  const demoStage = document.querySelector('.hero-stage');
  const demoSubtitle = document.querySelector('[data-demo-subtitle]');

  const demoMeta = {
    chat: 'OPENROUTER · NATIVE HUB',
    skills: 'CAPABILITY CONTROL',
    gateway: 'ANDROID · NATIVE OWNER',
    wallet: 'BASE · HUMAN APPROVAL',
  };

  const setMenu = (open) => {
    if (!menuButton || !mobileNav) return;
    menuButton.setAttribute('aria-expanded', String(open));
    menuButton.querySelector('.sr-only').textContent = open ? 'Close menu' : 'Open menu';
    mobileNav.hidden = !open;
  };

  menuButton?.addEventListener('click', () => {
    setMenu(menuButton.getAttribute('aria-expanded') !== 'true');
  });

  mobileNav?.addEventListener('click', (event) => {
    if (event.target.closest('a')) setMenu(false);
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') setMenu(false);
  });

  const updateHeader = () => header?.classList.toggle('is-scrolled', window.scrollY > 18);
  updateHeader();
  window.addEventListener('scroll', updateHeader, { passive: true });

  const setDemo = (name, options = {}) => {
    if (!demoMeta[name]) return;
    document.body.dataset.demo = name;
    if (demoSubtitle) demoSubtitle.textContent = demoMeta[name];

    panels.forEach((panel) => {
      const selected = panel.dataset.demoPanel === name;
      if (selected) {
        panel.hidden = false;
        requestAnimationFrame(() => panel.classList.add('is-active'));
      } else {
        panel.classList.remove('is-active');
        window.setTimeout(() => {
          if (document.body.dataset.demo !== panel.dataset.demoPanel) panel.hidden = true;
        }, 290);
      }
    });

    allDemoControls.forEach((control) => {
      const selected = control.dataset.demoTarget === name;
      control.classList.toggle('is-active', selected);
      if (control.getAttribute('role') === 'tab') {
        control.setAttribute('aria-selected', String(selected));
        control.tabIndex = selected ? 0 : -1;
      }
    });

    document.dispatchEvent(new CustomEvent('plawie:demochange', { detail: { name } }));

    if (options.focusPhone && demoStage) {
      const block = window.innerWidth < 760 ? 'center' : 'center';
      demoStage.scrollIntoView({ behavior: motionAllowed() ? 'smooth' : 'auto', block });
    }
  };

  allDemoControls.forEach((control) => {
    control.addEventListener('click', () => {
      setDemo(control.dataset.demoTarget, { focusPhone: control.getAttribute('role') === 'tab' });
    });
  });

  productTabs.forEach((tab, index) => {
    tab.addEventListener('keydown', (event) => {
      let nextIndex = index;
      if (event.key === 'ArrowRight' || event.key === 'ArrowDown') nextIndex = (index + 1) % productTabs.length;
      else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') nextIndex = (index - 1 + productTabs.length) % productTabs.length;
      else if (event.key === 'Home') nextIndex = 0;
      else if (event.key === 'End') nextIndex = productTabs.length - 1;
      else return;
      event.preventDefault();
      const next = productTabs[nextIndex];
      setDemo(next.dataset.demoTarget, { focusPhone: false });
      next.focus();
    });
  });

  const toolProposal = document.querySelector('[data-tool-proposal]');
  const toolButton = document.querySelector('[data-tool-approve]');
  const toolCopy = document.querySelector('[data-tool-copy]');
  toolButton?.addEventListener('click', () => {
    const complete = toolProposal?.classList.toggle('is-complete');
    if (toolCopy) toolCopy.textContent = complete ? 'Preview complete · 3 results' : '3 read-only steps ready';
    toolButton.textContent = complete ? 'Reset preview' : 'Run preview';
  });

  const gatewayButton = document.querySelector('[data-gateway-toggle]');
  const logList = document.querySelector('[data-log-list]');
  let gatewayRunning = true;
  let logSequence = 0;
  const logMessages = [
    ['✓', 'tool catalog synchronized', 'log-ok'],
    ['→', 'health event published', 'log-info'],
    ['✓', 'dependency receipts loaded', 'log-ok'],
    ['↻', 'native lane remains ready', 'log-info'],
  ];

  gatewayButton?.addEventListener('click', () => {
    gatewayRunning = !gatewayRunning;
    gatewayButton.textContent = gatewayRunning ? 'Pause preview' : 'Resume preview';
  });

  window.setInterval(() => {
    if (!motionAllowed() || !gatewayRunning || document.body.dataset.demo !== 'gateway' || !logList) return;
    const [symbol, message, style] = logMessages[logSequence % logMessages.length];
    const row = document.createElement('li');
    const now = new Date();
    row.innerHTML = `<time>${now.toLocaleTimeString([], { hour12: false })}</time><span class="${style}">${symbol}</span> ${message}`;
    logList.append(row);
    while (logList.children.length > 7) logList.firstElementChild?.remove();
    logSequence += 1;
  }, 3200);

  const networkButton = document.querySelector('[data-network-toggle]');
  const networkLabel = document.querySelector('.wallet-network > span');
  networkButton?.addEventListener('click', () => {
    const robinhood = networkLabel?.textContent.trim() === 'BASE';
    if (networkLabel) networkLabel.innerHTML = `<i></i> ${robinhood ? 'ROBINHOOD' : 'BASE'}`;
    networkButton.textContent = robinhood ? 'Use Base' : 'Switch network';
  });

  const paymentDialog = document.querySelector('[data-payment-dialog]');
  const paymentReview = document.querySelector('[data-payment-review]');
  const paymentConfirm = document.querySelector('[data-payment-confirm]');
  const paymentState = document.querySelector('[data-payment-state]');

  paymentReview?.addEventListener('click', () => {
    if (typeof paymentDialog?.showModal === 'function') paymentDialog.showModal();
  });

  paymentConfirm?.addEventListener('click', () => {
    if (paymentState) paymentState.textContent = 'Preview approved · nothing was signed or sent.';
    paymentReview.textContent = 'Review again';
  });

  const revealItems = [...document.querySelectorAll('.reveal')];
  const revealProfiles = [
    ['.hero-copy, .setup-copy', 'left'],
    ['.hero-brand-stage, .hero-stage.reveal, .launch-card', 'scale'],
    ['.product-control-rail', 'right'],
    ['.section-heading', 'heading'],
    ['.bento, .truth-callout, .faq-list', 'lift'],
  ];
  revealProfiles.forEach(([selector, profile]) => {
    document.querySelectorAll(selector).forEach((item) => {
      if (item.classList.contains('reveal')) item.dataset.revealProfile = profile;
    });
  });

  const motionGroups = [
    ['.hero-proof', ':scope > div'],
    ['.product-control-rail', '.control-rail-heading, .demo-selector, .demo-disclaimer'],
    ['.architecture-map', ':scope > .architecture-node, :scope > .architecture-link, :scope > .architecture-branch'],
    ['.setup-timeline', ':scope > li'],
    ['.safety-card', '.safety-copy, .safety-rules article'],
    ['.launch-card', ':scope > *'],
    ['.faq-list', ':scope > details'],
  ];
  motionGroups.forEach(([groupSelector, itemSelector]) => {
    document.querySelectorAll(groupSelector).forEach((group) => {
      if (!group.classList.contains('reveal')) return;
      group.dataset.revealGroup = '';
      group.querySelectorAll(itemSelector).forEach((item, index) => {
        item.dataset.motionItem = '';
        item.style.setProperty('--motion-delay', `${110 + index * 82}ms`);
      });
    });
  });

  if ('IntersectionObserver' in window && motionAllowed()) {
    const observer = new IntersectionObserver((entries, revealObserver) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        revealObserver.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -10% 0px', threshold: .12 });
    revealItems.forEach((item) => observer.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add('is-visible'));
  }

  const motionSections = [
    document.querySelector('.hero'),
    ...document.querySelectorAll('main > .section'),
  ].filter(Boolean);
  motionSections.forEach((section) => { section.dataset.motionSection = ''; });

  if ('IntersectionObserver' in window) {
    const sectionObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        entry.target.classList.toggle('is-in-view', entry.isIntersecting);
      });
    }, { rootMargin: '12% 0px 12% 0px', threshold: .01 });
    motionSections.forEach((section) => sectionObserver.observe(section));
  } else {
    motionSections.forEach((section) => section.classList.add('is-in-view'));
  }

  const navigationLinks = [...document.querySelectorAll(
    '.desktop-nav a[href^="#"], .mobile-nav a[href^="#"]',
  )];
  const navigationSections = navigationLinks
    .map((link) => document.querySelector(link.getAttribute('href')))
    .filter((section, index, sections) => section && sections.indexOf(section) === index);
  let scrollFrame = 0;

  const updateScrollState = () => {
    scrollFrame = 0;
    const scrollRange = Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
    const pageProgress = Math.min(1, Math.max(0, window.scrollY / scrollRange));
    const sectionBounds = new Map(motionSections.map((section) => [
      section,
      section.getBoundingClientRect(),
    ]));
    const sectionSignals = motionSections.map((section) => {
      const bounds = sectionBounds.get(section);
      const progress = Math.min(
        1,
        Math.max(0, (window.innerHeight - bounds.top) / (window.innerHeight + bounds.height)),
      );
      const signal = motionAllowed() ? Math.sin(progress * Math.PI) : 0;
      return [section, Math.max(0, signal).toFixed(3)];
    });

    const marker = Math.min(220, window.innerHeight * .3);
    let activeId = '';
    navigationSections.forEach((section) => {
      const bounds = sectionBounds.get(section);
      if (bounds.top <= marker && bounds.bottom > marker) activeId = section.id;
    });

    root.style.setProperty('--scroll-progress', pageProgress.toFixed(4));
    root.style.setProperty(
      '--atmosphere-shift',
      `${motionAllowed() ? Math.min(150, window.scrollY * .045).toFixed(2) : 0}px`,
    );
    sectionSignals.forEach(([section, signal]) => {
      section.style.setProperty('--section-signal', signal);
    });
    navigationLinks.forEach((link) => {
      const active = link.getAttribute('href') === `#${activeId}`;
      link.classList.toggle('is-active', active);
      if (active) link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    });
  };

  const scheduleScrollState = () => {
    if (scrollFrame) return;
    scrollFrame = window.requestAnimationFrame(updateScrollState);
  };
  scheduleScrollState();
  window.addEventListener('scroll', scheduleScrollState, { passive: true });
  window.addEventListener('resize', scheduleScrollState, { passive: true });

  const pointerSurfaces = [...document.querySelectorAll(
    '.product-device-slot, .architecture-node, .truth-callout, .bento, .setup-timeline li',
  )];
  if (finePointer.matches) {
    pointerSurfaces.forEach((surface) => {
      surface.classList.add('has-pointer-light');
      let pointerFrame = 0;
      let latestEvent = null;
      surface.addEventListener('pointermove', (event) => {
        if (!motionAllowed()) return;
        latestEvent = event;
        if (pointerFrame) return;
        pointerFrame = window.requestAnimationFrame(() => {
          pointerFrame = 0;
          const bounds = surface.getBoundingClientRect();
          const x = ((latestEvent.clientX - bounds.left) / bounds.width) * 100;
          const y = ((latestEvent.clientY - bounds.top) / bounds.height) * 100;
          surface.style.setProperty('--pointer-x', `${x.toFixed(2)}%`);
          surface.style.setProperty('--pointer-y', `${y.toFixed(2)}%`);
          if (surface.classList.contains('product-device-slot')) {
            surface.style.setProperty('--phone-tilt-y', `${((x - 50) * .035).toFixed(2)}deg`);
            surface.style.setProperty('--phone-tilt-x', `${((50 - y) * .025).toFixed(2)}deg`);
          }
        });
      }, { passive: true });
      surface.addEventListener('pointerleave', () => {
        surface.style.removeProperty('--pointer-x');
        surface.style.removeProperty('--pointer-y');
        surface.style.removeProperty('--phone-tilt-x');
        surface.style.removeProperty('--phone-tilt-y');
      }, { passive: true });
    });
  }

  reduceMotion.addEventListener?.('change', () => {
    if (motionPreference !== 'system') return;
    syncMotionState();
    if (!motionAllowed()) revealItems.forEach((item) => item.classList.add('is-visible'));
    scheduleScrollState();
  });

  document.querySelectorAll('[data-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });
})();
