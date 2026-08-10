const ASSET_ROOT = '/assets/vrm/gemini-v1';
const LIMB_GESTURES = [
  'animations/limbs/Light_Wave_Left_01.vrma',
  'animations/limbs/Light_Wave_Right_01.vrma',
];
const hosts = [...document.querySelectorAll('[data-vrm-host]')];

if (hosts.length) {
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  const constrainedDevice = Boolean(
    reduceMotion.matches
      || connection?.saveData
      || (navigator.deviceMemory && navigator.deviceMemory < 4),
  );

  const statusNodes = hosts.map((host) => host.querySelector('[data-vrm-status]'));
  let activeHost = null;
  let renderer = null;
  let scene = null;
  let camera = null;
  let currentVrm = null;
  let mixer = null;
  let idleAction = null;
  let currentAction = null;
  let clock = null;
  let resizeObserver = null;
  let animationFrame = 0;
  let loadingPromise = null;
  let ready = false;
  let paused = true;
  let lastRenderAt = 0;
  let targetYaw = Math.PI;
  let currentYaw = Math.PI;
  let metrics = { height: 1.8, width: 0.8, centerX: 0, lookY: 0.9 };
  let gestureCountdown = Number.POSITIVE_INFINITY;
  let gestureLoading = false;
  let activeGestureAction = null;
  let activeGestureRemaining = 0;
  let lastGesturePath = '';
  const gestureActions = new Map();
  const failedGesturePaths = new Set();

  const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
  const targetFrameMs = isMobile ? 1000 / 30 : 1000 / 45;
  const maxPixelRatio = Math.min(window.devicePixelRatio || 1, isMobile ? 1.35 : 1.65);

  const setStatus = (message) => {
    statusNodes.forEach((node) => {
      if (node) node.textContent = message;
    });
  };

  const setHostState = (className, enabled) => {
    hosts.forEach((host) => host.classList.toggle(className, enabled));
  };

  const supportsWebGl = () => {
    try {
      const canvas = document.createElement('canvas');
      const context = window.WebGLRenderingContext
        && (canvas.getContext('webgl2') || canvas.getContext('webgl'));
      context?.getExtension('WEBGL_lose_context')?.loseContext();
      return Boolean(context);
    } catch (_) {
      return false;
    }
  };

  const measuredVisibility = (host) => {
    const bounds = host.getBoundingClientRect();
    if (bounds.width < 1 || bounds.height < 1) return 0;
    const visibleWidth = Math.max(
      0,
      Math.min(bounds.right, window.innerWidth) - Math.max(bounds.left, 0),
    );
    const visibleHeight = Math.max(
      0,
      Math.min(bounds.bottom, window.innerHeight) - Math.max(bounds.top, 0),
    );
    return (visibleWidth * visibleHeight) / (bounds.width * bounds.height);
  };

  const hostVisibility = (host) => measuredVisibility(host);

  const isHostEligible = (host) => {
    if (host.dataset.vrmHost === 'chat' && document.body.dataset.demo !== 'chat') {
      return false;
    }
    return hostVisibility(host) > 0.025;
  };

  const frameCamera = () => {
    if (!renderer || !camera || !activeHost) return;
    const { width, height } = activeHost.getBoundingClientRect();
    if (width < 2 || height < 2) return;

    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();

    const compact = activeHost.dataset.vrmHost === 'chat';
    const zoom = compact ? 1.5 : 1.08;
    const panY = compact ? 0.2 : 0.03;
    const tanFov = Math.tan((camera.fov * Math.PI) / 360);
    const heightDistance = (metrics.height / (2 * tanFov)) / zoom;
    const widthDistance = (metrics.width / (2 * tanFov * camera.aspect)) / zoom;
    const distance = Math.max(heightDistance, widthDistance);
    const frameCenterY = metrics.height / 2 + panY;

    camera.position.set(metrics.centerX, frameCenterY + 0.05, distance);
    camera.lookAt(metrics.centerX, frameCenterY, 0);
    metrics.lookY = frameCenterY;
  };

  const attachRenderer = (host) => {
    if (!renderer || !host || activeHost === host && renderer.domElement.parentElement === host) {
      return;
    }
    hosts.forEach((item) => item.classList.remove('is-vrm-active'));
    activeHost = host;
    activeHost.append(renderer.domElement);
    activeHost.classList.add('is-vrm-active');
    frameCamera();
  };

  const updateActiveHost = () => {
    const candidates = hosts
      .filter(isHostEligible)
      .sort((left, right) => hostVisibility(right) - hostVisibility(left));
    const nextHost = candidates[0] || null;

    if (nextHost) {
      if (renderer) attachRenderer(nextHost);
      paused = !ready || document.hidden;
      if (!loadingPromise && !constrainedDevice) scheduleLoad();
    } else {
      paused = true;
      activeHost?.classList.remove('is-vrm-active');
      activeHost = null;
    }
  };

  const getHumanoidAnchorX = (THREE, vrm) => {
    if (!vrm?.humanoid) return 0;
    const head = vrm.humanoid.getNormalizedBoneNode('head');
    const hips = vrm.humanoid.getNormalizedBoneNode('hips');
    const headPosition = new THREE.Vector3();
    const hipsPosition = new THREE.Vector3();
    const rawCenter = new THREE.Vector3();
    if (head) head.getWorldPosition(headPosition);
    if (hips) hips.getWorldPosition(hipsPosition);
    new THREE.Box3().setFromObject(vrm.scene).getCenter(rawCenter);
    if (head && hips) return headPosition.x * 0.62 + hipsPosition.x * 0.38;
    if (head) return headPosition.x;
    if (hips) return hipsPosition.x;
    return rawCenter.x;
  };

  const recenterVrm = (THREE, vrm) => {
    const anchorX = getHumanoidAnchorX(THREE, vrm);
    if (!Number.isFinite(anchorX)) return;
    vrm.scene.position.x -= anchorX;
    vrm.scene.updateMatrixWorld(true);
  };

  const measureVrm = (THREE, vrm) => {
    const box = new THREE.Box3().setFromObject(vrm.scene);
    const size = box.getSize(new THREE.Vector3());
    return {
      height: size.y,
      width: size.x,
      centerX: 0,
      lookY: size.y / 2,
    };
  };

  const loadWithProgress = (loader, url, onProgress) => new Promise((resolve, reject) => {
    loader.load(url, resolve, onProgress, reject);
  });

  const loadVettedLimbClip = async (loader, url) => {
    const originalWarn = console.warn;
    console.warn = (...argumentsList) => {
      const message = String(argumentsList[0] || '');
      const ignoredTranslationTrack = message.startsWith(
        'The loading animation contains a translation track for ',
      ) && message.endsWith('which is not permitted in the VRMC_vrm_animation spec. ignoring the track');
      if (!ignoredTranslationTrack) originalWarn.apply(console, argumentsList);
    };
    try {
      // These vetted exports include redundant non-hips translations. The VRM
      // loader intentionally ignores them; keep that behavior without flooding
      // production consoles every time a lazy limb clip is selected.
      return await loadWithProgress(loader, url);
    } finally {
      console.warn = originalWarn;
    }
  };

  const dispose = () => {
    cancelAnimationFrame(animationFrame);
    resizeObserver?.disconnect();
    mixer?.stopAllAction();
    gestureActions.clear();
    currentVrm?.dispose?.();
    renderer?.dispose();
    renderer?.forceContextLoss?.();
  };

  const fail = (error) => {
    console.warn('[Plawie] Gemini web companion unavailable.', error);
    ready = false;
    paused = true;
    setHostState('is-vrm-loading', false);
    setHostState('is-vrm-gesturing', false);
    setHostState('is-vrm-unavailable', true);
    setStatus('App visual');
    dispose();
    renderer?.domElement.remove();
  };

  const loadCompanion = async () => {
    setHostState('is-vrm-loading', true);
    setStatus('Preparing Gemini…');

    const [THREE, loaderModule, vrmModule, animationModule] = await Promise.all([
      import(`${ASSET_ROOT}/lib/three.module.js`),
      import(`${ASSET_ROOT}/lib/GLTFLoader.js`),
      import(`${ASSET_ROOT}/lib/three-vrm.module.js`),
      import(`${ASSET_ROOT}/lib/three-vrm-animation.module.js`),
    ]);

    scene = new THREE.Scene();
    camera = new THREE.PerspectiveCamera(30, 1, 0.1, 20);
    renderer = new THREE.WebGLRenderer({
      alpha: true,
      antialias: !isMobile,
      powerPreference: isMobile ? 'low-power' : 'high-performance',
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(maxPixelRatio);
    renderer.domElement.className = 'vrm-canvas';
    renderer.domElement.setAttribute('aria-hidden', 'true');
    renderer.domElement.addEventListener('webglcontextlost', (event) => {
      event.preventDefault();
      fail(new Error('WebGL context lost'));
    });

    scene.add(new THREE.AmbientLight(0xffffff, 0.8));
    const keyLight = new THREE.DirectionalLight(0xffffff, 0.3);
    keyLight.position.set(1, 2, 3);
    scene.add(keyLight);
    const rimLight = new THREE.PointLight(0x00ffa3, 0.36, 5);
    rimLight.position.set(-1.2, 1.5, 1.2);
    scene.add(rimLight);

    const loader = new loaderModule.GLTFLoader();
    loader.register((parser) => new vrmModule.VRMLoaderPlugin(parser));
    loader.register((parser) => new animationModule.VRMAnimationLoaderPlugin(parser));

    attachRenderer(
      hosts.filter(isHostEligible)
        .sort((left, right) => hostVisibility(right) - hostVisibility(left))[0]
        || hosts[0],
    );

    const modelGltf = await loadWithProgress(
      loader,
      `${ASSET_ROOT}/gemini.vrm`,
      ({ loaded, total }) => {
        if (!total) return;
        const percent = Math.min(99, Math.max(1, Math.round((loaded / total) * 100)));
        setStatus(`Loading Gemini · ${percent}%`);
      },
    );
    const vrm = modelGltf.userData.vrm;
    if (!vrm) throw new Error('Gemini asset did not expose a VRM scene');

    currentVrm = vrm;
    scene.add(currentVrm.scene);
    currentVrm.scene.rotation.y = Math.PI;
    currentVrm.scene.traverse((object) => { object.frustumCulled = false; });
    currentVrm.scene.position.set(0, 0, 0);
    currentVrm.scene.updateMatrixWorld(true);

    const initialSize = new THREE.Box3()
      .setFromObject(currentVrm.scene)
      .getSize(new THREE.Vector3());
    const scale = 1.8 / initialSize.y;
    currentVrm.scene.scale.setScalar(scale);
    currentVrm.scene.updateMatrixWorld(true);
    recenterVrm(THREE, currentVrm);
    metrics = measureVrm(THREE, currentVrm);

    setStatus('Synchronizing idle motion…');
    mixer = new THREE.AnimationMixer(currentVrm.scene);
    const animationGltf = await loadWithProgress(
      loader,
      `${ASSET_ROOT}/animations/idle_loop.vrma`,
    );
    const vrmAnimation = animationGltf.userData.vrmAnimations?.[0];
    if (!vrmAnimation) throw new Error('Gemini idle animation is missing');
    if (currentVrm.lookAt) {
      const lookAtProxy = new animationModule.VRMLookAtQuaternionProxy(currentVrm.lookAt);
      lookAtProxy.name = 'VRMLookAtQuaternionProxy';
      currentVrm.scene.add(lookAtProxy);
    }
    const clip = animationModule.createVRMAnimationClip(vrmAnimation, currentVrm);
    idleAction = mixer.clipAction(clip);
    idleAction.setLoop(THREE.LoopRepeat, Infinity).play();
    currentAction = idleAction;
    mixer.update(1 / 60);
    recenterVrm(THREE, currentVrm);
    metrics = measureVrm(THREE, currentVrm);

    clock = new THREE.Clock();
    ready = true;
    paused = document.hidden || !activeHost;
    setHostState('is-vrm-loading', false);
    setHostState('is-vrm-ready', true);
    setStatus('Gemini · live 3D');
    frameCamera();
    renderer.render(scene, camera);

    const randomDelay = (initial = false) => {
      const minimum = initial ? 8 : 22;
      const maximum = initial ? 14 : 38;
      return minimum + Math.random() * (maximum - minimum);
    };

    const chooseGesturePath = () => {
      const available = LIMB_GESTURES.filter((path) => (
        path !== lastGesturePath && !failedGesturePaths.has(path)
      ));
      const pool = available.length
        ? available
        : LIMB_GESTURES.filter((path) => !failedGesturePaths.has(path));
      if (!pool.length) return null;
      return pool[Math.floor(Math.random() * pool.length)];
    };

    const loadLimbGesture = async (path) => {
      if (!path.startsWith('animations/limbs/') || !path.endsWith('.vrma')) {
        throw new Error('Landing gestures must come from animations/limbs/');
      }
      if (gestureActions.has(path)) return gestureActions.get(path);

      const gltf = await loadVettedLimbClip(loader, `${ASSET_ROOT}/${path}`);
      const animation = gltf.userData.vrmAnimations?.[0];
      const humanBones = gltf.parser?.json?.extensions
        ?.VRMC_vrm_animation?.humanoid?.humanBones;
      if (!animation || !humanBones || !Object.keys(humanBones).length) {
        throw new Error(`Limb animation is missing VRM humanoid tracks: ${path}`);
      }

      const gestureClip = animationModule.createVRMAnimationClip(animation, currentVrm);
      if (!gestureClip.tracks.length || !Number.isFinite(gestureClip.duration)) {
        throw new Error(`Limb animation produced an invalid clip: ${path}`);
      }
      const action = mixer.clipAction(gestureClip);
      action.setLoop(THREE.LoopOnce, 1);
      action.clampWhenFinished = false;
      gestureActions.set(path, action);
      return action;
    };

    const returnToIdle = () => {
      if (!idleAction) return;
      activeGestureAction?.fadeOut(0.42);
      idleAction.reset()
        .setEffectiveWeight(1)
        .setEffectiveTimeScale(1)
        .fadeIn(0.42)
        .play();
      currentAction = idleAction;
      activeGestureAction = null;
      activeGestureRemaining = 0;
      gestureCountdown = randomDelay();
      setHostState('is-vrm-gesturing', false);
    };

    const playOccasionalLimbGesture = async () => {
      if (gestureLoading || currentAction !== idleAction) return;
      const path = chooseGesturePath();
      if (!path) {
        gestureCountdown = Number.POSITIVE_INFINITY;
        return;
      }

      gestureLoading = true;
      try {
        const action = await loadLimbGesture(path);
        if (paused || document.hidden || !activeHost || currentAction !== idleAction) {
          gestureCountdown = 4;
          return;
        }

        idleAction.fadeOut(0.34);
        action.reset()
          .setEffectiveWeight(1)
          .setEffectiveTimeScale(1)
          .fadeIn(0.34)
          .play();
        currentAction = action;
        activeGestureAction = action;
        activeGestureRemaining = Math.max(0.35, action.getClip().duration - 0.3);
        lastGesturePath = path;
        setHostState('is-vrm-gesturing', true);
      } catch (error) {
        failedGesturePaths.add(path);
        gestureCountdown = randomDelay();
        console.warn('[Plawie] Optional limb animation unavailable.', error);
      } finally {
        gestureLoading = false;
      }
    };

    gestureCountdown = randomDelay(true);

    const animate = (timestamp) => {
      animationFrame = requestAnimationFrame(animate);
      if (paused || document.hidden || !currentVrm || !activeHost) {
        clock.getDelta();
        lastRenderAt = timestamp;
        return;
      }
      const elapsedSinceRender = timestamp - lastRenderAt;
      if (elapsedSinceRender < targetFrameMs) return;
      lastRenderAt = timestamp - (elapsedSinceRender % targetFrameMs);
      const delta = Math.min(clock.getDelta(), 0.05);
      mixer?.update(delta);
      currentVrm.update(delta);
      if (activeGestureAction) {
        activeGestureRemaining -= delta;
        if (activeGestureRemaining <= 0) returnToIdle();
      } else if (!gestureLoading && currentAction === idleAction) {
        gestureCountdown -= delta;
        if (gestureCountdown <= 0) {
          gestureCountdown = Number.POSITIVE_INFINITY;
          void playOccasionalLimbGesture();
        }
      }
      currentYaw = THREE.MathUtils.lerp(currentYaw, targetYaw, delta * 2.4);
      currentVrm.scene.rotation.y = currentYaw;
      renderer.render(scene, camera);
    };
    animationFrame = requestAnimationFrame(animate);
  };

  function scheduleLoad() {
    if (loadingPromise || constrainedDevice) return;
    if (!supportsWebGl()) {
      loadingPromise = Promise.resolve();
      setHostState('is-vrm-unavailable', true);
      setStatus('App visual');
      return;
    }
    loadingPromise = new Promise((resolve) => {
      const begin = () => resolve(loadCompanion());
      if ('requestIdleCallback' in window) {
        window.requestIdleCallback(begin, { timeout: 1800 });
      } else {
        window.setTimeout(begin, 900);
      }
    }).catch(fail);
  }

  const intersectionObserver = new IntersectionObserver(updateActiveHost, {
    threshold: [0, 0.025, 0.1, 0.25, 0.5, 0.75, 1],
  });
  hosts.forEach((host) => intersectionObserver.observe(host));

  resizeObserver = new ResizeObserver(() => frameCamera());
  hosts.forEach((host) => resizeObserver.observe(host));

  document.addEventListener('plawie:demochange', () => {
    updateActiveHost();
    requestAnimationFrame(updateActiveHost);
    window.setTimeout(updateActiveHost, 320);
  });
  document.addEventListener('visibilitychange', () => {
    paused = document.hidden || !ready || !activeHost;
    clock?.getDelta();
  });
  window.addEventListener('pointermove', (event) => {
    if (!activeHost || event.pointerType === 'touch') return;
    const bounds = activeHost.getBoundingClientRect();
    const relativeX = ((event.clientX - bounds.left) / bounds.width) * 2 - 1;
    targetYaw = Math.PI + Math.max(-0.11, Math.min(0.11, relativeX * 0.08));
  }, { passive: true });
  window.addEventListener('pagehide', dispose, { once: true });

  if (constrainedDevice) {
    setHostState('is-vrm-unavailable', true);
    setStatus(reduceMotion.matches ? 'Motion reduced' : 'Data-saver visual');
  } else {
    window.addEventListener('load', updateActiveHost, { once: true });
  }
}
