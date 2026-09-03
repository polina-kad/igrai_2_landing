/* ============================================================
   IGRAI® — scroll-driven laptop stage
   three.js + GLB (Lid_Open clip) + DOM cards projected on the screen
   ============================================================ */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

/* ---------- tiny helpers ---------- */
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const lerp = (a, b, t) => a + (b - a) * t;
const inv = (v, a, b) => clamp((v - a) / (b - a));
const smooth = t => t * t * (3 - 2 * t);
const smoother = t => t * t * t * (t * (t * 6 - 15) + 10);
const range = (v, a, b) => smooth(inv(v, a, b));
const DEG = Math.PI / 180;

const $ = s => document.querySelector(s);
const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

/* ---------- dom ---------- */
const dom = {
  stage:      $('.stage'),
  canvas:     $('#gl'),
  hero:       $('#hero'),
  hint:       $('#scrollhint'),
  catHead:    $('#catHead'),
  layer:      $('#screenLayer'),
  box:        $('#screenBox'),
  scrUi:      $('#scrUi'),
  bg:         $('.stage__bg-img'),
  hdr:        $('#hdr'),
  loader:     $('#loader'),
  loaderBar:  $('#loaderBar'),
};

/* ============================================================
   1.  three.js scene
   ============================================================ */
const renderer = new THREE.WebGLRenderer({
  canvas: dom.canvas, antialias: true, alpha: true, powerPreference: 'high-performance',
});
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.15;

const scene  = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 400);

/* studio env for believable metal / glass */
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.5;

/* brand rim lights */
const key = new THREE.DirectionalLight(0xffffff, 2.1); key.position.set(3.5, 6, 5);   scene.add(key);
const vio = new THREE.PointLight(0x8b5cf6, 90, 40, 2);  vio.position.set(-5, 2.5, 3);  scene.add(vio);
const pnk = new THREE.PointLight(0xff4fd8, 44, 40, 2);  pnk.position.set(5, 1.2, -3.5); scene.add(pnk);
const blu = new THREE.PointLight(0x4f7dff, 72, 40, 2);  blu.position.set(-1.5, -2.2, 5); scene.add(blu);
scene.add(new THREE.AmbientLight(0xa9b4ff, 0.55));

/* ============================================================
   2.  model state
   ============================================================ */
const M = {
  ready: false,
  root: null,          // recentred wrapper we scale
  model: null,
  mixer: null,
  clip: null,
  action: null,
  screen: null,        // Screen_Content mesh
  overlay: null,       // dark UI plane pinned on the screen
  mats: [],            // [{m, o}] unique materials + base opacity
  radius: 4,
  corners: [],         // 4 local-space corners of the display
};

const CORNER = new THREE.Vector3();
const projected = { x: 0, y: 0, w: 0, h: 0, ok: false };

function darkScreenTexture() {
  const c = document.createElement('canvas');
  c.width = 1024; c.height = 576;
  const g = c.getContext('2d');
  g.fillStyle = '#0a0616'; g.fillRect(0, 0, c.width, c.height);
  let r = g.createRadialGradient(190, 40, 10, 190, 40, 700);
  r.addColorStop(0, 'rgba(123,63,242,.55)'); r.addColorStop(1, 'rgba(123,63,242,0)');
  g.fillStyle = r; g.fillRect(0, 0, c.width, c.height);
  r = g.createRadialGradient(940, 560, 10, 940, 560, 640);
  r.addColorStop(0, 'rgba(255,79,216,.42)'); r.addColorStop(1, 'rgba(255,79,216,0)');
  g.fillStyle = r; g.fillRect(0, 0, c.width, c.height);
  g.strokeStyle = 'rgba(255,255,255,.045)'; g.lineWidth = 1;
  for (let x = 0; x < c.width; x += 64) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, c.height); g.stroke(); }
  for (let y = 0; y < c.height; y += 64) { g.beginPath(); g.moveTo(0, y); g.lineTo(c.width, y); g.stroke(); }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

new GLTFLoader().load(
  './asus_rog_animated.glb',
  gltf => { build(gltf); },
  ev => {
    if (ev.lengthComputable && dom.loaderBar) {
      dom.loaderBar.style.width = (ev.loaded / ev.total * 100).toFixed(0) + '%';
    }
  },
  err => { console.error('GLB load failed', err); fail(); }
);

