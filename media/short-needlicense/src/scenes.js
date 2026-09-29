// SICHelper short - scenariul de 60 s: scene, tranzitii, subtitrari, indicii de sunet
'use strict';

// ============================================================
// MOMENTELE CHEIE (secunde) - aceleasi si pentru sunet (audio.py citeste cues.json)
// ============================================================
const T = {
  typeA: 0.8, enterA: 2.45, signal: 2.6, fly: 3.7,
  cardIn: 6.05, accept: 6.95, cpSet: 7.2, walkB: 8.2, unlock: 9.5, sms: 10.15, zoomB: 11.35,
  bootC: 12.0, tabs0: 13.7, infoC: 16.5, reportC: 18.2, checkC: 19.4, lockC: 20.6, zoomC: 21.55,
  driveA: 22.4, driveB: 31.2, zoomD: 31.4,
  carIn: 32.0, carStop: 33.0, exit: 33.25, salut: 34.45, rl: 35.95, dialog: 36.8,
  scan0: 38.5, scanStep: 0.75, verdict: 42.3,
  wmIn: 44.1, clickAll: 45.8, clickOk: 47.0, shot: 47.25, fLine: 47.5, memo: 47.9,
  sicIn: 50.05, clickGive: 51.2, chain0: 51.45, chainStep: 1.2, chainAcc: 0.75, done: 57.2,
  outro: 58.0,
};
const CHAIN_SEND = LICS.map((_, i) => T.chain0 + i * T.chainStep);
const CHAIN_ACC = CHAIN_SEND.map(s => s + T.chainAcc);

// ============================================================
// CHATUL INSTRUCTORULUI (textele reale ale helperului, SICHelper.lua)
// ============================================================
const SI = '{10FF78}', WH = '{FFFFFF}', DM = '{B4BCC4}', CM = '{9ED0FF}';
const TAGSIC = SI + '[SIC] ' + WH;
const NT = `${SI}${CAND.name} (${CAND.id})${WH}`;
const INSTR_CHAT = [
  { t0: T.cardIn, s: `${TAGSIC}${NT} are nevoie de licente (nivel ${CAND.level}). ${DM}Accepta cu tasta ${CM}F2${DM} sau din /sic.` },
  { t0: T.sms, s: `${TAGSIC}SMS de confirmare trimis lui ${NT}.` },
  { t0: T.salut + 0.45, s: `${TAGSIC}Trimis pe /w lui ${NT}: Salut, ${CAND.name}! Arata-mi te rog licentele si spune-mi de ce ai nevoie.` },
  { t0: T.fLine, s: `${TAGSIC}Trimis pe /f: ${CAND.name} (${CAND.id}) is with me for all licenses. He is level 50+.` },
  { t0: T.chain0 + 0.1, s: `${TAGSIC}Astept sa accepte ${NT}, apoi continui cu: Sail, Fish, Weap, Mat` },
  ...LICS.map((l, i) => ({ t0: CHAIN_ACC[i], s: `{A9D6FF}You gave a ${l.server} License to ${CAND.name}` })),
  { t0: T.done, s: `${TAGSIC}Toate licentele din /withme au fost date.` },
];
function chatInstr(ctx, t, o = {}) {
  sampChat(ctx, 34, o.y || 168, INSTR_CHAT, t, { size: o.size || 27, maxRows: o.rows || 5, maxW: 1000, alpha: o.alpha });
}
// ce se scrie in campul de chat: [start, text, enter]
function chatTyping(ctx, t, start, s, enter, y) {
  if (t < start - 0.12 || t > enter + 0.05) return;
  const p = seg(t, start, enter - 0.12);
  sampInput(ctx, 44, y, typed(s, p + 0.001), t, { size: 29, w: 560, alpha: env(t, start - 0.12, enter + 0.05, 0.08, 0.05) });
}
// eticheta "comanda trimisa" (ce pleaca la server)
function cmdChip(ctx, x, y, s, p, o = {}) {
  if (p <= 0) return;
  const f = F.mono(o.size || 28, 700);
  const wdt = tw(ctx, s, f) + 70;
  const k = E.outBackBig(clamp(p * 1.6));
  ctx.save();
  ctx.globalAlpha *= clamp(p * 3) * (o.alpha ?? 1);
  ctx.translate(x, y); ctx.scale(k, k);
  const x0 = o.align === 'right' ? -wdt : o.align === 'center' ? -wdt / 2 : 0;
  glow(ctx, hexA(C.primary, 0.7), 20);
  fillRR(ctx, x0, -30, wdt, 60, 30, 'rgba(4,16,10,0.92)');
  noGlow(ctx);
  strokeRR(ctx, x0, -30, wdt, 60, 30, C.primary, 2.5);
  icon(ctx, 'plane', x0 + 32, 1, 22, C.accent);
  text(ctx, s, x0 + 54, 1, { font: f, color: '#EFFFF6', base: 'middle' });
  ctx.restore();
}

// ============================================================
// SUBTITRARI (stil shorts: mari, cu contur, cuvintele cheie colorate)
// ============================================================
const CAPS = [
  { a: 0.25, b: 2.5, s: `${CAND.name} are nevoie de licențe`, hl: ['licențe'] },
  { a: 2.6, b: 5.75, s: 'Scrie /needlicense și așteaptă', hl: ['/needlicense'] },
  { a: 6.15, b: 8.1, s: 'Instructorul primește cererea pe loc', hl: ['pe', 'loc'] },
  { a: 8.2, b: 11.3, s: 'O tastă: accept + SMS automat', hl: ['SMS', 'automat'] },
  { a: 12.35, b: 16.4, s: 'Aici intră în scenă SICHelper', hl: ['SICHelper'] },
  { a: 16.5, b: 21.5, s: 'Candidat, nivel, dovezi: totul pregătit', hl: ['totul', 'pregătit'] },
  { a: 22.3, b: 26.9, s: 'Drumul spre candidat', hl: ['candidat'] },
  { a: 27.0, b: 31.7, s: 'Legenda îți arată câți metri mai ai', hl: ['metri'] },
  { a: 32.3, b: 34.35, s: 'A ajuns la candidat', hl: ['ajuns'] },
  { a: 34.45, b: 35.85, s: '/salut: îi cere licențele', hl: ['/salut'] },
  { a: 35.95, b: 37.9, s: '/rl: licențele lui, pe ecran', hl: ['/rl'] },
  { a: 38.3, b: 42.2, s: 'Helperul citește fiecare licență', hl: ['citește'] },
  { a: 42.3, b: 43.95, s: 'Toate 5 sunt expirate', hl: ['expirate'], red: true },
  { a: 44.2, b: 47.0, s: '/withme: roșu = expirată', hl: ['/withme', 'roșu'] },
  { a: 47.1, b: 49.85, s: 'Anunț pe /f + /id pentru dovadă', hl: ['/f', '/id'] },
  { a: 50.3, b: 53.5, s: 'Un click: „Toate licentele”', hl: ['click'] },
  { a: 53.6, b: 56.95, s: 'Le trimite una câte una, după fiecare accept', hl: ['una', 'câte'] },
];
function drawCaptions(ctx, t) {
  for (const c of CAPS) {
    if (t < c.a || t > c.b) continue;
    const pin = E.outBackBig(seg(t, c.a, c.a + 0.22));
    const pout = seg(t, c.b - 0.12, c.b);
    const size = 62, font = F.cap(size, 900), lh = 76, maxW = 900;
    const words = c.s.split(' ');
    ctx.font = font;
    const lines = [[]]; let w = 0;
    for (const wd of words) {
      const ww = ctx.measureText(wd + ' ').width;
      if (w + ww > maxW && lines[lines.length - 1].length) { lines.push([]); w = 0; }
      lines[lines.length - 1].push(wd); w += ww;
    }
    const y0 = (c.y || 1490) - (lines.length - 1) * lh / 2;
    ctx.save();
    ctx.globalAlpha *= clamp(pin * 1.5) * (1 - pout);
    ctx.translate(W / 2, y0);
    const sc = (0.7 + 0.3 * pin) * (1 - pout * 0.1);
    ctx.scale(sc, sc);
    lines.forEach((ln, li) => {
      const full = ln.join(' ');
      const fw = ctx.measureText(full).width;
      let x = -fw / 2;
      const y = li * lh;
      for (const wd of ln) {
        const clean = wd.replace(/[.,:!?„”]/g, '');
        const isHl = c.hl && c.hl.includes(clean);
        const col = isHl ? (c.red ? '#FF5A55' : '#29F58C') : '#FFFFFF';
        ctx.lineJoin = 'round';
        ctx.strokeStyle = '#000'; ctx.lineWidth = 14;
        ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.letterSpacing = '0px';
        ctx.strokeText(wd, x, y);
        ctx.fillStyle = 'rgba(0,0,0,0.45)'; ctx.fillText(wd, x + 3, y + 5);
        ctx.fillStyle = col; ctx.fillText(wd, x, y);
        x += ctx.measureText(wd + ' ').width;
      }
    });
    ctx.restore();
  }
}

