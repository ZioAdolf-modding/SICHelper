// SICHelper short - nucleul: constante, matematica, easing, text, iconite, efecte
'use strict';

const W = 1080, H = 1920, FPS = 30, DURATION = 60;

// paleta helperului (tema "si" din SICHelper.lua + culorile din chat)
const C = {
  primary: '#00D96A', accent: '#6EF2AC', selBg: '#133326', selBorder: '#1F8A55',
  idleBg: '#151C18', idleBorder: '#24352C', idleText: '#9BB5A8',
  si: '#10FF78', text: '#E4E9EC', dim: '#97A3AB', amber: '#E0C24A', red: '#E06A64',
  okGreen: '#5FBF77', blue: '#7FB8FF',
  chatDim: '#B4BCC4', chatCmd: '#9ED0FF', money: '#F2C56B', err: '#FF5050',
  winBg: 'rgba(11,15,17,0.94)', surface: 'rgba(14,20,24,0.88)', dark: '#0E1418',
  jarvis: '#6EF2AC', jarvisDeep: '#00D96A',
};

// ---------- matematica ----------
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, t) => a + (b - a) * t;
const seg = (t, a, b) => clamp((t - a) / (b - a));
const TAU = Math.PI * 2;
const E = {
  lin: x => x,
  inQuad: x => x * x,
  outQuad: x => 1 - (1 - x) * (1 - x),
  inOutQuad: x => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2),
  inCubic: x => x * x * x,
  outCubic: x => 1 - Math.pow(1 - x, 3),
  inOutCubic: x => (x < 0.5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2),
  outQuart: x => 1 - Math.pow(1 - x, 4),
  outExpo: x => (x >= 1 ? 1 : 1 - Math.pow(2, -10 * x)),
  inExpo: x => (x <= 0 ? 0 : Math.pow(2, 10 * x - 10)),
  inOutExpo: x => (x <= 0 ? 0 : x >= 1 ? 1 : x < 0.5 ? Math.pow(2, 20 * x - 10) / 2 : (2 - Math.pow(2, -20 * x + 10)) / 2),
  outBack: x => { const c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); },
  outBackBig: x => { const c1 = 2.6, c3 = c1 + 1; return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2); },
  outElastic: x => (x <= 0 ? 0 : x >= 1 ? 1 : Math.pow(2, -10 * x) * Math.sin((x * 10 - 0.75) * (TAU / 3)) + 1),
};
// anvelopa: 0 inainte de a, 1 intre a+fin si b-fout, 0 dupa b
function env(t, a, b, fin = 0.25, fout = 0.25) {
  if (t < a || t > b) return 0;
  let v = 1;
  if (fin > 0) v = Math.min(v, (t - a) / fin);
  if (fout > 0) v = Math.min(v, (b - t) / fout);
  return clamp(v);
}
// zgomot determinist
function mulberry32(seed) {
  return function () {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hash1(n) { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); }
function noise1(x) { const i = Math.floor(x), f = x - i; const u = f * f * (3 - 2 * f); return lerp(hash1(i), hash1(i + 1), u) * 2 - 1; }

function hexA(hex, a) {
  const h = hex.replace('#', '');
  const r = parseInt(h.slice(0, 2), 16), g = parseInt(h.slice(2, 4), 16), b = parseInt(h.slice(4, 6), 16);
  return `rgba(${r},${g},${b},${a})`;
}
function mixHex(h1, h2, t) {
  const p = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
  const a = p(h1), b = p(h2);
  const c = a.map((v, i) => Math.round(lerp(v, b[i], t)));
  return '#' + c.map(v => v.toString(16).padStart(2, '0')).join('');
}

// ---------- canvas ----------
function makeCanvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return c;
}
function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
}
function fillRR(ctx, x, y, w, h, r, fill) { rr(ctx, x, y, w, h, r); ctx.fillStyle = fill; ctx.fill(); }
function strokeRR(ctx, x, y, w, h, r, stroke, lw = 1) { rr(ctx, x, y, w, h, r); ctx.strokeStyle = stroke; ctx.lineWidth = lw; ctx.stroke(); }
function glow(ctx, color, blur) { ctx.shadowColor = color; ctx.shadowBlur = blur; ctx.shadowOffsetX = 0; ctx.shadowOffsetY = 0; }
function noGlow(ctx) { ctx.shadowColor = 'transparent'; ctx.shadowBlur = 0; }
function line(ctx, x1, y1, x2, y2, color, lw = 1) {
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2);
  ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.stroke();
}
function circle(ctx, x, y, r, fill) { ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fillStyle = fill; ctx.fill(); }
function ring(ctx, x, y, r, color, lw, a0 = 0, a1 = TAU) { ctx.beginPath(); ctx.arc(x, y, r, a0, a1); ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.stroke(); }