/* graceful degradation: no WebGL / no 3D file → the cards simply appear as a section */
let failed = false;
function fail() {
  failed = true;
  dom.canvas.style.display = 'none';
  if (location.protocol === 'file:' && dom.loader) {
    dom.loader.innerHTML =
      '<p style="max-width:34ch;text-align:center;line-height:1.6;color:#c3bade">' +
      'Страница открыта напрямую из файла, поэтому браузер не даёт загрузить 3D-модель.<br><br>' +
      'Запустите <b>start.bat</b> из папки проекта — сайт откроется на локальном сервере.</p>';
    return;
  }
  finishLoading();
  update(true);
}

function build(gltf) {
  const model = gltf.scene;

  /* --- animation: t=0 closed, t=duration open --- */
  M.mixer  = new THREE.AnimationMixer(model);
  M.clip   = gltf.animations.find(a => /lid/i.test(a.name)) || gltf.animations[0];
  M.action = M.mixer.clipAction(M.clip);
  M.action.play();
  M.action.paused = true;
  M.action.time = 0;
  M.mixer.update(0);

  /* --- collect materials for the dissolve --- */
  const seen = new Set();
  model.traverse(o => {
    if (!o.isMesh) return;
    o.castShadow = o.receiveShadow = false;
    const list = Array.isArray(o.material) ? o.material : [o.material];
    list.forEach(m => {
      if (!m || seen.has(m.uuid)) return;
      seen.add(m.uuid);
      M.mats.push({ m, o: m.opacity ?? 1 });
    });
  });

  /* --- recentre on the OPEN pose so the composition never drifts --- */
  M.action.time = M.clip.duration; M.mixer.update(0);
  const box = new THREE.Box3().setFromObject(model);
  const c   = box.getCenter(new THREE.Vector3());
  const s   = box.getSize(new THREE.Vector3());
  M.radius  = Math.max(s.x, s.y, s.z) * 0.5;

  const root = new THREE.Group();
  model.position.sub(c);
  root.add(model);
  scene.add(root);
  M.root = root; M.model = model;

  /* --- the display panel --- */
  const screen = model.getObjectByName('Screen_Content');
  M.screen = screen;
  const sm = Array.isArray(screen.material) ? screen.material[0] : screen.material;
  M.mats.forEach(r => { if (r.m === sm) r.wall = true; });
  screen.geometry.computeBoundingBox();
  const bb = screen.geometry.boundingBox;
  /* the panel is a flat quad: find its two spanning axes */
  const size = bb.getSize(new THREE.Vector3());
  const axes = [['x', size.x], ['y', size.y], ['z', size.z]].sort((a, b) => b[1] - a[1]);
  const [a1, a2, flat] = [axes[0][0], axes[1][0], axes[2][0]];
  const mid = bb.getCenter(new THREE.Vector3());
  M.corners = [[bb.min[a1], bb.min[a2]], [bb.max[a1], bb.min[a2]],
               [bb.min[a1], bb.max[a2]], [bb.max[a1], bb.max[a2]]].map(([u, v]) => {
    const p = new THREE.Vector3();
    p[a1] = u; p[a2] = v; p[flat] = mid[flat];
    return p;
  });

  SCREEN_AR = size[a1] / size[a2];

  /* --- dark UI plane pinned right on the display --- */
  const geo = new THREE.PlaneGeometry(size[a1], size[a2]);
  const mat = new THREE.MeshBasicMaterial({
    map: darkScreenTexture(), transparent: true, opacity: 0,
    side: THREE.DoubleSide, depthWrite: false, toneMapped: false,
  });
  const plane = new THREE.Mesh(geo, mat);
  /* PlaneGeometry lives in XY — rotate it into the panel's own plane */
  if (flat === 'y') plane.rotation.x = -Math.PI / 2;
  else if (flat === 'x') plane.rotation.y = Math.PI / 2;
  plane.position.copy(mid);
  plane.renderOrder = 5;
  screen.add(plane);
  M.overlay = plane;

  /* push it a hair towards the viewer so it never z-fights */
  screen.updateWorldMatrix(true, false);
  const n = new THREE.Vector3(); n[flat] = 1;
  n.transformDirection(screen.matrixWorld);
  const toCam = new THREE.Vector3(0, 0, 1);          // camera ends up on +Z
  plane.position[flat] = mid[flat] + (n.dot(toCam) >= 0 ? 0.004 : -0.004);

  M.action.time = 0; M.mixer.update(0);
  M.ready = true;
  resize();
  update(true);
  renderer.render(scene, camera);
  finishLoading();
}