// ============================================================
// INDICII DE SUNET (exportate pentru audio.py)
// ============================================================
const CUES = [];
function cue(t, s, o = {}) { CUES.push(Object.assign({ t: +t.toFixed(3), s }, o)); }
(function buildCues() {
  cue(0.0, 'hit');
  cue(0.55, 'chatopen');
  '/needlicense'.split('').forEach((_, i) => cue(T.typeA + i * (T.enterA - 0.12 - T.typeA) / 12, 'key', { v: i }));
  cue(T.enterA, 'enter');
  cue(T.signal, 'signal');
  cue(T.fly, 'whooshUp');
  cue(5.75, 'whoosh', { g: 1.0 });
  cue(T.cardIn + 0.05, 'notif');
  cue(T.accept, 'keyBig');
  cue(T.accept + 0.15, 'send');
  cue(T.cpSet, 'blip', { f: 1320 });
  cue(T.unlock, 'unlock');
  cue(T.sms, 'sms');
  cue(T.zoomB, 'whooshBig');
  cue(T.bootC, 'impact');
  [0, 0.3, 0.6, 0.9].forEach(d => cue(T.bootC + 0.12 + d, 'typeBurst'));
  cue(13.25, 'whoosh', { g: 0.8 });
  for (let i = 0; i < 5; i++) cue(T.tabs0 + i * 0.5, 'tick', { v: i });
  cue(T.infoC, 'whoosh', { g: 0.8 }); cue(T.infoC + 0.15, 'scan', { d: 1.0 });
  cue(T.reportC, 'pop'); cue(T.reportC + 0.2, 'fill');
  cue(T.checkC, 'pop'); cue(T.checkC + 0.4, 'check', { v: 0 });
  cue(T.lockC, 'lock');
  cue(T.zoomC, 'whooshBig');
  cue(22.0, 'impact');
  cue(22.1, 'engine', { d: 9.3 });
  cue(24.4, 'skid', { g: 0.5 }); cue(27.9, 'skid', { g: 0.6 });
  cue(28.9, 'ping');
  cue(T.zoomD, 'whoosh', { g: 0.9 });
  cue(T.carIn, 'hitSoft');
  cue(T.carIn, 'engineIn', { d: 1.2 });
  cue(T.carStop - 0.4, 'brake');
  cue(T.exit, 'door');
  'salut'.split('').forEach((_, i) => cue(T.salut + 0.05 + i * 0.06, 'key', { v: i + 3 }));
  cue(T.salut + 0.4, 'enter'); cue(T.salut + 0.45, 'send');
  'rl'.split('').forEach((_, i) => cue(T.rl + 0.05 + i * 0.08, 'key', { v: i + 7 }));
  cue(T.rl + 0.3, 'enter'); cue(T.rl + 0.35, 'send');
  cue(T.dialog, 'dialog');
  cue(37.4, 'whoosh', { g: 0.7 });
  cue(38.05, 'scanStart');
  LICS.forEach((_, i) => { cue(T.scan0 + i * T.scanStep - 0.25, 'scan', { d: 0.3 }); cue(T.scan0 + i * T.scanStep, 'alert', { v: i }); });
  cue(T.verdict, 'stamp');
  cue(42.6, 'riser', { d: 1.4 });
  cue(44.0, 'glitch');
  cue(T.wmIn, 'pop');
  cue(44.6, 'alert', { v: 9, g: 0.5 });
  cue(T.clickAll, 'click'); cue(T.clickAll + 0.12, 'coins');
  cue(T.clickOk, 'click');
  cue(T.shot, 'shutter');
  cue(T.fLine, 'send');
  cue(T.memo, 'pop'); cue(48.9, 'whoosh', { g: 0.7 });
  cue(49.75, 'whoosh', { g: 1.0 });
  cue(T.sicIn, 'pop');
  cue(T.clickGive, 'click');
  CHAIN_SEND.forEach((s, i) => cue(s, 'sendCard', { v: i }));
  CHAIN_ACC.forEach((s, i) => cue(s, 'success', { v: i }));
  cue(T.done, 'finale');
  cue(T.outro, 'hit');
})();

// ============================================================
// EFECTE GLOBALE
// ============================================================
const FLASHES = [
  { t: 0.0, d: 0.35, a: 0.7 }, { t: 12.0, d: 0.5, a: 1 }, { t: 22.0, d: 0.45, a: 0.9 }, { t: 32.0, d: 0.35, a: 0.8 },
  { t: T.shot, d: 0.25, a: 0.5 }, { t: T.done, d: 0.4, a: 0.5 }, { t: 58.0, d: 0.5, a: 1 },
];
const SHAKES = [
  { t: 0.0, d: 0.3, a: 10 }, { t: 12.0, d: 0.5, a: 14 }, { t: 22.0, d: 0.4, a: 12 }, { t: T.verdict, d: 0.45, a: 16 },
  { t: T.carStop - 0.1, d: 0.3, a: 6 }, { t: T.done, d: 0.4, a: 10 }, { t: 58.0, d: 0.4, a: 10 },
];
const GLITCHES = [{ t: 44.0, d: 0.28 }, { t: 21.9, d: 0.1 }, { t: 37.95, d: 0.08 }];

// ============================================================
// SCENA A (0-6 s): strada, Stroe scrie /needlicense
// ============================================================
function sceneA(ctx, t) {
  const push = E.outExpo(seg(t, 0, 0.55));
  const cam = { x: lerp(-40, 30, seg(t, 0, 6)), zoom: lerp(1.22, 1.0, push) + seg(t, 0.5, 6) * 0.06 };
  // la final camera "priveste" in sus, dupa semnal
  const up = E.inCubic(seg(t, 4.6, 6.2));
  cam.y = -up * 900;
  drawStreet(ctx, cam, 0);
  worldBegin(ctx, cam);
  const typing = t > 0.5 && t < T.enterA;
  const pose = {
    t, headTurn: typing ? -0.35 : lerp(-0.35, 0.1, seg(t, T.enterA, T.enterA + 0.4)),
    headTilt: typing ? -0.06 : 0, brow: env(t, 0.3, 1.4, 0.15, 0.3) * 0.8,
    smile: seg(t, T.enterA, T.enterA + 0.3) * 0.5, nod: env(t, T.enterA, T.enterA + 0.5, 0.15, 0.3),
    armL: { s: 0.12, e: 0.1 }, armR: { s: 0.12 + env(t, 0.6, T.enterA, 0.2, 0.2) * 0.35, e: 0.08 + env(t, 0.6, T.enterA, 0.2, 0.2) * 1.9 },
    rim: '#ffb46b', rimA: 0.55,
  };
  const r = drawToon(ctx, STROE, 60, 30, 6.1, pose);
  ctx.restore();
  nameTag(ctx, r.headX, r.headY - 30, CAND.name, CAND.id, '#FFFFFF', 1.25);
  // semnalul /needlicense
  if (t > T.signal) {
    for (let k = 0; k < 3; k++) {
      const p = seg(t, T.signal + k * 0.28, T.signal + k * 0.28 + 1.3);
      if (p <= 0 || p >= 1) continue;
      ctx.save();
      ctx.globalAlpha = (1 - p) * 0.9;
      glow(ctx, C.primary, 20);
      ring(ctx, r.headX, r.headY + 60, 40 + E.outCubic(p) * 520, C.accent, 6 * (1 - p) + 1.5);
      noGlow(ctx);
      ctx.restore();
    }
    // "pachetul" care pleaca spre instructori
    const pp = seg(t, T.signal, T.signal + 0.35), fly = E.inCubic(seg(t, T.fly, T.fly + 1.1));
    const px = lerp(r.headX, W * 0.72, fly), py = lerp(r.headY - 110, -120, fly);
    ctx.save();
    ctx.globalAlpha = clamp(pp * 2);
    if (fly > 0) { // dara
      for (let k = 1; k < 7; k++) {
        const f2 = Math.max(0, fly - k * 0.035);
        ctx.globalAlpha = clamp(pp * 2) * (0.5 - k * 0.06);
        cmdChip(ctx, lerp(r.headX, W * 0.72, f2), lerp(r.headY - 110, -120, f2), '/needlicense', 1, { align: 'center', size: 34 });
      }
      ctx.globalAlpha = clamp(pp * 2);
    }
    cmdChip(ctx, px, py, '/needlicense', pp, { align: 'center', size: 34 });
    ctx.restore();
  }
  // chatul (al candidatului) - doar campul de scris
  chatTyping(ctx, t, T.typeA - 0.25, '/needlicense', T.enterA, 250);
  drawVignette(ctx, 0.45);
}