// ---------- text ----------
const F = {
  ui: (s, w = 500) => `${w} ${s}px Inter`,
  hud: (s, w = 600) => `${w} ${s}px Rajdhani`,
  mono: (s, w = 500) => `${w} ${s}px "JetBrains Mono"`,
  chat: s => `700 ${s}px Arimo`,
  cap: (s, w = 800) => `${w} ${s}px Inter`,
  big: s => `400 ${s}px Anton`,
  icon: s => `900 ${s}px FA6`,
};
function text(ctx, s, x, y, o = {}) {
  ctx.font = o.font || F.ui(16);
  ctx.textAlign = o.align || 'left';
  ctx.textBaseline = o.base || 'alphabetic';
  if (o.ls !== undefined) ctx.letterSpacing = o.ls + 'px'; else ctx.letterSpacing = '0px';
  if (o.stroke) {
    ctx.lineJoin = 'round';
    ctx.strokeStyle = o.stroke; ctx.lineWidth = o.sw || 3;
    ctx.strokeText(s, x, y);
  }
  if (o.shadow) { ctx.fillStyle = o.shadow; ctx.fillText(s, x + (o.sdx ?? 1), y + (o.sdy ?? 1)); }
  ctx.fillStyle = o.color || C.text;
  ctx.fillText(s, x, y);
  ctx.letterSpacing = '0px';
}
function tw(ctx, s, font, ls) { ctx.font = font; ctx.letterSpacing = (ls || 0) + 'px'; const w = ctx.measureText(s).width; ctx.letterSpacing = '0px'; return w; }

// text cu coduri de culoare SA-MP: "{RRGGBB}"
function parseColored(s, base = '#FFFFFF') {
  const out = [];
  let color = base, i = 0, buf = '';
  while (i < s.length) {
    if (s[i] === '{' && s[i + 7] === '}' && /^[0-9a-fA-F]{6}$/.test(s.slice(i + 1, i + 7))) {
      if (buf) { out.push({ c: color, s: buf }); buf = ''; }
      color = '#' + s.slice(i + 1, i + 7);
      i += 8;
    } else { buf += s[i]; i++; }
  }
  if (buf) out.push({ c: color, s: buf });
  return out;
}
// imparte segmentele colorate pe randuri de latime maxima (cuvant cu cuvant)
function wrapColored(ctx, segs, font, maxW) {
  ctx.font = font;
  const words = [];
  for (const sg of segs) {
    const parts = sg.s.split(/(\s+)/);
    for (const p of parts) if (p) words.push({ c: sg.c, s: p });
  }
  const lines = [[]];
  let w = 0;
  for (const wd of words) {
    const ww = ctx.measureText(wd.s).width;
    const isSpace = /^\s+$/.test(wd.s);
    if (!isSpace && w + ww > maxW && lines[lines.length - 1].length) {
      lines.push([]); w = 0;
    }
    if (isSpace && w === 0) continue;
    lines[lines.length - 1].push(wd); w += ww;
  }
  return lines;
}
function drawColoredLine(ctx, words, x, y, font, o = {}) {
  ctx.font = font; ctx.textAlign = 'left'; ctx.textBaseline = o.base || 'alphabetic';
  let cx = x;
  for (const wd of words) {
    const ww = ctx.measureText(wd.s).width;
    if (o.stroke) { ctx.lineJoin = 'round'; ctx.strokeStyle = o.stroke; ctx.lineWidth = o.sw || 3; ctx.strokeText(wd.s, cx, y); }
    ctx.fillStyle = wd.c; ctx.fillText(wd.s, cx, y);
    cx += ww;
  }
  return cx - x;
}