function finishLoading() {
  requestAnimationFrame(() => {
    dom.loader.classList.add('is-done');
    document.body.classList.add('is-loaded');
  });
}

/* ============================================================
   3.  layout maths
   ============================================================ */
let vw = 0, vh = 0, mobile = false;
const design = { w: 1280, h: 720, hEnd: 720 };
let SCREEN_AR = 16 / 9;   // real aspect of the laptop panel, measured from the mesh

function resize() {
  vw = innerWidth; vh = dom.stage ? dom.stage.querySelector('.stage__sticky').clientHeight : innerHeight;
  mobile = vw < 760;
  design.w = mobile ? 640 : 1280;
  design.h = Math.round(design.w / SCREEN_AR);      // always matches the panel
  design.hEnd = mobile ? Math.round(design.w * 1.16) : design.h;
  dom.box.style.width  = design.w + 'px';
  dom.box.style.height = design.h + 'px';

  renderer.setSize(vw, vh, false);
  camera.aspect = vw / vh;
  camera.updateProjectionMatrix();
  update(true);
  if (M.ready) renderer.render(scene, camera);
}

/* where the cards end up once the laptop has dissolved */
function finalState() {
  const pad = Math.min(72, Math.max(18, vw * 0.044));
  const w = Math.min(1300, vw - pad * 2);
  const s = w / design.w;
  const boxH = Math.min(design.hEnd, (vh * 0.74) / s);
  return { x: (vw - w) / 2, y: vh * 0.5 - boxH * s * 0.5 + vh * 0.06, s, boxH };
}