// ============================================================
// SCENA B (6-12 s): sediul SI, notificarea, accept, SMS
// ============================================================
function zioPoseB(t) {
  const walking = seg(t, T.walkB, T.walkB + 1.5);
  const walkAmt = env(t, T.walkB, T.walkB + 1.5, 0.2, 0.25);
  return {
    x: lerp(-10, 250, E.inOutQuad(walking)),
    pose: {
      t, walk: (t - T.walkB) * 9, walkAmt,
      headTurn: t < T.cardIn + 0.1 ? 0.2 : lerp(-0.6, 0.15, seg(t, T.accept + 0.3, T.accept + 0.8)),
      brow: env(t, T.cardIn + 0.05, T.accept + 0.4, 0.1, 0.3),
      bob: -env(t, T.cardIn + 0.05, T.cardIn + 0.35, 0.08, 0.2) * 3,
      smile: seg(t, T.accept, T.accept + 0.3) * 0.8, nod: env(t, T.accept, T.accept + 0.5, 0.12, 0.3),
      armR: { s: 0.1 + env(t, T.accept - 0.3, T.accept + 0.4, 0.2, 0.25) * 0.5, e: 0.08 + env(t, T.accept - 0.3, T.accept + 0.4, 0.2, 0.25) * 1.7 },
      rim: C.primary, rimA: 0.75,
    },
  };
}
function sceneB(ctx, t) {
  const z = E.inExpo(seg(t, T.zoomB, 12.0));
  const zp = zioPoseB(t);
  const headX = zp.x, headY = 40 - 96 * 4.8;
  const cam = { x: lerp(0, headX, z), y: lerp(0, headY, z), zoom: lerp(1.0, 5.5, z), sy: lerp(H * 0.69, H * 0.47, z) };
  drawHQ(ctx, cam, t);
  worldBegin(ctx, cam);
  const unlockBlink = (t > T.unlock && t < T.unlock + 0.5) ? (Math.floor((t - T.unlock) * 8) % 2 === 0) : false;
  const r = drawToon(ctx, ZIO, zp.x, 40, 4.8, zp.pose);
  drawCarSide(ctx, 560, 200, 1.0, { lights: unlockBlink || t > T.unlock + 0.5, brake: unlockBlink });
  ctx.restore();
  if (z < 0.15) nameTag(ctx, r.headX, r.headY - 30, INSTR.name, INSTR.id, '#8CFFC0', 1.2, 1 - z * 6);
  const ui = 1 - clamp(z * 7);
  if (ui <= 0) { drawVignette(ctx, 0.5); return; }
  ctx.save();
  ctx.globalAlpha = ui;
  chatInstr(ctx, t);
  // legenda (dreapta)
  ctx.save();
  ctx.translate(1046, 560); ctx.scale(2.2, 2.2);
  const flashAcc = env(t, T.accept, T.accept + 0.6, 0.05, 0.5);
  uiLegend(ctx, 0, 0, [
    { label: 'Accept needlicense', key: 'F2', flash: flashAcc },
    { label: 'Cere licentele', key: 'F3' },
    { label: 'Checkpoint - Ganton', dist: 969, appear: seg(t, T.cpSet, T.cpSet + 0.4), flash: env(t, T.cpSet, T.cpSet + 0.8, 0.05, 0.6) },
  ]);
  ctx.restore();
  // bara de iconite (stanga)
  ctx.save(); ctx.translate(24, 790); ctx.scale(1.55, 1.55); uiDock(ctx, 0, 0, { open: [] }); ctx.restore();
  // cartonasul de notificare
  const slideIn = 1 - clamp((t - T.cardIn) / 0.65);
  const slideOut = clamp((t - (T.sms - 1.2)) / 0.65);
  const slide = t < T.sms - 1.2 ? slideIn : slideOut;
  if (t > T.cardIn && slide < 1) {
    ctx.save(); ctx.translate(30, 560); ctx.scale(1.9, 1.9);
    uiNotifyCard(ctx, 0, 0, { title: `${CAND.name} (${CAND.id})`, body: `cere licente  -  nivel ${CAND.level}`, slide, remain: 1 - (t - T.cardIn) / 10, glow: env(t, T.cardIn + 0.3, T.cardIn + 1.4, 0.2, 0.6) });
    ctx.restore();
  }
  // tasta F2 + comanda trimisa
  const kp = env(t, T.accept - 0.45, T.accept + 1.1, 0.15, 0.3);
  if (kp > 0) {
    const press = env(t, T.accept - 0.05, T.accept + 0.2, 0.05, 0.15);
    ctx.save(); ctx.globalAlpha *= kp;
    keycap(ctx, 870, 900, 'F2', press, 1.2 * (0.8 + 0.2 * E.outBack(seg(t, T.accept - 0.45, T.accept - 0.2))));
    ctx.restore();
  }
  cmdChip(ctx, 1040, 1030, `/accept needlicense ${CAND.id}`, seg(t, T.accept + 0.1, T.accept + 0.5) * (1 - seg(t, T.accept + 1.6, T.accept + 1.9)), { align: 'right', size: 26 });
  // SMS-ul primit de Stroe
  const ph = env(t, T.sms, 11.6, 0.3, 0.25);
  if (ph > 0) drawPhone(ctx, 40 - (1 - E.outBack(clamp(ph))) * 500, 820, t);
  ctx.restore();
  drawVignette(ctx, 0.5);
}
// telefonul lui Stroe cu SMS-ul automat (textul din SICHelper_data.lua)
function drawPhone(ctx, x, y, t) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(-0.05);
  glow(ctx, 'rgba(0,0,0,0.6)', 30);
  fillRR(ctx, 0, 0, 420, 560, 46, '#0c0f12');
  noGlow(ctx);
  strokeRR(ctx, 0, 0, 420, 560, 46, '#39434b', 4);
  fillRR(ctx, 18, 18, 384, 524, 32, '#12181d');
  fillRR(ctx, 160, 30, 100, 22, 11, '#05070a');
  text(ctx, 'Telefonul lui ' + CAND.name, 210, 92, { font: F.ui(22, 700), color: C.dim, align: 'center' });
  icon(ctx, 'sms', 52, 150, 30, C.accent);
  text(ctx, 'SMS · ' + INSTR.name, 78, 152, { font: F.ui(24, 800), color: C.text, base: 'middle' });
  // bula
  const b = E.outBackBig(seg(t, T.sms + 0.15, T.sms + 0.5));
  ctx.save(); ctx.translate(40, 190); ctx.scale(b, b);
  fillRR(ctx, 0, 0, 340, 250, 26, '#1f6b46');
  const msgT = 'Salut! Ajung imediat la tine. Daca vrei sa ne vedem intr-un loc anume, spune-mi!';
  const lines = wrapColored(ctx, [{ c: '#F2FFF7', s: msgT }], F.ui(27, 600), 300);
  lines.forEach((ln, i) => drawColoredLine(ctx, ln, 20, 44 + i * 36, F.ui(27, 600)));
  ctx.restore();
  text(ctx, 'acum', 380, 470, { font: F.ui(18, 600), color: C.dim, align: 'right' });
  ctx.restore();
}