// ---------- iconite Font Awesome 6 (solid) ----------
const ICON = {
  helicopter: '', ship: '', fish: '', gun: '', boxes: '', crown: '',
  cap: '', circleCheck: '', check: '', xmark: '', warn: '', crosshair: '',
  clipList: '', userPlus: '', chart: '', gear: '', note: '', idCard: '',
  user: '', car: '', sms: '', clipCheck: '', search: '', bell: '',
  mobile: '', plane: '', route: '', pin: '', camera: '', bolt: '',
  terminal: '', keyboard: '', certificate: '', star: '', circle: '',
  signal: '', wifi: '', eye: '', lock: '', minus: '', plus: '',
  hourglass: '', cursor: '', handPointer: '', play: '', ban: '',
};
function icon(ctx, name, x, y, size, color, align = 'center', base = 'middle') {
  ctx.font = F.icon(size); ctx.textAlign = align; ctx.textBaseline = base;
  ctx.fillStyle = color; ctx.fillText(ICON[name] || name, x, y);
}

// ---------- licentele (SICHelper.lua: Licenses.list) ----------
const LICS = [
  { id: 'flying', server: 'Flying', label: 'Flying', short: 'Fly', icon: 'helicopter', dialog: 'Licenta de pilot', status: 'Expirata' },
  { id: 'sailing', server: 'Sailing', label: 'Sailing', short: 'Sail', icon: 'ship', dialog: 'Licenta de navigatie', status: 'Expirata' },
  { id: 'fishing', server: 'Fishing', label: 'Fishing', short: 'Fish', icon: 'fish', dialog: 'Licenta de pescar', status: 'Expirata' },
  { id: 'weapons', server: 'Weapon', label: 'Weapons', short: 'Weap', icon: 'gun', dialog: 'Permis de port-arma', status: 'Expirat' },
  { id: 'materials', server: 'Materials', label: 'Materials', short: 'Mat', icon: 'boxes', dialog: 'Licenta de materiale', status: 'Expirata' },
];
const ALL_LIC = { id: 'all', short: 'All', icon: 'crown' };

// ---------- personaje si date ----------
const CAND = { name: '[XO]Stroe', id: 27, level: 54 };
const INSTR = { name: '[XO]ZioAdolf', id: 14 };
// preturile de la 50+ (SICHelper_data.lua, "high"): 3600 + 3400 + 1000 + 4000 + 3200
const TOTAL_50 = '$15.200';

// ---------- efecte post ----------
let GRAIN = [];
function initGrain() {
  const rnd = mulberry32(1234);
  for (let k = 0; k < 6; k++) {
    const c = makeCanvas(256, 256), g = c.getContext('2d');
    const img = g.createImageData(256, 256);
    for (let i = 0; i < img.data.length; i += 4) {
      const v = Math.floor(rnd() * 255);
      img.data[i] = img.data[i + 1] = img.data[i + 2] = v; img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    GRAIN.push(c);
  }
}
function drawGrain(ctx, t, alpha = 0.05) {
  const g = GRAIN[Math.floor(t * FPS) % GRAIN.length];
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.globalCompositeOperation = 'overlay';
  const pat = ctx.createPattern(g, 'repeat');
  ctx.fillStyle = pat;
  ctx.fillRect(0, 0, W, H);
  ctx.restore();
}
function drawVignette(ctx, strength = 0.55) {
  const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.25, W / 2, H / 2, H * 0.72);
  g.addColorStop(0, 'rgba(0,0,0,0)');
  g.addColorStop(1, `rgba(0,0,0,${strength})`);
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
}

// cursorul de mouse (sageata)
function drawCursor(ctx, x, y, s = 1.6, press = 0) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(s * (1 - press * 0.12), s * (1 - press * 0.12));
  ctx.beginPath();
  ctx.moveTo(0, 0); ctx.lineTo(0, 22); ctx.lineTo(5.5, 17); ctx.lineTo(9.5, 26); ctx.lineTo(13, 24.5); ctx.lineTo(9, 16); ctx.lineTo(16, 16); ctx.closePath();
  ctx.fillStyle = '#fff'; ctx.fill();
  ctx.strokeStyle = '#000'; ctx.lineWidth = 1.5; ctx.stroke();
  ctx.restore();
  if (press > 0) {
    ctx.save();
    ctx.globalAlpha = press * 0.8;
    ring(ctx, x, y, 10 + (1 - press) * 40, C.accent, 3);
    ctx.restore();
  }
}

// imaginile (skinurile si logo-ul) se incarca o singura data
const IMG = {};
function loadImage(key, src) {
  return new Promise(res => {
    const im = new Image();
    im.onload = () => { IMG[key] = im; res(); };
    im.onerror = () => { IMG[key] = null; res(); };
    im.src = src;
  });
}