/* project the display quad into CSS pixels */
function projectScreen() {
  if (!M.ready) return false;
  M.screen.updateWorldMatrix(true, false);
  let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
  for (const p of M.corners) {
    CORNER.copy(p).applyMatrix4(M.screen.matrixWorld).project(camera);
    const x = (CORNER.x * 0.5 + 0.5) * vw;
    const y = (-CORNER.y * 0.5 + 0.5) * vh;
    minX = Math.min(minX, x); maxX = Math.max(maxX, x);
    minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  projected.x = minX; projected.y = minY;
  projected.w = maxX - minX; projected.h = maxY - minY;
  projected.ok = projected.w > 4 && projected.h > 4;
  return projected.ok;
}

/* ============================================================
   4.  the scroll timeline
   ============================================================ */
const T = {
  openA: 0.10, openB: 0.52,     // lid opens
  camA:  0.02, camB:  0.56,     // orbit to the front
  heroA: 0.02, heroB: 0.17,     // hero copy leaves
  uiA:   0.46, uiB:  0.60,      // screen turns into our dark UI
  cardA: 0.50, cardB: 0.63,     // cards appear on the display
  blowA: 0.64, blowB: 1.00,     // frame expands past the viewport
  fadeA: 0.68, fadeB: 0.93,     // …and dissolves
  morfA: 0.66, morfB: 0.96,     // cards leave the display
  chrmA: 0.70, chrmB: 0.88,     // screen chrome disappears
  headA: 0.86, headB: 1.00,     // catalog heading arrives
  HOLD:  0.88,                  // last 12% of the track: nothing moves
};

/* camera orbit: start behind-left, low, at the hinge corner → end straight on */
const CAM = {
  az0: 204 * DEG, az1: 360 * DEG, // near hinge corner on the left → sweep round to straight on
  el0: 6.5 * DEG, el1: 3.5 * DEG,
  d0: 1.95,       d1: 1.90,
  bump: 0.42,                     // keeps the laptop in frame mid-sweep
  ty0: 0.13,      ty1: -0.02,
};

let progress = -1;
const tmpTarget = new THREE.Vector3();

function stageProgress() {
  const rect = dom.stage.getBoundingClientRect();
  const total = dom.stage.offsetHeight - vh;
  if (total <= 0) return 0;
  return clamp((-rect.top) / total / T.HOLD);
}

function update(force) {
  const p = stageProgress();
  if (!force && Math.abs(p - progress) < 0.00015) return false;
  progress = p;

  /* ---- hero copy ---- */
  const hp = range(p, T.heroA, T.heroB);
  dom.hero.style.opacity = String(1 - hp);
  dom.hero.style.transform = `translate3d(0,${(-70 * hp).toFixed(1)}px,0)`;
  dom.hero.style.visibility = hp > 0.99 ? 'hidden' : 'visible';
  dom.hint.style.opacity = String(1 - range(p, 0.01, 0.07));

  /* ---- background drifts back and darkens ---- */
  const bp = range(p, 0, 0.7);
  dom.bg.style.transform = `scale(${(1.06 + bp * 0.16).toFixed(3)}) translate3d(0,${(-vh * 0.06 * bp).toFixed(0)}px,0)`;
  dom.bg.style.opacity = String(1 - bp * 0.55);

  /* ---- catalog heading ---- */
  const chp = range(p, T.headA, T.headB);
  dom.catHead.style.opacity = String(chp);
  dom.catHead.style.transform = `translate3d(0,${(24 * (1 - chp)).toFixed(1)}px,0)`;

  if (!M.ready) {
    if (failed) {                       // static fallback layout
      const f = finalState();
      const vis2 = range(p, 0.12, 0.3);
      dom.box.style.opacity = String(vis2);
      dom.box.style.height = f.boxH + 'px';
      dom.box.style.transform = `translate3d(${f.x}px,${f.y}px,0) scale(${f.s})`;
      dom.scrUi.style.setProperty('--scr-chrome', '0');
      dom.catHead.style.opacity = String(range(p, 0.12, 0.3));
    }
    return true;
  }

  /* ---- lid ---- */
  const op = smoother(inv(p, T.openA, T.openB));
  M.action.time = op * M.clip.duration;
  M.mixer.update(0);

  /* ---- camera orbit ---- */
  const cp = smoother(inv(p, T.camA, T.camB));
  const az = lerp(CAM.az0, CAM.az1, cp);
  const el = lerp(CAM.el0, CAM.el1, cp);
  let dd = (lerp(CAM.d0, CAM.d1, cp) + CAM.bump * Math.sin(Math.PI * cp)) * M.radius * 2;
  /* make sure the whole machine fits on tall/narrow viewports */
  const hfov = 2 * Math.atan(Math.tan(camera.fov * DEG / 2) * camera.aspect);
  dd = Math.max(dd, (M.radius * 0.92) / Math.tan(hfov / 2));
  const ty = lerp(CAM.ty0, CAM.ty1, cp) * M.radius;
  camera.position.set(
    Math.sin(az) * Math.cos(el) * dd,
    Math.sin(el) * dd + ty,
    Math.cos(az) * Math.cos(el) * dd
  );
  tmpTarget.set(0, ty * 0.4, 0);
  camera.lookAt(tmpTarget);
  camera.updateMatrixWorld(true);

  /* ---- the frame blows up past the viewport, then dissolves ---- */
  const bl = smooth(inv(p, T.blowA, T.blowB));
  const sc = lerp(1, 4.2, bl * bl);
  M.root.scale.setScalar(sc);
  M.root.position.y = -ty * 0.15 * sc;

  const alpha = 1 - smooth(inv(p, T.fadeA, T.fadeB));
  const wall = 1 - range(p, T.uiA - 0.02, T.uiB - 0.02);   // stock ROG wallpaper
  for (const rec of M.mats) {
    const want = rec.o * alpha * (rec.wall ? wall : 1);
    rec.m.transparent = alpha < 0.999 ? true : rec.m.userData.__t ?? false;
    rec.m.opacity = want;
    rec.m.depthWrite = alpha > 0.98;
  }
  M.root.visible = alpha > 0.004;

  /* ---- our dark UI on the panel ---- */
  M.overlay.material.opacity = range(p, T.uiA, T.uiB) * alpha;

  /* keep matrices fresh for the projection below */
  M.root.updateMatrixWorld(true);

  /* ---- the cards ---- */
  const vis = range(p, T.cardA, T.cardB);
  dom.box.style.opacity = String(vis);
  dom.layer.style.pointerEvents = vis > 0.9 ? 'none' : 'none';
  dom.scrUi.style.setProperty('--scr-chrome', String(1 - range(p, T.chrmA, T.chrmB)));
  dom.scrUi.style.setProperty('--scr-r', (10 + 8 * range(p, T.chrmA, T.chrmB)) + 'px');

  if (vis > 0.001) {
    const ok = projectScreen();
    const f = finalState();
    const m = smoother(inv(p, T.morfA, T.morfB));
    const s0 = ok ? projected.w / design.w : f.s;
    const x0 = ok ? projected.x : f.x;
    const y0 = ok ? projected.y : f.y;
    const sc = lerp(s0, f.s, m);
    const bh = lerp(design.h, f.boxH, m);
    /* keep the box vertically centred on whatever it is pinned to */
    const y = lerp(y0 - (bh - design.h) * s0 * 0.5, f.y, m);
    const x = lerp(x0, f.x, m);
    dom.box.style.height = bh.toFixed(1) + 'px';
    dom.box.style.transform =
      `translate3d(${x.toFixed(1)}px,${y.toFixed(1)}px,0) scale(${sc.toFixed(4)})`;
  }
  return true;
}

/* ============================================================
   5.  loop
   ============================================================ */
let running = true;
function tick() {
  requestAnimationFrame(tick);
  if (!running) return;
  const rect = dom.stage.getBoundingClientRect();
  const onScreen = rect.bottom > -80 && rect.top < vh + 80;
  const changed = update(false);
  if (M.ready && onScreen && changed) renderer.render(scene, camera);
}

addEventListener('resize', () => { resize(); if (M.ready) renderer.render(scene, camera); }, { passive: true });
addEventListener('scroll', () => {
  if (M.ready && update(false)) renderer.render(scene, camera);
}, { passive: true });

resize();
tick();

/* ============================================================
   6.  page chrome
   ============================================================ */
/* header background */
const onScroll = () => dom.hdr.classList.toggle('is-stuck', scrollY > 40);
addEventListener('scroll', onScroll, { passive: true }); onScroll();

/* "Каталог" jumps to the moment the cards are fully formed */
document.querySelectorAll('a[href="#catalog"]').forEach(a => {
  a.addEventListener('click', e => {
    e.preventDefault();
    const top = dom.stage.offsetTop + (dom.stage.offsetHeight - vh) * T.HOLD * 0.99;
    scrollTo({ top, behavior: reduced ? 'auto' : 'smooth' });
  });
});

/* reveal on scroll — plain rect test, no IntersectionObserver surprises */
const revealables = [];
document.querySelectorAll(
  '.about__panel, .about__photo, .stat, .why__item, .b2b__left, .b2b__right, .sect__head, .lead__form, .map__info, .map__canvas'
).forEach((el, i) => { el.classList.add('rv'); el.style.transitionDelay = (i % 6) * 55 + 'ms'; revealables.push(el); });

function reveal() {
  const h = innerHeight;
  for (let i = revealables.length - 1; i >= 0; i--) {
    const el = revealables[i];
    const r = el.getBoundingClientRect();
    if (r.top < h * 0.92 && r.bottom > 0) {
      el.classList.add('is-in');
      revealables.splice(i, 1);
    }
  }
}
addEventListener('scroll', reveal, { passive: true });
addEventListener('resize', reveal, { passive: true });
reveal();

/* phone mask + form */
const phone = document.querySelector('input[name="phone"]');
if (phone) phone.addEventListener('input', () => {
  let d = phone.value.replace(/\D/g, '');
  if (d.startsWith('8')) d = '7' + d.slice(1);
  if (!d.startsWith('7')) d = '7' + d;
  d = d.slice(0, 11);
  let out = '+7';
  if (d.length > 1) out += ' (' + d.slice(1, 4);
  if (d.length >= 5) out += ') ' + d.slice(4, 7);
  if (d.length >= 8) out += '-' + d.slice(7, 9);
  if (d.length >= 10) out += '-' + d.slice(9, 11);
  phone.value = out;
});

const form = $('#leadForm');
if (form) form.addEventListener('submit', e => {
  e.preventDefault();
  if (!form.name.value.trim() || form.phone.value.replace(/\D/g, '').length < 11) {
    form.reportValidity?.();
    return;
  }
  $('#leadOk').hidden = false;
  form.querySelector('button').textContent = 'Отправлено';
  /* TODO: подключите свой обработчик / CRM здесь */
});

/* burger → simple anchor sheet */
const burger = $('#burger');
if (burger) burger.addEventListener('click', () => location.hash = '#catalog');