// ============================================================
// SCENA C (12-22 s): montajul "Jarvis"
// ============================================================
// pozitiile ferestrelor: "spot" = mare, in centru; "tile" = mica, in randul de sus
function winPlace(t, tIn, tTile, spot, tile) {
  const pin = E.outBack(seg(t, tIn, tIn + 0.45));
  const pt = E.inOutCubic(seg(t, tTile, tTile + 0.5));
  return {
    x: lerp(lerp(spot.x + 700, spot.x, pin), tile.x, pt), y: lerp(spot.y, tile.y, pt),
    s: lerp(lerp(spot.s * 0.7, spot.s, pin), tile.s, pt), a: clamp(seg(t, tIn, tIn + 0.2)),
    skew: (1 - pin) * 0.25, tile: pt,
  };
}
function drawPlaced(ctx, P, fn, glowAmt) {
  if (P.a <= 0) return;
  ctx.save();
  ctx.globalAlpha *= P.a;
  ctx.translate(P.x, P.y);
  ctx.transform(1, P.skew * 0.3, -P.skew, 1, 0, 0);
  ctx.scale(P.s, P.s);
  fn(glowAmt);
  ctx.restore();
}
function sceneC(ctx, t) {
  const out = E.inExpo(seg(t, T.zoomC, 22.0));
  ctx.save();
  // zoom-through la final
  ctx.translate(W / 2, H * 0.47); ctx.scale(1 + out * 5, 1 + out * 5); ctx.translate(-W / 2, -H * 0.47);
  drawJarvisBG(ctx, t, { cy: H * 0.47, rings: 1, ringScale: 1 + 0.08 * Math.sin(t * 2) });
  // logo-ul ZA in inele, la pornire
  const lg = env(t, 12.05, 13.6, 0.3, 0.4);
  if (lg > 0 && IMG.logo) {
    const k = E.outBackBig(seg(t, 12.05, 12.5));
    ctx.save(); ctx.globalAlpha = lg; glow(ctx, hexA(C.primary, 0.8), 40);
    ctx.drawImage(IMG.logo, W / 2 - 260 * k, H * 0.47 - 260 * k, 520 * k, 520 * k);
    noGlow(ctx); ctx.restore();
  }
  // consola de pornire
  const boot = [
    `> SICHelper 1.6.0-beta · School Instructors`,
    `> candidat: ${CAND.name} (${CAND.id}) · nivel ${CAND.level} · RO`,
    `> checkpoint: Ganton · 969 m`,
    `> module: /sic  /withme  /info  raport  dovezi`,
  ];
  boot.forEach((s, i) => {
    const p = seg(t, 12.12 + i * 0.3, 12.12 + i * 0.3 + 0.28);
    if (p <= 0) return;
    text(ctx, typed(s, p), 44, 178 + i * 40, { font: F.mono(25, 700), color: i === 1 ? C.accent : hexA(C.jarvis, 0.85), shadow: 'rgba(0,0,0,0.6)' });
  });
  // /sic: tab-urile se schimba pe ritm
  const tabI = clamp(Math.floor((t - T.tabs0) / 0.5) + 1, 0, 5);
  const tabGlow = t > T.tabs0 ? 1 - ((t - T.tabs0) % 0.5) / 0.5 : 0;
  const sicP = winPlace(t, 13.25, T.infoC, { x: 98, y: 640, s: 2.6 }, { x: 40, y: 350, s: 0.95 });
  drawPlaced(ctx, sicP, () => uiSic(ctx, 0, 0, { tab: tabI, tabGlow: tabGlow * 0.9, glow: 1 - sicP.tile, withme: false }));
  // /info
  const infoP = winPlace(t, T.infoC, T.reportC, { x: 108, y: 650, s: 2.4 }, { x: 378, y: 350, s: 0.9 });
  const scan = seg(t, T.infoC + 0.2, T.infoC + 1.2);
  drawPlaced(ctx, infoP, () => uiInfo(ctx, 0, 0, { scan, typed: seg(t, T.infoC + 0.3, T.infoC + 1.3), glow: 1 - infoP.tile, t, dist: '969 m' }));
  // raportul
  const repP = winPlace(t, T.reportC, T.checkC, { x: 150, y: 660, s: 2.6 }, { x: 716, y: 350, s: 0.97 });
  drawPlaced(ctx, repP, () => uiReport(ctx, 0, 0, { fill: E.outCubic(seg(t, T.reportC + 0.2, T.reportC + 0.9)), glow: 1 - repP.tile }));
  // dovezile
  const chk = winPlace(t, T.checkC, T.lockC, { x: 165, y: 680, s: 3.0 }, { x: 165, y: 680, s: 3.0 });
  const chkOut = seg(t, T.lockC, T.lockC + 0.35);
  chk.a *= 1 - chkOut; chk.s *= 1 - chkOut * 0.3;
  drawPlaced(ctx, chk, () => uiChecklist(ctx, 0, 0, { done: [E.outCubic(seg(t, T.checkC + 0.4, T.checkC + 0.7))], glow: 1 }));
  // tinta: candidatul
  const lk = seg(t, T.lockC, T.lockC + 0.5);
  if (lk > 0) {
    const cx = W / 2, cy = H * 0.47 + 120;
    const k = E.outCubic(lk);
    const bw = lerp(900, 640, k), bh = lerp(700, 300, k);
    ctx.save();
    ctx.globalAlpha = clamp(lk * 2);
    glow(ctx, C.primary, 18);
    brackets(ctx, cx - bw / 2, cy - bh / 2, bw, bh, 60, C.accent, 5);
    noGlow(ctx);
    text(ctx, 'TINTĂ SETATĂ', cx, cy - 70, { font: F.hud(40, 700), color: C.jarvis, align: 'center', ls: 8 });
    text(ctx, `${CAND.name} (${CAND.id})`, cx, cy + 20, { font: F.hud(88, 700), color: '#FFFFFF', align: 'center', shadow: hexA(C.primary, 0.6), sdx: 0, sdy: 4 });
    text(ctx, `nivel ${CAND.level}  ·  969 m  ·  Ganton`, cx, cy + 90, { font: F.hud(36, 600), color: C.accent, align: 'center', ls: 2 });
    // crucea din mijloc se roteste
    ctx.translate(cx, cy - 190); ctx.rotate(t * 2);
    ring(ctx, 0, 0, 40, C.accent, 3, 0, 1.2); ring(ctx, 0, 0, 40, C.accent, 3, Math.PI, Math.PI + 1.2);
    ctx.restore();
  }
  ctx.restore();
  scanlines(ctx, 0.07);
  drawVignette(ctx, 0.6);
}

// ============================================================
// SCENA D (22-32 s): drumul pe harta + distanta din legenda
// ============================================================
function driveS(t) { return MAP.len * E.inOutQuad(seg(t, T.driveA, T.driveB)); }
function sceneD(ctx, t) {
  const s = driveS(t);
  const p = routeAt(s);
  const pa = routeAt(s - 40), pb = routeAt(s + 40);
  const heading = Math.atan2(pb.y - pa.y, pb.x - pa.x);
  const intro = E.outCubic(seg(t, 22.0, 22.8));
  const outZ = E.inExpo(seg(t, T.zoomD, 32.0));
  const zoom = lerp(1.9, 1.0, intro) * (1 + outZ * 2.5);
  const rot = -(heading + Math.PI / 2);
  ctx.fillStyle = '#05080a'; ctx.fillRect(0, 0, W, H);
  const carY = H * 0.6;
  ctx.save();
  ctx.translate(W / 2, carY); ctx.scale(zoom, zoom); ctx.rotate(rot);
  ctx.translate(-p.x, -p.y);
  ctx.drawImage(MAP.canvas, -MAP.O, -MAP.O);
  // traseul ramas
  const R = MAP.route;
  ctx.save();
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.beginPath();
  let started = false;
  for (const q of R) { if (q.s < s) continue; if (!started) { ctx.moveTo(p.x, p.y); started = true; } ctx.lineTo(q.x, q.y); }
  glow(ctx, C.primary, 24);
  ctx.strokeStyle = hexA(C.primary, 0.55); ctx.lineWidth = 22; ctx.stroke();
  noGlow(ctx);
  ctx.setLineDash([26, 22]); ctx.lineDashOffset = -t * 120;
  ctx.strokeStyle = '#D9FFE9'; ctx.lineWidth = 6; ctx.stroke();
  ctx.setLineDash([]);
  ctx.restore();
  // checkpoint-ul (rosu, ca in SA-MP) + candidatul
  const end = R[R.length - 1];
  const pulse = (t * 1.4) % 1;
  ctx.save();
  glow(ctx, 'rgba(255,40,40,0.9)', 30);
  ring(ctx, end.x, end.y, 26, '#ff3b3b', 6);
  noGlow(ctx);
  ctx.globalAlpha = 1 - pulse; ring(ctx, end.x, end.y, 26 + pulse * 70, '#ff5555', 4);
  ctx.restore();
  ctx.restore();
  // pozitia candidatului pe ecran (eticheta ramane dreapta)
  const toScreen = (x, y) => {
    const dx = x - p.x, dy = y - p.y;
    const cr = Math.cos(rot), sr = Math.sin(rot);
    return { x: W / 2 + (dx * cr - dy * sr) * zoom, y: carY + (dx * sr + dy * cr) * zoom };
  };
  const cs = toScreen(MAP.target.x, MAP.target.y);
  ctx.save();
  glow(ctx, hexA(C.primary, 0.9), 26);
  circle(ctx, cs.x, cs.y, 30 * zoom, '#0c1a13');
  ring(ctx, cs.x, cs.y, 30 * zoom, C.accent, 4);
  noGlow(ctx);
  icon(ctx, 'user', cs.x, cs.y + 1, 30 * zoom, C.accent);
  if (outZ < 0.2) text(ctx, `${CAND.name} (${CAND.id})`, cs.x, cs.y - 48 * zoom, { font: F.chat(30), color: '#FFFFFF', align: 'center', stroke: '#000', sw: 5 });
  ctx.restore();
  // masina (mereu cu fata in sus)
  drawCarTop(ctx, W / 2, carY, 0, 1.25 * zoom);
  // distantele reale (in linie dreapta, ca getDistanceBetweenCoords3d)
  const dCand = Math.hypot(MAP.target.x - p.x, MAP.target.y - p.y) / MAP.PPM;
  const dCp = Math.hypot(end.x - p.x, end.y - p.y) / MAP.PPM;
  const candIn = dCand <= 320 ? seg(t, tCandIn(), tCandIn() + 0.35) : 0;
  const ui = 1 - clamp(outZ * 4);
  ctx.save();
  ctx.globalAlpha = ui;
  // vigneta de radar
  drawVignette(ctx, 0.75);
  // legenda (dreapta sus)
  ctx.save();
  ctx.translate(1046, 480); ctx.scale(2.25, 2.25);
  const rows = [
    { label: 'Accept needlicense', key: 'F2' },
    { label: 'Cere licentele', key: 'F3' },
  ];
  if (candIn > 0) rows.push({ label: `Distanta pana la ${CAND.name}`, dist: dCand, appear: candIn, flash: 0.35 + 0.65 * env(t, tCandIn(), tCandIn() + 1.0, 0.05, 0.8) });
  if (dCp >= 8) rows.push({ label: 'Checkpoint - Ganton', dist: dCp });
  uiLegend(ctx, 0, 0, rows);
  ctx.restore();
  // bara de iconite
  ctx.save(); ctx.translate(24, 700); ctx.scale(1.5, 1.5); uiDock(ctx, 0, 0, { open: ['sic'] }); ctx.restore();
  // afisajul mare (copia randului din legenda)
  const big = candIn > 0 ? dCand : dCp;
  const lbl = candIn > 0 ? `DISTANȚA PÂNĂ LA ${CAND.name.toUpperCase()}` : 'CHECKPOINT · GANTON';
  const bp = seg(t, 22.3, 22.8);
  ctx.globalAlpha = ui * bp;
  fillRR(ctx, 160, 150, 760, 250, 18, 'rgba(4,12,9,0.78)');
  strokeRR(ctx, 160, 150, 760, 250, 18, hexA(C.primary, 0.7), 2.5);
  brackets(ctx, 150, 140, 780, 270, 34, C.accent, 4);
  text(ctx, lbl, W / 2, 205, { font: F.hud(34, 700), color: candIn > 0 ? C.accent : C.dim, align: 'center', ls: 4 });
  const fl = candIn > 0 ? env(t, tCandIn(), tCandIn() + 0.8, 0.05, 0.7) : 0;
  if (fl) glow(ctx, C.primary, 40 * fl);
  text(ctx, fmtDist(big), W / 2, 350, { font: F.hud(150, 700), color: '#FFFFFF', align: 'center' });
  noGlow(ctx);
  ctx.restore();
}
// momentul in care candidatul intra in raza (distanta <= 320 m)
let _tCand = null;
function tCandIn() {
  if (_tCand !== null) return _tCand;
  for (let tt = T.driveA; tt < T.driveB; tt += 1 / 120) {
    const q = routeAt(driveS(tt));
    if (Math.hypot(MAP.target.x - q.x, MAP.target.y - q.y) / MAP.PPM <= 320) { _tCand = tt; return tt; }
  }
  _tCand = T.driveB; return _tCand;
}

