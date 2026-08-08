(() => {
  'use strict';

  document.documentElement.className = 'js';

  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const header = document.querySelector('[data-header]');
  const menuButton = document.querySelector('[data-menu-button]');
  const mobileNav = document.querySelector('[data-mobile-nav]');
  const productTabs = [...document.querySelectorAll('[role="tab"][data-demo-target]')];
  const allDemoControls = [...document.querySelectorAll('[data-demo-target]')];
  const panels = [...document.querySelectorAll('[data-demo-panel]')];
  const heroStage = document.querySelector('.hero-stage');
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

    if (options.focusPhone && heroStage) {
      const block = window.innerWidth < 760 ? 'center' : 'center';
      heroStage.scrollIntoView({ behavior: reduceMotion.matches ? 'auto' : 'smooth', block });
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

  if (!reduceMotion.matches) {
    window.setInterval(() => {
      if (!gatewayRunning || document.body.dataset.demo !== 'gateway' || !logList) return;
      const [symbol, message, style] = logMessages[logSequence % logMessages.length];
      const row = document.createElement('li');
      const now = new Date();
      row.innerHTML = `<time>${now.toLocaleTimeString([], { hour12: false })}</time><span class="${style}">${symbol}</span> ${message}`;
      logList.append(row);
      while (logList.children.length > 7) logList.firstElementChild?.remove();
      logSequence += 1;
    }, 3200);
  }

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
  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    const observer = new IntersectionObserver((entries, revealObserver) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-visible');
        revealObserver.unobserve(entry.target);
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: .08 });
    revealItems.forEach((item) => observer.observe(item));
  } else {
    revealItems.forEach((item) => item.classList.add('is-visible'));
  }

  document.querySelectorAll('[data-year]').forEach((node) => {
    node.textContent = String(new Date().getFullYear());
  });
})();
