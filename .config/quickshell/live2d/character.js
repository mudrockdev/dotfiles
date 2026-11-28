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
  // maxY: only drawables that end above it (to measure the upper body alone)
  function drawnBounds(maxY = Infinity) {
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (let i = 0; i < cm.getDrawableCount(); i++) {
      if (!cm.getDrawableDynamicFlagIsVisible(i) || cm.getDrawableOpacity(i) < 0.3)
        continue;
      const b = im.getDrawableBounds(i);
      if (b.y + b.height > maxY)
        continue;
      x0 = Math.min(x0, b.x); y0 = Math.min(y0, b.y);
      x1 = Math.max(x1, b.x + b.width); y1 = Math.max(y1, b.y + b.height);
    }
    return { x0, y0, x1, y1 };
  }
  // "upper": head to hips, cut by the screen edge; "full": head to feet (and tail)
  const UPPER = 0.5;    // share of the full height shown in upper-body framing
  let body = null;      // drawn area at rest, model canvas coordinates
  let upper = null;     // drawn area of the upper body (centres the framing)
  let head = { x: 0, y: 0 };  // window coordinates
  function layout() {
    const w = window.innerWidth, h = window.innerHeight;
    body = body ?? drawnBounds();
    const bh = body.y1 - body.y0;
    upper = upper ?? drawnBounds(body.y0 + bh * UPPER);
    let s;
    model.anchor.set(0, 0);
    if (cfg.framing === "full") {
      const bw = body.x1 - body.x0;
      s = Math.min((h * 0.95) / bh, (w * 0.98) / bw);
      model.position.set(w / 2 - (body.x0 + bw / 2) * s, h - 2 - body.y1 * s);
    } else {
      s = (h * 0.96) / (bh * UPPER);
      const cx = (upper.x0 + upper.x1) / 2;
      model.position.set(w / 2 - cx * s, h - (body.y0 + bh * UPPER) * s);
    }
    model.scale.set(s);
    const cx = (upper.x0 + upper.x1) / 2;
    const hp = model.toGlobal(new PIXI.Point(cx, body.y0 + bh * 0.2));
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
    // The debug menu (when open) must be clickable too
    const mr = menuRect();
    if (mr) rects.push(mr);
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
    const open = Math.min(eyeOpen, 1.5) * blink;   // up to 1.5 = wide open
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

  // Looks toward a point in window coordinates (may be far outside the window).
  // near: the pointer is over her (smoother 30 fps); far moves keep the idle frame rate.
  function lookToward(x, y, near) {
    hoverUntil = now() + 1.2;
    if (near) fast(1.5);
    if (lookOverride) return;
    const dx = x - head.x, dy = head.y - y;
    const d = Math.hypot(dx, dy) || 1;
    const k = Math.min(1, d / 260) / d;   // full turn from 260 px away, direction kept
    focus(dx * k, dy * k);
  }
  app.canvas.addEventListener("pointermove", e => lookToward(e.clientX, e.clientY, true));
  // Pointer anywhere on screen, from deepseek.py (null = on no output)
  window.dsCursor = p => {
    if (p) lookToward(p[0], p[1]);
    else { hoverUntil = 0; wander(); }
  };

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
      // The model's own raised-hand pose; only head and body move on top of it
      // (driving the arm/finger parameters from here looked unnatural)
      await setRight("finger");
      if (!alive(my)) return;
      set("ParamAngleZ", t => 7 * Math.sin(t * 4.5), 3);
      set("ParamBodyAngleZ", t => 3 * Math.sin(t * 4.5 - 0.5), 3);
      set("ParamAngleY", t => 3 + 3 * Math.sin(t * 9), 3);
      await sleep(2.4);
      release("ParamAngleZ", "ParamBodyAngleZ", "ParamAngleY");
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
    // Sways side to side to a tune only she hears, eyes closed
    async sway(my) {
      look(0, 0);
      eyeOpen = 0;
      set("EyeSmile", 1);
      set("ParamMouthForm", 0.8);
      set("ParamMouthOpenY", t => 0.08 + 0.08 * Math.max(0, Math.sin(t * 5.2)), 4);
      set("ParamBodyAngleZ", t => 8 * Math.sin(t * 2.2), 2);
      set("ParamBodyAngleX", t => 4 * Math.sin(t * 2.2 + 0.4), 2);
      set("ParamAngleZ", t => 10 * Math.sin(t * 2.2 - 0.6), 2);
      set("ShoulderZ", t => 6 * Math.sin(t * 2.2 - 0.3), 2);
      await sleep(rand(5, 8));
      eyeOpen = 1;
    },
    // Looks to one side, then the other, then back at the user
    async lookAround(my) {
      const first = Math.random() < 0.5 ? -1 : 1;
      for (const [x, y, d] of [[0.85 * first, 0.05, 1.6], [0.2 * first, -0.1, 0.5],
                               [-0.85 * first, 0.1, 1.6], [0, 0.05, 0.8]]) {
        if (!alive(my)) return;
        look(x, y);
        set("ParamBodyAngleX", x * 6, 2);
        await sleep(d);
      }
      if (alive(my) && Math.random() < 0.4) { expr("屑屑眼"); await sleep(1.5); }
    },
    // Tilts her head and leans in, curious
    async curious(my) {
      const side = Math.random() < 0.5 ? -1 : 1;
      look(0.1 * side, 0.15);
      set("ParamAngleZ", 14 * side, 2.5);
      set("LeanInput", -14, 2);
      set("BrowInnerUp", 0.8);
      set("ParamMouthOpenY", 0.18); set("ParamMouthForm", 0.2);
      await sleep(rand(3, 4.5));
    },
    // Giggles: eyes squeezed into a smile, shoulders bobbing
    async giggle(my) {
      look(0.15, -0.1);
      set("EyeSmile", 1);
      eyeOpen = 0.15;
      set("ParamMouthForm", 1);
      set("ParamMouthOpenY", t => 0.25 + 0.2 * Math.max(0, Math.sin(t * 15)), 8);
      set("ShoulderY", t => 5 * Math.abs(Math.sin(t * 7.5)), 6);
      set("ParamAngleY", t => -3 + 3 * Math.abs(Math.sin(t * 7.5)), 6);
      if (Math.random() < 0.5) expr("脸红");
      await sleep(rand(2, 3));
      eyeOpen = 1;
    },
    // A big, slow yawn
    async yawn(my) {
      look(0, 0.4);
      set("ParamAngleY", 10, 1.2);
      set("ParamMouthOpenY", 1, 1.2); set("JawOpen", 1, 1.2); set("ParamMouthForm", -0.4, 1.2);
      set("ParamA", 1, 1.2); set("ParamO", 0.6, 1.2);
      set("ShoulderY", 6, 1);
      eyeOpen = 0;
      await sleep(2.2);
      release("ParamMouthOpenY", "JawOpen", "ParamMouthForm", "ParamA", "ParamO", "ShoulderY", "ParamAngleY");
      await sleep(0.6);
      eyeOpen = 0.6;
      await sleep(0.8);
      eyeOpen = 1;
    },
    // Angry: brows down, puffed cheeks, "hmph" and turns away (rarely the dark face)
    async angry(my) {
      const side = Math.random() < 0.5 ? -1 : 1;
      const brows = () => {
        set("ParamBrowLAngle", -1); set("ParamBrowRAngle", -1);
        set("ParamBrowLY", -1); set("ParamBrowRY", -1);
      };
      brows();
      set("LEyeSquint", 0.6); set("REyeSquint", 0.6);
      set("ParamMouthForm", -1); set("CheeckPuff", 1);
      look(0, 0.05);
      // Stomps: a few quick shakes
      set("ParamAngleX", t => 6 * Math.sin(t * 22), 10);
      await sleep(0.7);
      release("ParamAngleX");
      if (!alive(my)) return;
      // Hmph: turns her head away, chin up, eyes closed
      look(0.9 * side, 0.35);
      set("ParamAngleZ", -8 * side, 3);
      eyeOpen = 0;
      if (Math.random() < 0.25) expr("黑脸");
      await sleep(rand(1.8, 2.6));
      if (!alive(my)) return;
      // Peeks back to check you noticed
      eyeOpen = 1;
      look(0.35 * side, 0.1);
      await sleep(1.4);
    },
    // Scared: wide eyes, trembling, leaning back, cold sweat, nervous glances
    async scared(my) {
      expr(Math.random() < 0.3 ? "圈圈眼" : "流冷汗");
      set("BrowInnerUp", 1); set("ParamBrowLY", 1); set("ParamBrowRY", 1);
      set("ParamBrowLAngle", 1); set("ParamBrowRAngle", 1);
      set("ParamMouthOpenY", 0.45); set("ParamMouthForm", -1);
      eyeOpen = 1.3;
      set("LeanInput", 16, 3);
      set("ParamAngleX", t => 2.2 * Math.sin(t * 47), 8);
      set("ParamBodyAngleX", t => 1.5 * Math.sin(t * 41 + 1), 8);
      set("ShoulderY", 7, 4);
      for (const x of [-0.7, 0.7, -0.5, 0.1]) {
        if (!alive(my)) return;
        look(x, -0.15);
        await sleep(rand(0.6, 1));
      }
      await sleep(0.6);
      eyeOpen = 1;
    },
    // Surprised: a jolt back, eyes wide, mouth open, then a relieved blink
    async surprised(my) {
      set("ParamBrowLY", 1, 14); set("ParamBrowRY", 1, 14);
      set("ParamMouthOpenY", 0.8, 14); set("ParamA", 0.8, 14);
      eyeOpen = 1.5;
      set("LeanInput", 20, 12);
      set("ParamAngleY", 8, 12);
      look(0, 0.15);
      await sleep(0.5);
      release("LeanInput");
      await sleep(rand(1.2, 1.8));
      if (!alive(my)) return;
      eyeOpen = 1;
      release("ParamA", "ParamAngleY");
      set("ParamMouthOpenY", 0.2);
      await sleep(0.8);
    },
    // Sad: head down, drooping brows, tears
    async sad(my) {
      expr("流泪");
      set("BrowInnerUp", 1); set("ParamBrowLAngle", 0.7); set("ParamBrowRAngle", 0.7);
      set("ParamMouthForm", -1);
      eyeOpen = 0.65;
      look(-0.2, -0.6);
      set("ParamAngleY", -10, 1.5);
      set("ShoulderY", -4, 1.5);
      // Small sniffles
      set("ParamBodyAngleY", t => Math.max(0, Math.sin(t * 2.4)) ** 8 * 4, 6);
      await sleep(rand(4.5, 6.5));
      eyeOpen = 1;
    },
    // Happy ear flaps: quick ups and downs, blushing, eyes smiling, a little bounce
    async earFlap(my) {
      expr("脸红");
      look(0, 0.1);
      set("EyeSmile", 1, 8);
      eyeOpen = 0.2;
      set("ParamMouthForm", 1, 8);
      set("ParamMouthOpenY", 0.3, 8);
      const flaps = Math.round(rand(3, 5));
      const hz = 2.4, t0 = now(), dur = flaps / hz;
      // 0 → up → 0, `flaps` times; the tips (Ear2/3) trail a little for a springy look
      const wave = lag => t => {
        const u = t - t0 - lag;
        return u < 0 || u > dur ? 0 : Math.sin(Math.PI * hz * u) ** 2;
      };
      set("LControl", t => wave(0)(t), 15); set("RControl", t => wave(0.03)(t), 15);
      set("LEar1", t => wave(0.05)(t), 15); set("REar1", t => wave(0.08)(t), 15);
      set("LEar2", t => wave(0.1)(t), 15); set("REar2", t => wave(0.13)(t), 15);
      set("LEar3", t => wave(0.15)(t), 15); set("REar3", t => wave(0.18)(t), 15);
      set("ParamAngleY", t => 4 * wave(0)(t), 12);
      set("ShoulderY", t => 3 * wave(0.04)(t), 12);
      await sleep(dur + 0.2);
      release("LControl", "RControl", "LEar1", "REar1", "LEar2", "REar2", "LEar3", "REar3",
              "ParamAngleY", "ShoulderY");
      await sleep(rand(1, 1.6));
      eyeOpen = 1;
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
  Object.assign(window.__ds, { set, release, expr, look });

  // Something every 20-50 s
  const weights = { look: 3, lookAround: 3, sway: 2.5, curious: 2, wave: 2, eat: 2, think: 2,
                    giggle: 1.5, earFlap: 1.5, shy: 1.5, yawn: 1, busy: 1, sleepy: 1,
                    surprised: 0.8, angry: 0.6, scared: 0.5, sad: 0.4 };
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

  // Clicks: wave back; a burst of clicks gets her flustered, keep poking and she gets angry
  let clicks = [];
  app.canvas.addEventListener("pointerdown", e => {
    if (e.button !== 0) return;
    if (menu.open) { closeMenu(); return; }
    const t = now();
    clicks = clicks.filter(c => t - c < 3).concat([t]);
    if (clicks.length >= 6) { clicks = []; run("angry"); }
    else if (clicks.length === 3) run("flustered");
    else if (clicks.length === 1 && !busy) run(Math.random() < 0.2 ? "surprised" : "wave");
  });

  // ---------------- Debug menu (right click, when enabled in the panel) ----------------
  // Lists every state; picking one cancels whatever is running.
  const LABELS = {
    look: "Look at you", lookAround: "Look around", wave: "Wave", sway: "Sway", curious: "Curious",
    giggle: "Giggle", earFlap: "Ear flaps", shy: "Shy", eat: "Eat", think: "Think", busy: "Server busy",
    yawn: "Yawn", sleepy: "Sleepy", surprised: "Surprised", angry: "Angry", scared: "Scared",
    sad: "Sad", flustered: "Flustered",
  };
  let debug = !!cfg.debug;
  window.dsDebug = on => { debug = !!on; if (!debug) closeMenu(); };
  const menu = { el: document.createElement("div"), open: false };
  menu.el.id = "menu";
  document.body.appendChild(menu.el);
  function addItem(label, onClick, cls) {
    const b = document.createElement("div");
    b.className = "item" + (cls ? " " + cls : "");
    b.textContent = label;
    b.addEventListener("pointerdown", e => { e.stopPropagation(); if (e.button === 0) { closeMenu(); onClick(); } });
    menu.el.appendChild(b);
  }
  addItem("DeepSeek debug", () => {}, "title");
  for (const name of Object.keys(states))
    addItem(LABELS[name] ?? name, () => run(name));
  addItem("Stop (calm)", () => stop(), "wide");
  function menuRect() {
    if (!menu.open) return null;
    const r = menu.el.getBoundingClientRect();
    return [Math.floor(r.left), Math.floor(r.top), Math.ceil(r.width), Math.ceil(r.height)];
  }
  function openMenu(x, y) {
    menu.el.style.display = "grid";
    const w = menu.el.offsetWidth, h = menu.el.offsetHeight;
    menu.el.style.left = clamp(x, 2, window.innerWidth - w - 2) + "px";
    menu.el.style.top = clamp(y, 2, window.innerHeight - h - 2) + "px";
    menu.open = true;
    sendInput(true);
  }
  function closeMenu() {
    if (!menu.open) return;
    menu.open = false;
    menu.el.style.display = "none";
    sendInput(true);
  }
  // Cancel the running state without starting another
  async function stop() {
    const my = ++token;
    busy = true;
    await calm();
    if (alive(my)) busy = false;
  }
  app.canvas.addEventListener("contextmenu", e => e.preventDefault());
  menu.el.addEventListener("contextmenu", e => e.preventDefault());
  app.canvas.addEventListener("pointerdown", e => {
    if (e.button === 2 && debug) openMenu(e.clientX, e.clientY);
  });
  // The menu can't see clicks outside this window: close it when the pointer leaves
  let leaveTimer = 0;
  document.addEventListener("mouseleave", () => { leaveTimer = setTimeout(closeMenu, 800); });
  document.addEventListener("mouseenter", () => clearTimeout(leaveTimer));

  layout();
  window.addEventListener("resize", layout);
  setTimeout(() => run("wave"), 1200);   // hello
  log("ready");
})();