// ============================================================
// SCENA E (32-38 s): sosirea, /salut, /rl, dialogul
// ============================================================
function carXE(t) { return lerp(-1500, -300, E.outCubic(seg(t, T.carIn, T.carStop))); }
function zioE(t) {
  const w = seg(t, T.exit + 0.05, T.exit + 1.0);
  return { x: lerp(-140, 60, E.inOutQuad(w)), y: lerp(100, 40, E.inOutQuad(w)), s: lerp(5.45, 5.6, w), walkAmt: env(t, T.exit + 0.05, T.exit + 1.0, 0.15, 0.2), vis: t > T.exit };
}
function sceneE(ctx, t) {
  const z = E.inOutCubic(seg(t, 37.35, 38.2));
  const cam = { x: -40, zoom: 1.0 + z * 0.3, sy: H * 0.645 };
  drawStreet(ctx, cam, 0.35);
  worldBegin(ctx, cam);
  const st = { t, headTurn: -0.4, flip: false, smile: seg(t, T.salut + 0.6, T.salut + 1.0) * 0.8, nod: env(t, T.salut + 0.8, T.salut + 1.4, 0.15, 0.3),
    brow: env(t, T.carStop, T.carStop + 0.6, 0.1, 0.3) * 0.7, rim: '#ffb46b', rimA: 0.45,
    armL: { s: 0.1 + env(t, T.rl + 0.3, T.dialog, 0.2, 0.2) * 0.4, e: 0.1 + env(t, T.rl + 0.3, T.dialog, 0.2, 0.2) * 1.6 } };
  const rS = drawToon(ctx, STROE, 300, 30, 5.6, st);
  const zz = zioE(t);
  let rZ = null;
  if (zz.vis) {
    const waving = env(t, T.salut + 0.4, T.salut + 1.5, 0.15, 0.25);
    rZ = drawToon(ctx, ZIO, zz.x, zz.y, zz.s, {
      t, walk: (t - T.exit) * 9, walkAmt: zz.walkAmt, headTurn: 0.45, smile: 0.5 + waving * 0.4,
      armL: { s: 0.1 + waving * (2.35 + 0.25 * Math.sin(t * 16)), e: 0.08 + waving * 0.5 },
      rim: '#ffb46b', rimA: 0.45,
    });
  }
  const cx = carXE(t);
  const moving = t < T.carStop;
  drawCarSide(ctx, cx, 175, 0.95, { lights: true, brake: t > T.carStop - 0.4 && t < T.carStop + 0.6, wheelRot: (cx + 1500) / 45, bounce: moving ? Math.sin(t * 40) * 0.8 : env(t, T.carStop, T.carStop + 0.35, 0.05, 0.3) * 3, driver: !zz.vis });
  ctx.restore();
  nameTag(ctx, rS.headX, rS.headY - 26, CAND.name, CAND.id, '#FFFFFF', 1.1);
  if (rZ) nameTag(ctx, rZ.headX, rZ.headY - 26, INSTR.name, INSTR.id, '#8CFFC0', 1.1, seg(t, T.exit + 0.3, T.exit + 0.6));
  // chat + ce se scrie
  const uiA = 1 - z;
  ctx.save(); ctx.globalAlpha = uiA;
  chatInstr(ctx, t);
  chatTyping(ctx, t, T.salut, '/salut', T.salut + 0.4, 372);
  chatTyping(ctx, t, T.rl, '/rl', T.rl + 0.3, 372);
  cmdChip(ctx, 1040, 440, `/w ${CAND.id} Salut, ${CAND.name}!...`, seg(t, T.salut + 0.45, T.salut + 0.8) * (1 - seg(t, T.rl - 0.2, T.rl)), { align: 'right', size: 24 });
  cmdChip(ctx, 1040, 440, `/requestlicenses ${CAND.id}`, seg(t, T.rl + 0.35, T.rl + 0.7) * (1 - seg(t, T.dialog + 0.2, T.dialog + 0.5)), { align: 'right', size: 26 });
  ctx.restore();
  // dialogul serverului
  if (t > T.dialog) drawLicDialog(ctx, t, E.outBack(seg(t, T.dialog, T.dialog + 0.35)), 0);
  drawVignette(ctx, 0.45);
}
const DIALOG_POS = { x: 137, y: 600, s: 1.55 };
function dialogLines(t, scanT) {
  return LICS.map(l => `{FFFFFF}${l.dialog}: {FF4B4B}${l.status}`);
}
function drawLicDialog(ctx, t, k, glowAmt) {
  ctx.save();
  ctx.translate(DIALOG_POS.x + 403, DIALOG_POS.y + 210);
  ctx.scale(DIALOG_POS.s * k, DIALOG_POS.s * k);
  ctx.translate(-260, -135);
  if (glowAmt) { glow(ctx, hexA(C.primary, 0.6 * glowAmt), 40 * glowAmt); fillRR(ctx, 0, 0, 520, 270, 2, 'rgba(0,0,0,0.01)'); noGlow(ctx); }
  const d = sampDialog(ctx, 0, 0, { title: `Licentele lui ${CAND.name}`, lines: dialogLines(t) });
  ctx.restore();
  return d;
}

