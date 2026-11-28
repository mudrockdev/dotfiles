// DeepSeek-chan: rendering and behaviour. Runs inside deepseek.py's WebKit view.
//
// The model has no "wave"/"eat" motions of its own, so states are built from what it has:
//   motions:     finger up / foxtail grass (right hand), hand on chest (left hand), IDLE loop
//   expressions: loading spinner, blush, heart eyes, ><, steel basin, ...
//   parameters:  head/eye direction, mouth, cheeks, arm angles (driven from here)
(async () => {
  const cfg = window.DS_CONFIG;
  await loadScript(cfg.core);
  // Cubism Core 6 moved drawables.renderOrders to model.renderOrders (drawables first,
  // then offscreens); the engine still reads the Core 5 location.
  const CoreModel = Live2DCubismCore.Model;
  const fromMoc = CoreModel.fromMoc;
  CoreModel.fromMoc = moc => {
    const m = fromMoc.call(CoreModel, moc);
    if (m && m.drawables && !m.drawables.renderOrders && m.renderOrders)
      m.drawables.renderOrders = m.renderOrders.subarray(0, m.drawables.count);
    return m;
  };
  await loadScript("node_modules/untitled-pixi-live2d-engine/dist/cubism.min.js");
  const { Live2DModel, Live2DPlugin } = PIXI.live2d;
  // Workers fetch() textures, which fails for file:// URLs: load them as plain images
  PIXI.Assets.setPreferences({ preferWorkers: false, preferCreateImageBitmap: false });
  PIXI.extensions.add(Live2DPlugin);

  const app = new PIXI.Application();
  await app.init({
    resizeTo: window,
    preference: "webgl",
    backgroundAlpha: 0,
    antialias: true,
    autoDensity: true,
    resolution: window.devicePixelRatio || 1,
  });
  // Smooth only while something happens: 30 fps in states / hover, 20 fps idle (CPU)
  app.ticker.maxFPS = 20;
  let fastUntil = 0;
  function fast(sec) {
    fastUntil = Math.max(fastUntil, performance.now() / 1000 + sec);
    app.ticker.maxFPS = 30;
  }
  setInterval(() => { if (performance.now() / 1000 > fastUntil) app.ticker.maxFPS = 20; }, 500);
  document.body.appendChild(app.canvas);

  const model = await Live2DModel.from(cfg.settings, {
    autoFocus: false,
    autoHitTest: false,
    idleMotionGroup: "IDLE",
    // High-precision masks cost ~15% more CPU and look the same at this size
    useHighPrecisionMask: false,
  });
  app.stage.addChild(model);
  window.__ds = { app, model };   // for debugging from the WebKit inspector

  const im = model.internalModel;
  const cm = im.coreModel;
  const params = cm.getModel().parameters;
  const pidx = Object.fromEntries(Array.from(params.ids).map((id, i) => [id, i]));
  const now = () => performance.now() / 1000;
  const sleep = s => new Promise(r => setTimeout(r, s * 1000));
  const rand = (a, b) => a + Math.random() * (b - a);
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  // ---------------- Layout ----------------
  // The model canvas is mostly empty: fit the drawn area, feet on the window's bottom.
  function drawnBounds() {
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (let i = 0; i < cm.getDrawableCount(); i++) {
      if (!cm.getDrawableDynamicFlagIsVisible(i) || cm.getDrawableOpacity(i) < 0.3)
        continue;
      const b = im.getDrawableBounds(i);
      x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y);
      x1 = Math.max(x1, b.x + b.width); y1 = Math.max(y1, b.y + b.height);
    }
    return { x0, y0, x1, y1 };
  }
  let body = null;   // drawn area at rest, model canvas coordinates
  let head = { x: 0, y: 0 };  // window coordinates
  function layout() {
    const w = window.innerWidth, h = window.innerHeight;
    body = body ?? drawnBounds();
    const bw = body.x1 - body.x0, bh = body.y1 - body.y0;
    const s = Math.min((h * 0.95) / bh, (w * 0.98) / bw);
    model.anchor.set(0, 0);
    model.scale.set(s);
    model.position.set(w / 2 - (body.x0 + bw / 2) * s, h - 2 - body.y1 * s);
    const hp = model.toGlobal(new PIXI.Point(body.x0 + bw * 0.5, body.y0 + bh * 0.2));
    head = { x: hp.x, y: hp.y };
    sendInput(true);
  }

  // ---------------- Click area ----------------
  // Input region = cells of a coarse grid covered by visible drawables (sent as rects).
  const CELL = 10;
  let lastInput = "";
  function sendInput(force) {
    const w = window.innerWidth, h = window.innerHeight;
    const cols = Math.ceil(w / CELL), rows = Math.ceil(h / CELL);
    const grid = new Uint8Array(cols * rows);
    const p0 = new PIXI.Point(), p1 = new PIXI.Point();
    for (let i = 0; i < cm.getDrawableCount(); i++) {
      if (!cm.getDrawableDynamicFlagIsVisible(i) || cm.getDrawableOpacity(i) < 0.3)
        continue;
      const b = im.getDrawableBounds(i);
      model.toGlobal(p0.set(b.x, b.y), p0);
      model.toGlobal(p1.set(b.x + b.width, b.y + b.height), p1);
      const c0 = clamp(Math.floor(p0.x / CELL), 0, cols - 1), c1 = clamp(Math.floor(p1.x / CELL), 0, cols - 1);
      const r0 = clamp(Math.floor(p0.y / CELL), 0, rows - 1), r1 = clamp(Math.floor(p1.y / CELL), 0, rows - 1);
      // Thin, long meshes (hair strands, tail) cover little of their box: skip big boxes
      if ((c1 - c0 + 1) * (r1 - r0 + 1) > cols * rows * 0.12)
        continue;
      for (let r = r0; r <= r1; r++)
        for (let c = c0; c <= c1; c++)
          grid[r * cols + c] = 1;
    }
    const rects = [];
    for (let r = 0; r < rows; r++) {
      let c = 0;
      while (c < cols) {
        if (!grid[r * cols + c]) { c++; continue; }
        const start = c;
        while (c < cols && grid[r * cols + c]) c++;
        rects.push([start * CELL, r * CELL, (c - start) * CELL, CELL]);
      }
    }
    const key = JSON.stringify(rects);
    if (force || key !== lastInput) {
      lastInput = key;
      post({ type: "input", rects });
    }
  }
  setInterval(() => sendInput(false), 500);

  // ---------------- Parameter overrides ----------------
  // id -> { target: number | (t) => number, w: current weight, on: bool, rate }
  // Applied after motions/physics every frame and blended in/out smoothly.
  const ov = {};
  function set(id, target, rate = 5) {
    if (!(id in pidx)) return;
    const o = ov[id] ?? (ov[id] = { w: 0 });
    o.target = target; o.on = true; o.rate = rate;
  }
  function release(...ids) {
    for (const id of ids.length ? ids : Object.keys(ov))
      if (ov[id]) ov[id].on = false;
  }

  // Own blinking: the engine only blinks when no motion plays, and IDLE always plays
  let nextBlink = now() + 2, blinkAt = -1;
  let eyeOpen = 1;     // state-driven openness (sleepy etc.)
  let lastT = now();
  im.on("beforeModelUpdate", () => {
    const t = now(), dt = Math.min(0.1, t - lastT);
    lastT = t;
    for (const id in ov) {
      const o = ov[id];
      o.w += ((o.on ? 1 : 0) - o.w) * Math.min(1, o.rate * dt);
      if (!o.on && o.w < 0.01) { delete ov[id]; continue; }
      const v = typeof o.target === "function" ? o.target(t) : o.target;
      cm.setParameterValueByIndex(pidx[id], v, o.w);
    }
    if (t > nextBlink) { blinkAt = t; nextBlink = t + rand(2, 6) + (Math.random() < 0.2 ? -1.6 : 0); }
    const bt = (t - blinkAt) / 0.16;
    const blink = bt >= 0 && bt < 1 ? Math.abs(bt * 2 - 1) : 1;
    const open = Math.min(eyeOpen, 1) * blink;
    for (const id of ["ParamEyeLOpen", "ParamEyeROpen"])
      if (!ov[id]) cm.setParameterValueByIndex(pidx[id], open, 1);
  });

  // ---------------- Look direction ----------------
  const focus = (x, y, instant) => im.focusController.focus(clamp(x, -1, 1), clamp(y, -1, 1), instant);
  let hoverUntil = 0;
  let lookOverride = null;   // a state wants a specific direction
  function wander() {
    if (now() < hoverUntil || lookOverride) return;
    // Mostly at the user (straight ahead), sometimes glance around
    if (Math.random() < 0.55) focus(rand(-0.08, 0.08), rand(-0.05, 0.1));
    else focus(rand(-0.7, 0.7), rand(-0.45, 0.35));
  }
  (function loop() { wander(); setTimeout(loop, rand(2500, 6500)); })();
  function look(x, y) { lookOverride = { x, y }; focus(x, y); }
  function unlook() { lookOverride = null; wander(); }

  app.canvas.addEventListener("pointermove", e => {
    hoverUntil = now() + 1.2;
    fast(1.5);
    if (!lookOverride)
      focus((e.clientX - head.x) / 260, (head.y - e.clientY) / 260);
  });

  // ---------------- Poses (motions that hold their last frame) ----------------
  let right = null;        // null | "finger" | "grass"
  let chest = false;
  function play(group) {
    return new Promise(resolve => {
      model.motion(group, 0, 3, { loop: false, onFinish: resolve, onError: resolve })
        .then(ok => { if (!ok) resolve(); });
      setTimeout(resolve, 2500);   // never hang a state on a lost callback
    });
  }
  async function setRight(pose) {
    if (right === pose) return;
    if (right === "finger") await play("竖手指切回默认");
    if (right === "grass") await play("狗尾草切回默认手");
    right = null;
    if (pose === "finger") await play("竖手指切出来动画");
    if (pose === "grass") await play("狗尾草切换出来");
    right = pose;
  }
  async function setChest(on) {
    if (chest === on) return;
    await play(on ? "默认手切举手" : "举手切默认手");
    chest = on;
  }

  // ---------------- Expressions ----------------
  const expr = name => model.expression(name);
  const clearExpr = () => im.motionManager.expressionManager?.resetExpression();

  // ---------------- States ----------------
  let token = 0;            // bumping it cancels the running state
  let busy = false;
  const alive = my => my === token;

  async function calm() {
    release();
    eyeOpen = 1;
    clearExpr();
    unlook();
    await setRight(null);
    await setChest(false);
  }

  const states = {
    // Looks straight at the user with a soft smile
    async look(my) {
      look(0, 0.08);
      set("EyeSmile", 0.5); set("ParamMouthForm", 0.8);
      if (Math.random() < 0.35) expr("脸红");
      await sleep(rand(4, 6));
    },
    // Raises her hand and waves
    async wave(my) {
      look(0, 0.1);
      set("EyeSmile", 0.8); set("ParamMouthForm", 1); set("ParamMouthOpenY", 0.35);
      await setRight("finger");
      if (!alive(my)) return;
      set("Param43", 1, 8);  // open fingers
      set("Param41", t => 0.72 + 0.2 * Math.sin(t * 10), 6);
      set("Param42", t => 0.4 * Math.sin(t * 10 + 0.7), 6);
      set("ParamAngleZ", t => 6 * Math.sin(t * 5), 3);
      await sleep(2.6);
      release("Param41", "Param42", "Param43", "ParamAngleZ");
      await sleep(0.4);
    },
    // Nibbles on a foxtail stalk
    async eat(my) {
      await setRight("grass");
      if (!alive(my)) return;
      look(0.35, -0.15);
      set("ParamAngleZ", 7, 3);
      set("ParamMouthOpenY", t => Math.max(0, Math.sin(t * 13)) * 0.45, 8);
      set("JawOpen", t => Math.max(0, Math.sin(t * 13)) * 0.4, 8);
      set("CheeckPuff", t => 0.5 + 0.3 * Math.sin(t * 6.5), 4);
      set("EyeSmile", 0.6);
      await sleep(rand(4, 6));
      release("ParamMouthOpenY", "JawOpen", "CheeckPuff");
      if (alive(my) && Math.random() < 0.5) { expr("爱心眼"); await sleep(1.8); }
    },
    // Index finger up, eyes up: "hmm, let me think"
    async think(my) {
      await setRight("finger");
      if (!alive(my)) return;
      look(-0.45, 0.75);
      set("Mouthpucker", 0.7); set("ParamMouthForm", -0.3); set("BrowInnerUp", 0.6);
      await sleep(rand(3.5, 5));
    },
    // Hand on chest, blushing, looking away
    async shy(my) {
      await setChest(true);
      if (!alive(my)) return;
      expr("脸红");
      look(-0.6, -0.45);
      set("EyeSmile", 0.4); set("ParamMouthForm", 0.4);
      await sleep(rand(3.5, 5));
    },
    // "Server is busy, please try again later."
    async busy(my) {
      expr("加载");
      look(0, 0.6);
      set("ParamMouthOpenY", 0.15);
      await sleep(rand(4, 6));
    },
    // Drowsy: half-closed eyes, slow nods
    async sleepy(my) {
      eyeOpen = 0.3;
      look(0, -0.3);
      set("ParamAngleY", t => -8 - 6 * Math.max(0, Math.sin(t * 1.3)), 2);
      set("ParamMouthOpenY", 0.12);
      await sleep(rand(6, 9));
      eyeOpen = 1;
      release("ParamAngleY");
    },
    // Clicked several times: flustered (rarely: a bowl falls on her head)
    async flustered(my) {
      expr(Math.random() < 0.12 ? "钢盆" : "＞＜");
      set("ParamAngleZ", t => 5 * Math.sin(t * 18), 6);
      set("ParamMouthOpenY", 0.5); set("ParamMouthForm", -0.6);
      await sleep(2.2);
    },
  };

  async function run(name) {
    if (!states[name]) return;
    const my = ++token;
    busy = true;
    fast(30);
    try {
      await calm();
      if (alive(my)) await states[name](my);
      if (alive(my)) await calm();
    } finally {
      if (alive(my)) { busy = false; fastUntil = 0; }
    }
  }
  window.dsState = run;

  // Something every 20-50 s
  const weights = { look: 4, wave: 2, eat: 2, think: 2, shy: 1.5, busy: 1, sleepy: 1 };
  function pick() {
    const total = Object.values(weights).reduce((a, b) => a + b, 0);
    let r = Math.random() * total;
    for (const [k, v] of Object.entries(weights))
      if ((r -= v) < 0) return k;
    return "look";
  }
  (function schedule() {
    setTimeout(() => {
      if (!busy) run(pick());
      schedule();
    }, rand(20000, 50000));
  })();

  // Clicks: wave back; a burst of clicks gets her flustered
  let clicks = [];
  app.canvas.addEventListener("pointerdown", () => {
    const t = now();
    clicks = clicks.filter(c => t - c < 1.5).concat([t]);
    if (clicks.length >= 3) { clicks = []; run("flustered"); }
    else if (!busy) run("wave");
  });

  layout();
  window.addEventListener("resize", layout);
  setTimeout(() => run("wave"), 1200);   // hello
  log("ready");
})();