// ============================================================
// SCENA F (38-44 s): analiza licentelor
// ============================================================
function sceneF(ctx, t) {
  drawJarvisBG(ctx, t, { cy: H * 0.42, rings: 0.45, hexA: 0.8 });
  const nScan = LICS.filter((_, i) => t >= T.scan0 + i * T.scanStep).length;
  // contorul de sus
  const top = seg(t, 38.1, 38.4);
  ctx.save(); ctx.globalAlpha = top;
  text(ctx, 'CITIRE /requestlicenses', W / 2, 190, { font: F.hud(34, 700), color: C.jarvis, align: 'center', ls: 6 });
  text(ctx, `EXPIRATE: ${nScan}/5`, W / 2, 300, { font: F.hud(110, 700), color: nScan ? '#FF5A55' : '#FFFFFF', align: 'center', shadow: 'rgba(0,0,0,0.5)', sdx: 0, sdy: 5 });
  for (let i = 0; i < 5; i++) {
    const on = t >= T.scan0 + i * T.scanStep;
    fillRR(ctx, 250 + i * 120, 340, 100, 16, 8, on ? '#FF5A55' : 'rgba(255,255,255,0.12)');
  }
  ctx.restore();
  // dialogul
  const s = DIALOG_POS.s;
  drawLicDialog(ctx, t, 1, 0.6);
  const lineY = i => DIALOG_POS.y + (50 + (i + 0.5) * 30) * s;
  const x0 = DIALOG_POS.x, x1 = DIALOG_POS.x + 520 * s;
  LICS.forEach((l, i) => {
    const ts = T.scan0 + i * T.scanStep;
    // fasciculul de scanare pe rand
    const sp = seg(t, ts - 0.3, ts);
    if (sp > 0 && sp < 1) {
      const bx = lerp(x0, x1, E.inOutQuad(sp));
      ctx.save();
      const g = ctx.createLinearGradient(bx - 160, 0, bx, 0);
      g.addColorStop(0, hexA(C.primary, 0)); g.addColorStop(1, hexA(C.primary, 0.5));
      ctx.fillStyle = g; ctx.fillRect(bx - 160, lineY(i) - 22, 160, 44);
      glow(ctx, C.primary, 16); line(ctx, bx, lineY(i) - 26, bx, lineY(i) + 26, C.accent, 3); noGlow(ctx);
      ctx.restore();
    }
    if (t >= ts) {
      const k = E.outBackBig(seg(t, ts, ts + 0.3));
      // randul se inroseste
      ctx.save(); ctx.globalAlpha = 0.22 * clamp((t - ts) * 4);
      fillRR(ctx, x0 + 8, lineY(i) - 22, x1 - x0 - 16, 44, 4, '#FF3B3B');
      ctx.restore();
      // iconita licentei in stanga
      ctx.save(); ctx.translate(x0 - 44, lineY(i)); ctx.scale(k, k);
      circle(ctx, 0, 0, 30, '#2a0c0c'); ring(ctx, 0, 0, 30, '#FF5A55', 3);
      icon(ctx, l.icon, 0, 1, 26, '#FF8A85');
      ctx.restore();
      // eticheta EXPIRATA
      ctx.save(); ctx.translate(x1 - 110, lineY(i)); ctx.rotate(-0.06); ctx.scale(k, k);
      glow(ctx, 'rgba(255,60,60,0.8)', 16);
      fillRR(ctx, -92, -22, 184, 44, 8, '#C8231F');
      noGlow(ctx);
      icon(ctx, 'xmark', -64, 1, 22, '#FFFFFF');
      text(ctx, 'EXPIRATĂ', 12, 2, { font: F.hud(30, 700), color: '#FFFFFF', align: 'center', base: 'middle', ls: 2 });
      ctx.restore();
    }
  });
  // ce a inteles helperul (sub dialog)
  const py = DIALOG_POS.y + 270 * s + 50;
  ctx.save();
  fillRR(ctx, 110, py, 860, 330, 14, 'rgba(3,12,8,0.82)');
  strokeRR(ctx, 110, py, 860, 330, 14, hexA(C.primary, 0.5), 2);
  text(ctx, 'SICHelper · licentele candidatului', 140, py + 46, { font: F.mono(24, 700), color: C.jarvis });
  LICS.forEach((l, i) => {
    const ts = T.scan0 + i * T.scanStep;
    if (t < ts) return;
    const p = seg(t, ts, ts + 0.25);
    const yy = py + 100 + i * 46;
    text(ctx, typed(`${l.id.padEnd(10)} ▸ ${l.status.toLowerCase()}`, p), 150, yy, { font: F.mono(30, 700), color: '#FF8A85' });
    text(ctx, typed('-> /withme', p), 930, yy, { font: F.mono(24, 500), color: hexA(C.accent, 0.8), align: 'right' });
  });
  ctx.restore();
  // verdictul
  if (t > T.verdict) {
    const k = seg(t, T.verdict, T.verdict + 0.28);
    const sc = lerp(2.6, 1, E.outCubic(k));
    ctx.save();
    ctx.globalAlpha = clamp(k * 3);
    ctx.translate(W / 2, DIALOG_POS.y + 210); ctx.rotate(-0.1); ctx.scale(sc, sc);
    glow(ctx, 'rgba(255,40,40,0.9)', 40);
    strokeRR(ctx, -330, -95, 660, 190, 18, '#FF4B4B', 12);
    noGlow(ctx);
    fillRR(ctx, -330, -95, 660, 190, 18, 'rgba(60,4,4,0.8)');
    text(ctx, '5/5 EXPIRATE', 0, 12, { font: F.big(130), color: '#FF4B4B', align: 'center', base: 'middle', ls: 4 });
    ctx.restore();
  }
  scanlines(ctx, 0.06);
  drawVignette(ctx, 0.6);
}

// ============================================================
// SCENA G (44-50 s): /withme
// ============================================================
function streetDuo(ctx, t, cam, o = {}) {
  drawStreet(ctx, cam, o.tint ?? 0.45);
  worldBegin(ctx, cam);
  const rZ = drawToon(ctx, ZIO, o.zx ?? -150, 40, o.s ?? 5.4, Object.assign({ t, headTurn: 0.45, rim: '#ffb46b', rimA: 0.4 }, o.zpose || {}));
  const rS = drawToon(ctx, STROE, o.sx ?? 220, 30, o.s ?? 5.4, Object.assign({ t, headTurn: -0.45, rim: '#ffb46b', rimA: 0.4 }, o.spose || {}));
  ctx.restore();
  return { rZ, rS };
}
function sceneG(ctx, t) {
  const cam = { x: 40, zoom: 1.12 };
  streetDuo(ctx, t, cam, { zpose: { smile: 0.4 }, spose: { smile: 0.2 } });
  ctx.fillStyle = 'rgba(2,8,6,0.62)'; ctx.fillRect(0, 0, W, H);
  chatInstr(ctx, t);
  // fereastra
  const open = E.outBack(seg(t, T.wmIn, T.wmIn + 0.4));
  const close = E.inCubic(seg(t, T.clickOk + 0.08, T.clickOk + 0.3));
  const k = open * (1 - close * 0.15);
  const S = 2.6, wx = 111, wy = 560;
  const sel = t >= T.clickAll + 0.05 ? { all: true } : {};
  const colors = {}; LICS.forEach(l => { colors[l.id] = C.red; });
  const flashLic = {}; LICS.forEach((l, i) => { flashLic[l.id] = env(t, 44.55 + i * 0.07, 45.3 + i * 0.07, 0.1, 0.4); });
  // cursorul
  const cStart = { x: 930, y: 1420 };
  let hover = null, press = 0;
  let geo = null;
  if (open > 0 && close < 1) {
    ctx.save();
    ctx.globalAlpha = clamp(open * 2) * (1 - close);
    ctx.translate(wx + 165 * S, wy + 107 * S); ctx.scale(S * k, S * k); ctx.translate(-165, -107);
    // pozitiile butoanelor (in px de ecran), calculate o data
    geo = { all: { x: wx + (10 + 2 * ((310 - 12) / 3 + 6) + (310 - 12) / 6) * S, y: wy + (24 + 9 + 22 + 16 + 20 + 29 + 12) * S },
            ok: { x: wx + (10 + (310 - 6) / 4) * S, y: wy + (215 - 9 - 13) * S } };
    const cp = cursorPath(t, cStart, geo);
    hover = cp.hover; press = cp.press;
    uiWithme(ctx, 0, 0, { sel, colors, flashLic, hover, press, subtotal: t > T.clickAll ? seg(t, T.clickAll, T.clickAll + 0.4) : 0, glow: 0.8 });
    ctx.restore();
    if (t > 44.9 && t < T.clickOk + 0.3) drawCursor(ctx, cp.x, cp.y, 2.2, press);
  }
  // explicatia: rosu = expirata
  const note = env(t, 44.55, T.clickAll - 0.1, 0.2, 0.25);
  if (note > 0) {
    ctx.save(); ctx.globalAlpha = note;
    hudTag(ctx, 111, 470, 'ROȘU = EXPIRATĂ (din /rl)', { color: '#FF6A64', font: F.hud(30, 700) });
    ctx.restore();
  }
  // /id + captura de ecran
  const sh = env(t, T.shot - 0.05, T.shot + 1.2, 0.08, 0.3);
  if (sh > 0) {
    ctx.save(); ctx.globalAlpha = sh;
    const kk = E.outBackBig(seg(t, T.shot, T.shot + 0.3));
    ctx.translate(W / 2, 820); ctx.scale(kk * 1.35, kk * 1.35);
    fillRR(ctx, -250, -70, 500, 140, 20, 'rgba(4,14,9,0.9)');
    strokeRR(ctx, -250, -70, 500, 140, 20, C.primary, 3);
    icon(ctx, 'camera', -170, 0, 60, C.accent);
    text(ctx, `/id ${CAND.id}`, 20, -12, { font: F.mono(44, 700), color: '#FFFFFF', align: 'center', base: 'middle' });
    text(ctx, 'screenshot pentru dovadă', 20, 36, { font: F.ui(24, 600), color: C.dim, align: 'center', base: 'middle' });
    ctx.restore();
  }
  // memoria /withme
  const mm = env(t, T.memo + 0.4, 49.9, 0.3, 0.3);
  if (mm > 0) {
    const fly = E.inCubic(seg(t, 48.9, 49.6));
    ctx.save(); ctx.globalAlpha = mm;
    ctx.translate(lerp(W / 2, 980, fly), lerp(1060, 420, fly)); ctx.scale(lerp(1, 0.3, fly), lerp(1, 0.3, fly));
    glow(ctx, hexA(C.primary, 0.8), 30);
    fillRR(ctx, -420, -110, 840, 220, 22, 'rgba(4,16,10,0.94)');
    noGlow(ctx);
    strokeRR(ctx, -420, -110, 840, 220, 22, C.primary, 3);
    text(ctx, 'REȚINUT PENTRU /givelicense', 0, -48, { font: F.hud(34, 700), color: C.jarvis, align: 'center', ls: 4 });
    text(ctx, `withme: All · lvl ${CAND.level} · ${TOTAL_50}`, 0, 30, { font: F.mono(40, 700), color: '#FFFFFF', align: 'center' });
    text(ctx, `${CAND.name} (${CAND.id})`, 0, 80, { font: F.ui(28, 700), color: C.accent, align: 'center' });
    ctx.restore();
  }
  // dovezile (stanga jos)
  ctx.save();
  ctx.globalAlpha = seg(t, 44.2, 44.5) * (1 - seg(t, 49.6, 49.9));
  ctx.translate(40, 1150); ctx.scale(1.5, 1.5);
  uiChecklist(ctx, 0, 0, { done: [1, E.outCubic(seg(t, 44.35, 44.7)), E.outCubic(seg(t, T.fLine + 0.1, T.fLine + 0.4))] });
  ctx.restore();
  drawVignette(ctx, 0.5);
}
// cursorul: intra, merge pe "All", apasa, merge pe "Trimite", apasa
function cursorPath(t, start, geo) {
  const a = E.inOutCubic(seg(t, 45.05, 45.7));
  const b = E.inOutCubic(seg(t, 46.3, 46.9));
  let x = lerp(start.x, geo.all.x + 10, a), y = lerp(start.y, geo.all.y + 6, a);
  x = lerp(x, geo.ok.x + 10, b); y = lerp(y, geo.ok.y + 6, b);
  const p1 = env(t, T.clickAll - 0.03, T.clickAll + 0.18, 0.04, 0.12), p2 = env(t, T.clickOk - 0.03, T.clickOk + 0.18, 0.04, 0.12);
  const hover = b > 0.6 ? 'ok' : a > 0.7 ? 'all' : null;
  return { x, y, hover, press: Math.max(p1, p2) };
}

// ============================================================
// SCENA H (50-58 s): Toate licentele, in lant
// ============================================================
function sceneH(ctx, t) {
  const cam = { x: 0, zoom: 0.92, sy: 1400 };
  const accN = CHAIN_ACC.filter(a => t >= a).length;
  const lastAcc = accN ? CHAIN_ACC[accN - 1] : -9;
  const hop = env(t, lastAcc, lastAcc + 0.35, 0.08, 0.25);
  const doneK = seg(t, T.done, T.done + 0.4);
  const { rZ, rS } = streetDuo(ctx, t, cam, {
    zx: -250, sx: 250, s: 3.6, tint: 0.6,
    zpose: { smile: 0.6 + doneK * 0.4, armR: { s: 0.1 + env(t, T.chain0 - 0.2, T.done, 0.3, 0.4) * 1.25, e: 0.1 } },
    spose: { smile: 0.3 + accN * 0.14, bob: -hop * 4, brow: hop * 0.8, armL: { s: 0.1 + doneK * 2.4, e: 0.1 + doneK * 0.3 }, armR: { s: 0.1 + doneK * 2.4, e: 0.1 + doneK * 0.3 } },
  });
  ctx.fillStyle = 'rgba(2,8,6,0.4)'; ctx.fillRect(0, 0, W, 1000);
  chatInstr(ctx, t, { rows: 5, size: 25 });
  nameTag(ctx, rZ.headX, rZ.headY - 20, INSTR.name, INSTR.id, '#8CFFC0', 0.95);
  nameTag(ctx, rS.headX, rS.headY - 20, CAND.name, CAND.id, '#FFFFFF', 0.95);
  // /sic, tab-ul 50+
  const S = 1.9, sx = 217, sy = 330;
  const k = E.outBack(seg(t, T.sicIn, T.sicIn + 0.4));
  let allPos = null;
  ctx.save();
  ctx.globalAlpha = clamp(k * 2);
  ctx.translate(sx + 170 * S, sy + 107 * S); ctx.scale(S * k, S * k); ctx.translate(-170, -107);
  const hov = t > 50.9 && t < 51.6 ? 'all' : null;
  const press = env(t, T.clickGive - 0.03, T.clickGive + 0.18, 0.04, 0.12);
  const g = uiSic(ctx, 0, 0, { tab: 5, withme: true, hover: hov, press, allSel: t > T.clickGive, allGlow: env(t, T.clickGive, T.done, 0.1, 0.4) * (0.5 + 0.5 * Math.sin(t * 8)), glow: 0.6 });
  ctx.restore();
  allPos = { x: sx + g.all.x * S, y: sy + g.all.y * S };
  if (t > 50.4 && t < 51.9) {
    const cp = E.inOutCubic(seg(t, 50.45, 51.0));
    drawCursor(ctx, lerp(900, allPos.x + 40, cp), lerp(1250, allPos.y + 6, cp), 2.2, press);
  }
  // lantul: 5 noduri
  const ny = 895, nx0 = 190, ndx = 175;
  ctx.save();
  ctx.globalAlpha = seg(t, T.chain0 - 0.3, T.chain0);
  for (let i = 0; i < 4; i++) {
    line(ctx, nx0 + i * ndx + 40, ny, nx0 + (i + 1) * ndx - 40, ny, 'rgba(255,255,255,0.15)', 6);
    const f = seg(t, CHAIN_ACC[i], CHAIN_SEND[i + 1]);
    if (f > 0) { glow(ctx, C.primary, 14); line(ctx, nx0 + i * ndx + 40, ny, lerp(nx0 + i * ndx + 40, nx0 + (i + 1) * ndx - 40, f), ny, C.primary, 6); noGlow(ctx); }
  }
  LICS.forEach((l, i) => {
    const xN = nx0 + i * ndx;
    const sent = t >= CHAIN_SEND[i], acc = t >= CHAIN_ACC[i];
    const kk = acc ? E.outBackBig(seg(t, CHAIN_ACC[i], CHAIN_ACC[i] + 0.3)) : 1;
    ctx.save(); ctx.translate(xN, ny); ctx.scale(0.85 + 0.15 * kk, 0.85 + 0.15 * kk);
    if (sent && !acc) { const pp = (t - CHAIN_SEND[i]) * 2 % 1; ctx.globalAlpha *= 1 - pp; ring(ctx, 0, 0, 40 + pp * 30, C.amber, 4); ctx.globalAlpha = seg(t, T.chain0 - 0.3, T.chain0); }
    if (acc) glow(ctx, C.primary, 26);
    circle(ctx, 0, 0, 40, acc ? '#0d3a24' : sent ? '#2a2410' : 'rgba(12,18,16,0.92)');
    noGlow(ctx);
    ring(ctx, 0, 0, 40, acc ? C.primary : sent ? C.amber : C.idleBorder, 4);
    icon(ctx, l.icon, 0, 1, 32, acc ? C.accent : sent ? C.amber : C.idleText);
    if (acc) { circle(ctx, 28, -28, 15, C.primary); icon(ctx, 'check', 28, -27.5, 16, C.dark); }
    ctx.restore();
    text(ctx, l.short, xN, ny + 72, { font: F.ui(26, 800), color: acc ? C.accent : C.dim, align: 'center', stroke: 'rgba(0,0,0,0.7)', sw: 5 });
  });
  ctx.restore();
  // comanda curenta
  const cur = CHAIN_SEND.filter(s => t >= s).length - 1;
  if (cur >= 0 && t < T.done) {
    const l = LICS[cur];
    cmdChip(ctx, W / 2, 792, `/givelicense ${CAND.id} ${l.server}`, seg(t, CHAIN_SEND[cur], CHAIN_SEND[cur] + 0.3), { align: 'center', size: 30 });
  }
  // licentele zboara de la instructor la candidat, iar la accept urca in nodul lor din lant
  LICS.forEach((l, i) => {
    const f = seg(t, CHAIN_SEND[i] + 0.05, CHAIN_ACC[i]);
    if (f <= 0) return;
    const up = seg(t, CHAIN_ACC[i], CHAIN_ACC[i] + 0.3);
    if (up >= 1) return;
    const ax = rZ.headX + 70, ay = rZ.headY + 200, bx = rS.headX - 30, by = rS.headY + 170;
    let x, y, sc = 1;
    if (f < 1) {
      const e = E.inOutCubic(f);
      x = lerp(ax, bx, e); y = lerp(ay, by, e) - Math.sin(e * Math.PI) * 170;
    } else {
      const e = E.inCubic(up);
      x = lerp(bx, nx0 + i * ndx, e); y = lerp(by, ny, e); sc = lerp(1, 0.5, e);
    }
    ctx.save(); ctx.translate(x, y); ctx.scale(sc * 1.25, sc * 1.25); ctx.rotate(f < 1 ? Math.sin(f * 9) * 0.2 : 0);
    glow(ctx, hexA(C.primary, 0.8), 18);
    fillRR(ctx, -34, -24, 68, 48, 8, '#F1F7F3');
    noGlow(ctx);
    fillRR(ctx, -34, -24, 68, 12, [8, 8, 0, 0], C.primary);
    icon(ctx, l.icon, 0, 7, 22, '#0E1418');
    ctx.restore();
  });
  // "+1" deasupra lui Stroe la fiecare accept
  CHAIN_ACC.forEach((a, i) => {
    const p = seg(t, a, a + 0.8);
    if (p <= 0 || p >= 1) return;
    ctx.save(); ctx.globalAlpha = 1 - p * p;
    text(ctx, `+ ${LICS[i].label}`, (rZ.headX + rS.headX) / 2 + 60, rS.headY + 150 - p * 90, { font: F.cap(44, 900), color: C.accent, align: 'center', stroke: '#000', sw: 9 });
    ctx.restore();
  });
  // final: 5/5
  if (t > T.done) {
    const kk = E.outBackBig(seg(t, T.done, T.done + 0.35));
    confetti(ctx, t - T.done);
    ctx.save(); ctx.translate(W / 2, 792); ctx.scale(kk, kk);
    glow(ctx, C.primary, 40);
    fillRR(ctx, -380, -80, 760, 160, 24, 'rgba(4,22,13,0.95)');
    noGlow(ctx);
    strokeRR(ctx, -380, -80, 760, 160, 24, C.primary, 5);
    icon(ctx, 'circleCheck', -290, 2, 76, C.accent);
    text(ctx, '5/5 LICENȚE DATE', 40, 8, { font: F.big(84), color: '#FFFFFF', align: 'center', base: 'middle', ls: 2 });
    ctx.restore();
  }
  drawVignette(ctx, 0.45);
}
function confetti(ctx, dt) {
  const rnd = mulberry32(99);
  ctx.save();
  for (let i = 0; i < 90; i++) {
    const a = rnd() * TAU, sp = 500 + rnd() * 900;
    const x = W / 2 + Math.cos(a) * sp * dt, y = 792 + Math.sin(a) * sp * dt + 900 * dt * dt;
    ctx.globalAlpha = clamp(1 - dt / 0.9);
    ctx.fillStyle = [C.primary, C.accent, '#FFFFFF', C.amber][i % 4];
    ctx.save(); ctx.translate(x, y); ctx.rotate(dt * 10 + i); ctx.fillRect(-6, -3, 12, 6); ctx.restore();
  }
  ctx.restore();
}

// ============================================================
// SCENA I (58-60 s): final
// ============================================================
function sceneI(ctx, t) {
  drawJarvisBG(ctx, t, { cy: 760, rings: 0.8, ringScale: 0.8 });
  const k = E.outBackBig(seg(t, 58.0, 58.4));
  if (IMG.logo) {
    ctx.save(); glow(ctx, hexA(C.primary, 0.8), 50);
    ctx.drawImage(IMG.logo, W / 2 - 280 * k, 760 - 280 * k, 560 * k, 560 * k);
    noGlow(ctx); ctx.restore();
  }
  const a = seg(t, 58.25, 58.55);
  ctx.save(); ctx.globalAlpha = a;
  text(ctx, 'SICHelper', W / 2, 1170, { font: F.hud(130, 700), color: '#FFFFFF', align: 'center', ls: 4, shadow: hexA(C.primary, 0.7), sdx: 0, sdy: 6 });
  text(ctx, 'CMD helper pentru School Instructors · B-Zone', W / 2, 1240, { font: F.ui(34, 600), color: C.accent, align: 'center' });
  ctx.restore();
  const b = seg(t, 58.5, 58.8);
  ctx.save(); ctx.globalAlpha = b;
  const url = 'github.com/ZioAdolf-modding/SICHelper';
  const f = F.mono(34, 700), uw = tw(ctx, url, f) + 90;
  fillRR(ctx, W / 2 - uw / 2, 1300, uw, 76, 38, 'rgba(4,16,10,0.95)');
  strokeRR(ctx, W / 2 - uw / 2, 1300, uw, 76, 38, C.primary, 3);
  icon(ctx, 'terminal', W / 2 - uw / 2 + 44, 1339, 28, C.accent);
  text(ctx, url, W / 2 + 22, 1340, { font: f, color: '#FFFFFF', align: 'center', base: 'middle' });
  text(ctx, `cu ${INSTR.name} & ${CAND.name}`, W / 2, 1440, { font: F.ui(28, 600), color: C.dim, align: 'center' });
  ctx.restore();
  drawVignette(ctx, 0.5);
  ctx.fillStyle = `rgba(0,0,0,${seg(t, 59.6, 60) * 0.85})`; ctx.fillRect(0, 0, W, H);
}

// ============================================================
// REGIA: ce scena, ce tranzitie, efectele de la final
// ============================================================
const SCENES = [
  { a: 0, draw: sceneA }, { a: 6.0, draw: sceneB }, { a: 12.0, draw: sceneC }, { a: 22.0, draw: sceneD },
  { a: 32.0, draw: sceneE }, { a: 38.0, draw: sceneF }, { a: 44.0, draw: sceneG }, { a: 50.0, draw: sceneH }, { a: 58.0, draw: sceneI },
];
// tranzitiile cu doua scene simultan
const TRANS = [
  { t: 6.0, d: 0.5, type: 'whipUp' },
  { t: 38.0, d: 0.4, type: 'fade' },
  { t: 50.0, d: 0.5, type: 'whipLeft' },
];
let CV, CTX, BUF_A, BUF_B, BUF_F;
function sceneIndex(t) { let i = 0; for (let k = 0; k < SCENES.length; k++) if (t >= SCENES[k].a) i = k; return i; }
function drawScene(ctx, i, t) {
  ctx.save();
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'source-over';
  SCENES[i].draw(ctx, t);
  ctx.restore();
}
function render(t) {
  const f = BUF_F.getContext('2d');
  f.setTransform(1, 0, 0, 1, 0, 0);
  f.clearRect(0, 0, W, H);
  const tr = TRANS.find(x => t >= x.t - x.d / 2 && t < x.t + x.d / 2);
  if (tr) {
    const i = sceneIndex(tr.t);
    const a = BUF_A.getContext('2d'), b = BUF_B.getContext('2d');
    drawScene(a, i - 1, Math.min(t, tr.t - 0.001));
    drawScene(b, i, Math.max(t, tr.t));
    const p = seg(t, tr.t - tr.d / 2, tr.t + tr.d / 2);
    if (tr.type === 'fade') {
      f.drawImage(BUF_A, 0, 0); f.globalAlpha = E.inOutQuad(p); f.drawImage(BUF_B, 0, 0); f.globalAlpha = 1;
    } else {
      const e = E.inOutCubic(p);
      const vert = tr.type === 'whipUp';
      const dist = vert ? H : W;
      const blurN = 6, spread = Math.sin(p * Math.PI) * 140;
      const drawBlur = (buf, off) => {
        for (let k = 0; k < blurN; k++) {
          const o = off + (k / (blurN - 1) - 0.5) * spread;
          f.globalAlpha = k === 0 ? 1 : 0.35;
          if (vert) f.drawImage(buf, 0, o); else f.drawImage(buf, o, 0);
        }
        f.globalAlpha = 1;
      };
      drawBlur(BUF_A, e * dist);          // scena veche pleaca (in jos / la dreapta)
      drawBlur(BUF_B, (e - 1) * dist);    // cea noua vine de sus / din stanga
    }
  } else {
    drawScene(f, sceneIndex(t), t);
  }
  // compunerea finala: tremurat, glitch, flash, subtitrari, granulatie
  const ctx = CTX;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.globalAlpha = 1;
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  let sx = 0, sy = 0;
  for (const s of SHAKES) {
    if (t < s.t || t > s.t + s.d) continue;
    const k = 1 - (t - s.t) / s.d;
    sx += noise1(t * 60) * s.a * k; sy += noise1(t * 60 + 50) * s.a * k;
  }
  ctx.drawImage(BUF_F, sx, sy);
  if (sx || sy) { ctx.save(); ctx.globalAlpha = 0.5; ctx.drawImage(BUF_F, sx * 1.6, sy * 1.6); ctx.restore(); }
  for (const g of GLITCHES) {
    if (t < g.t - g.d / 2 || t > g.t + g.d / 2) continue;
    const rnd = mulberry32(Math.floor(t * FPS) * 7 + 3);
    for (let k = 0; k < 14; k++) {
      const y = rnd() * H, h = 20 + rnd() * 140, dx = (rnd() - 0.5) * 160;
      ctx.drawImage(BUF_F, 0, y, W, h, dx, y, W, h);
    }
    ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.globalAlpha = 0.35;
    ctx.fillStyle = rnd() < 0.5 ? '#ff0055' : '#00ffc8'; ctx.fillRect(0, rnd() * H, W, 30 + rnd() * 80);
    ctx.restore();
  }
  drawCaptions(ctx, t);
  for (const fl of FLASHES) {
    if (t < fl.t || t > fl.t + fl.d) continue;
    const k = 1 - (t - fl.t) / fl.d;
    ctx.fillStyle = `rgba(235,255,245,${fl.a * k * k})`; ctx.fillRect(0, 0, W, H);
  }
  drawGrain(ctx, t, 0.035);
}

// ============================================================
// PORNIRE
// ============================================================
const SHORT = { W, H, FPS, DURATION, cues: CUES, T, render: null, ready: null };
SHORT.ready = (async () => {
  CV = document.getElementById('c');
  CTX = CV.getContext('2d');
  BUF_A = makeCanvas(W, H); BUF_B = makeCanvas(W, H); BUF_F = makeCanvas(W, H);
  await document.fonts.load(F.icon(20), '');
  await Promise.all([
    document.fonts.load(F.ui(20, 400)), document.fonts.load(F.ui(20, 500)), document.fonts.load(F.ui(20, 600)), document.fonts.load(F.ui(20, 700)), document.fonts.load(F.ui(20, 800)),
    document.fonts.load(F.hud(20, 500)), document.fonts.load(F.hud(20, 600)), document.fonts.load(F.hud(20, 700)),
    document.fonts.load(F.mono(20, 500)), document.fonts.load(F.mono(20, 700)), document.fonts.load(F.chat(20)), document.fonts.load(F.big(20)),
    document.fonts.load(F.cap(20, 900)),
    loadImage('logo', '../../docs/logo/za-logo.png'),
  ]);
  initGrain(); initStreet(); initHQ(); initMap(); initJarvis();
  SHORT.render = render;
  return true;
})();
