// SICHelper short - componentele de interfata ale helperului, refacute dupa SICHelper.lua
// Toate masurile sunt in "px de helper" (la 1080p); scena aplica scara cu ctx.scale().
'use strict';

// ---------- butoane ----------
// kind: idle | sel | primary ; color = culoarea textului / chenarului (ca toggleButton din helper)
function uiButton(ctx, x, y, w, h, label, o = {}) {
  const kind = o.kind || 'idle';
  let bg = kind === 'sel' ? C.selBg : kind === 'primary' ? C.primary : C.idleBg;
  let border = kind === 'sel' ? C.selBorder : kind === 'primary' ? C.primary : C.idleBorder;
  let fg = kind === 'sel' ? C.accent : kind === 'primary' ? C.dark : C.idleText;
  if (o.color) { fg = o.color; if (kind !== 'primary') border = o.border || hexA(o.color, kind === 'sel' ? 0.9 : 0.55); }
  if (o.hover && kind !== 'primary') bg = mixHex(bg, '#FFFFFF', 0.06);
  if (o.hover && kind === 'primary') bg = mixHex(C.primary, '#FFFFFF', 0.18);
  const press = o.press || 0;
  ctx.save();
  if (press) { ctx.translate(x + w / 2, y + h / 2); ctx.scale(1 - press * 0.05, 1 - press * 0.05); ctx.translate(-x - w / 2, -y - h / 2); }
  if (o.glow) glow(ctx, hexA(o.glowColor || C.primary, 0.9 * o.glow), 14 * o.glow);
  fillRR(ctx, x, y, w, h, 4, bg);
  noGlow(ctx);
  strokeRR(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 4, border, kind === 'sel' ? 1.4 : 1);
  const fnt = o.font || F.ui(13, kind === 'primary' ? 700 : 600);
  let lx = x + w / 2;
  if (o.icon) {
    const lw = tw(ctx, label, fnt);
    const total = 16 + (label ? lw + 6 : 0);
    const ix = x + w / 2 - total / 2 + 8;
    icon(ctx, o.icon, ix, y + h / 2 + 0.5, 13, fg);
    lx = ix + 8 + 6 + lw / 2;
  }
  if (label) text(ctx, label, lx, y + h / 2 + 0.5, { font: fnt, color: fg, align: 'center', base: 'middle' });
  ctx.restore();
}

// ---------- fereastra imgui (titlu + corp) ----------
function uiWindow(ctx, x, y, w, h, title, o = {}) {
  ctx.save();
  if (o.glow) glow(ctx, hexA(C.primary, 0.55 * o.glow), 30 * o.glow);
  fillRR(ctx, x, y, w, h, 5, C.winBg);
  noGlow(ctx);
  // bara de titlu
  ctx.save();
  rr(ctx, x, y, w, h, 5); ctx.clip();
  const tg = ctx.createLinearGradient(x, y, x + w, y);
  tg.addColorStop(0, '#12291E'); tg.addColorStop(1, '#0E1A15');
  ctx.fillStyle = tg; ctx.fillRect(x, y, w, 24);
  ctx.fillStyle = hexA(C.primary, 0.9); ctx.fillRect(x, y + 23, w, 1);
  ctx.restore();
  text(ctx, title, x + 10, y + 12.5, { font: F.ui(13, 700), color: C.text, base: 'middle' });
  // butonul X
  icon(ctx, 'xmark', x + w - 13, y + 12.5, 11, C.dim);
  strokeRR(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 5, o.border || C.idleBorder, 1);
  ctx.restore();
  return { x: x + 10, y: y + 24 + 9, w: w - 20, h: h - 24 - 18 };
}

// ---------- cartonasul de notificare (Notify, "stil zioAdolf") ----------
// slide: 0 = la loc, 1 = in afara ecranului (spre stanga); remain = linia de timp 0..1
function uiNotifyCard(ctx, x, y, o) {
  const PAD = 16, fs = 15;
  const body = o.body, title = o.title.toUpperCase();
  const bodyFont = F.ui(fs, 500);
  const bw = tw(ctx, body, bodyFont);
  const Wc = Math.max(260, Math.min(420, bw + PAD * 2 + 30));
  const h = PAD + fs + 6 + fs * 1.25 + PAD + 4;
  const ease = (o.slide || 0) * (o.slide || 0);
  const left = x - ease * (Wc + 24);
  const alpha = 1 - ease * 0.6;
  const accent = o.accent || C.accent;
  ctx.save();
  ctx.globalAlpha *= alpha;
  if (o.glow) glow(ctx, hexA(accent, 0.6 * o.glow), 28 * o.glow);
  fillRR(ctx, left, y, Wc, h, 6, 'rgba(14,20,24,0.88)');
  noGlow(ctx);
  // bara de accent de 3 px in stanga
  ctx.save(); rr(ctx, left, y, Wc, h, 6); ctx.clip();
  ctx.fillStyle = accent; ctx.fillRect(left, y, 3, h);
  ctx.restore();
  text(ctx, title, left + PAD, y + PAD + fs * 0.82, { font: F.ui(fs, 700), color: accent, ls: 0.4 });
  icon(ctx, 'circleCheck', left + Wc - PAD - 7, y + PAD + fs * 0.45, fs, accent);
  text(ctx, body, left + PAD, y + PAD + fs + 6 + fs * 0.95, { font: bodyFont, color: hexA(C.text, 0.95) });
  const remain = o.remain ?? 1;
  fillRR(ctx, left + PAD, y + h - 4, 90 * remain, 2, 1, hexA(accent, 0.9));
  ctx.restore();
  return { w: Wc, h };
}

// ---------- legenda bind-urilor + randurile de distanta (dreapta ecranului) ----------
// rows: { label, key } sau { label, dist } ; appear 0..1 ; flash 0..1 ; right = marginea din dreapta
function uiLegend(ctx, right, y, rows, o = {}) {
  const rowH = 27, badge = 22, small = 14;
  let cy = y;
  for (const r of rows) {
    const ap = r.appear ?? 1;
    if (ap <= 0) continue;
    ctx.save();
    ctx.globalAlpha *= clamp(ap * 1.4);
    const off = (1 - E.outCubic(clamp(ap))) * 60;
    const valTxt = r.key !== undefined ? r.key : fmtDist(r.dist);
    const vf = F.ui(small, 700);
    const kw = r.key !== undefined ? Math.max(badge, tw(ctx, valTxt, vf) + 10) : tw(ctx, valTxt, vf) + 12;
    const bx0 = right - kw + off, by0 = cy + (rowH - badge) / 2;
    if (r.flash) glow(ctx, hexA(C.primary, r.flash), 22 * r.flash);
    fillRR(ctx, bx0, by0, kw, badge, 5, 'rgba(13,18,20,0.85)');
    noGlow(ctx);
    strokeRR(ctx, bx0, by0, kw, badge, 5, hexA(C.primary, 0.9), r.flash ? 1.2 + r.flash * 1.5 : 1.2);
    text(ctx, valTxt, bx0 + kw / 2, by0 + badge / 2 + 0.5, { font: vf, color: C.accent, align: 'center', base: 'middle' });
    const label = r.label.toUpperCase();
    const lf = F.ui(small, 600);
    const lx = bx0 - 10;
    text(ctx, label, lx, cy + rowH / 2 + 0.5, { font: lf, color: 'rgba(224,232,237,0.96)', align: 'right', base: 'middle', shadow: 'rgba(0,0,0,0.75)', sdx: 1, sdy: 1.2 });
    if (r.flash) {
      ctx.globalAlpha *= r.flash * 0.5;
      const lwid = tw(ctx, label, lf);
      fillRR(ctx, lx - lwid - 8, cy + 2, right - lx + lwid + 8 + 4 + off, rowH - 4, 6, hexA(C.primary, 0.18));
    }
    ctx.restore();
    cy += rowH * clamp(ap * 1.6);
  }
  return cy - y;
}
function fmtDist(d) {
  if (d >= 1000) return (d / 1000).toFixed(1) + ' km';
  return Math.max(0, Math.round(d)) + ' m';
}

// ---------- bara de iconite (dock) ----------
const DOCK_ITEMS = [
  { id: 'sic', icon: 'clipList' }, { id: 'wm', icon: 'userPlus' }, { id: 'raport', icon: 'chart' },
  { id: 'sih', icon: 'gear' }, { id: 'note', icon: 'note' }, { id: 'duty', text: 'DUTY' },
];
function uiDock(ctx, x, y, o = {}) {
  const S = 46, GAP = 6, PAD = 6;
  const horiz = !!o.horiz, n = DOCK_ITEMS.length;
  const w = horiz ? n * S + (n - 1) * GAP + 10 + PAD * 2 : S + PAD * 2;
  const h = horiz ? S + PAD * 2 : n * S + (n - 1) * GAP + 10 + PAD * 2;
  ctx.save();
  if (o.glow) glow(ctx, hexA(C.primary, 0.5 * o.glow), 26 * o.glow);
  fillRR(ctx, x, y, w, h, 8, 'rgba(10,13,15,0.82)');
  noGlow(ctx);
  strokeRR(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 8, hexA(C.idleBorder, 0.95), 1);
  let px = x + PAD, py = y + PAD;
  // manerul
  if (horiz) { line(ctx, px + 2, py + S / 2 - 8, px + 2, py + S / 2 + 8, C.idleBorder); line(ctx, px + 5, py + S / 2 - 8, px + 5, py + S / 2 + 8, C.idleBorder); px += 10; }
  else { line(ctx, px + S / 2 - 8, py + 2, px + S / 2 + 8, py + 2, C.idleBorder); line(ctx, px + S / 2 - 8, py + 5, px + S / 2 + 8, py + 5, C.idleBorder); py += 10; }
  DOCK_ITEMS.forEach((it, i) => {
    const ap = o.appear ? clamp(o.appear * n - i * 0.6) : 1;
    ctx.save();
    ctx.globalAlpha *= ap;
    const open = o.open && o.open.includes(it.id);
    const isDuty = it.id === 'duty';
    const stateCol = isDuty ? C.okGreen : null;
    const hl = o.pulse === it.id ? o.pulseAmt || 0 : 0;
    if (open || stateCol || hl) fillRR(ctx, px - 3, py - 3, S + 6, S + 6, 9, hexA(stateCol || C.primary, 0.18 + hl * 0.4));
    fillRR(ctx, px, py, S, S, 6, open ? C.selBg : C.idleBg);
    line(ctx, px + 4, py + 1.5, px + S - 4, py + 1.5, 'rgba(255,255,255,0.07)');
    strokeRR(ctx, px, py, S, S, 6, stateCol || (open || hl ? C.primary : C.idleBorder), open || stateCol || hl ? 2 : 1.2);
    const col = stateCol || (open || hl ? C.accent : C.idleText);
    if (it.icon) icon(ctx, it.icon, px + S / 2, py + S / 2, 21, col);
    else text(ctx, it.text, px + S / 2, py + S / 2 + 0.5, { font: F.ui(12, 800), color: col, align: 'center', base: 'middle' });
    ctx.restore();
    if (horiz) px += S + GAP; else py += S + GAP;
  });
  ctx.restore();
  return { w, h };
}

// ---------- /withme (Prompt, needLic) ----------
// o: { sel: {all:true,...}, colors: {flying:C.red,...}, hover, press, subtotal, name, id, glow }
function uiWithme(ctx, x, y, o = {}) {
  const w = 330, h = 215;
  const c = uiWindow(ctx, x, y, w, h, 'Withme', { glow: o.glow });
  let cy = c.y;
  // randul cu ID: [-] [camp] [+] [cel mai apropiat]  Nume
  text(ctx, 'ID', c.x, cy + 11, { font: F.ui(13, 600), color: C.text, base: 'middle' });
  uiButton(ctx, c.x + 30, cy, 22, 22, '-', {});
  fillRR(ctx, c.x + 58, cy, 52, 22, 4, '#0B1310');
  strokeRR(ctx, c.x + 58.5, cy + 0.5, 51, 21, 4, C.idleBorder);
  const idTxt = o.idText ?? String(CAND.id);
  text(ctx, idTxt, c.x + 64, cy + 11.5, { font: F.ui(13, 600), color: C.text, base: 'middle' });
  if (o.caret) fillRR(ctx, c.x + 64 + tw(ctx, idTxt, F.ui(13, 600)) + 1, cy + 5, 1.2, 12, 0, C.text);
  uiButton(ctx, c.x + 116, cy, 22, 22, '+', {});
  uiButton(ctx, c.x + 144, cy, 26, 22, '', { icon: 'crosshair' });
  text(ctx, o.name ?? CAND.name, c.x + 178, cy + 11.5, { font: F.ui(13, 600), color: C.accent, base: 'middle' });
  cy += 22 + 8;
  line(ctx, c.x, cy, c.x + c.w, cy, C.idleBorder);
  cy += 8;
  const lf = F.ui(13, 500);
  text(ctx, 'Licente pentru', c.x, cy + 8, { font: lf, color: C.text, base: 'middle' });
  text(ctx, (o.name ?? CAND.name) + ':', c.x + tw(ctx, 'Licente pentru ', lf), cy + 8, { font: F.ui(13, 600), color: C.accent, base: 'middle' });
  cy += 20;
  const licW = (c.w - 12) / 3;
  const all = [...LICS, ALL_LIC];
  all.forEach((lic, i) => {
    const col = i % 3, row = Math.floor(i / 3);
    const bx = c.x + col * (licW + 6), by = cy + row * (24 + 5);
    const sel = o.sel && o.sel[lic.id];
    const color = o.colors && o.colors[lic.id];
    uiButton(ctx, bx, by, licW, 24, lic.short, {
      kind: sel ? 'sel' : 'idle', icon: lic.icon, color, hover: o.hover === lic.id, press: o.hover === lic.id ? o.press : 0,
      glow: o.flashLic && o.flashLic[lic.id] ? o.flashLic[lic.id] : 0, glowColor: color || C.primary,
    });
  });
  cy += 2 * 24 + 5 + 10;
  if (o.subtotal) {
    const sf = F.ui(13, 500);
    let sx = c.x;
    text(ctx, 'Subtotal', sx, cy + 7, { font: sf, color: C.text, base: 'middle' }); sx += tw(ctx, 'Subtotal ', sf);
    text(ctx, `(nivel ${CAND.level}):`, sx, cy + 7, { font: sf, color: C.dim, base: 'middle' }); sx += tw(ctx, `(nivel ${CAND.level}): `, sf);
    ctx.save(); ctx.globalAlpha *= o.subtotal;
    text(ctx, TOTAL_50, sx, cy + 7, { font: F.ui(13, 700), color: C.amber, base: 'middle' });
    ctx.restore();
  } else {
    text(ctx, 'Alege licentele.', c.x, cy + 7, { font: F.ui(13, 500), color: C.dim, base: 'middle' });
  }
  const btnW = (c.w - 6) / 2, by = y + h - 9 - 26;
  uiButton(ctx, c.x, by, btnW, 26, 'Trimite', { kind: 'primary', hover: o.hover === 'ok', press: o.hover === 'ok' ? o.press : 0 });
  uiButton(ctx, c.x + btnW + 6, by, btnW, 26, 'Anuleaza', {});
  return { w, h, // pozitiile utile pentru cursor
    lic: id => { const i = all.findIndex(l => l.id === id); return { x: c.x + (i % 3) * (licW + 6) + licW / 2, y: c.y + 22 + 16 + 20 + Math.floor(i / 3) * 29 + 12 }; },
    ok: { x: c.x + btnW / 2, y: by + 13 } };
}

// ---------- /sic (tab-uri de teste + 50+) ----------
const SIC_TABS = [
  { id: 'fly', icon: 'helicopter', name: 'Flying' }, { id: 'sail', icon: 'ship', name: 'Sailing' },
  { id: 'fish', icon: 'fish', name: 'Fishing' }, { id: 'weap', icon: 'gun', name: 'Weapons' },
  { id: 'mat', icon: 'boxes', name: 'Materials' }, { id: 'lvl50', icon: 'crown', name: 'Level 50+' },
];
function uiSic(ctx, x, y, o = {}) {
  const w = 340, h = o.h || 214;
  const c = uiWindow(ctx, x, y, w, h, 'SIC  -  ' + (o.tabName || SIC_TABS[o.tab || 0].name), { glow: o.glow });
  let cy = c.y;
  // tab-urile, cu iconite
  const tw6 = (c.w - 5 * 5) / 6;
  SIC_TABS.forEach((tb, i) => {
    const active = (o.tab || 0) === i;
    uiButton(ctx, c.x + i * (tw6 + 5), cy, tw6, 26, '', { kind: active ? 'sel' : 'idle', icon: tb.icon, glow: active ? (o.tabGlow || 0) : 0 });
  });
  cy += 26 + 9;
  const tab = SIC_TABS[o.tab || 0];
  if (tab.id === 'lvl50') {
    const f = F.ui(13, 500);
    let sx = c.x;
    if (o.withme) {
      text(ctx, 'withme:', sx, cy + 8, { font: f, color: C.dim, base: 'middle' }); sx += tw(ctx, 'withme: ', f);
      const s2 = `All  lvl ${CAND.level}`;
      text(ctx, s2, sx, cy + 8, { font: F.ui(13, 600), color: C.blue, base: 'middle' }); sx += tw(ctx, s2 + '  ', F.ui(13, 600));
      text(ctx, TOTAL_50, sx, cy + 8, { font: F.ui(13, 700), color: C.amber, base: 'middle' });
    } else {
      text(ctx, `${CAND.name} (${CAND.id})`, sx, cy + 8, { font: F.ui(13, 600), color: C.accent, base: 'middle' });
    }
    cy += 22;
    const bw3 = (c.w - 10) / 3, bw2 = (c.w - 5) / 2;
    LICS.slice(0, 3).forEach((l, i) => uiButton(ctx, c.x + i * (bw3 + 5), cy, bw3, 24, l.short, { icon: l.icon, kind: o.given && o.given[l.id] ? 'sel' : 'idle' }));
    cy += 29;
    LICS.slice(3).forEach((l, i) => uiButton(ctx, c.x + i * (bw2 + 5), cy, bw2, 24, l.short, { icon: l.icon, kind: o.given && o.given[l.id] ? 'sel' : 'idle' }));
    cy += 29;
    uiButton(ctx, c.x, cy, c.w, 26, 'Toate licentele', { kind: o.allSel ? 'sel' : 'idle', hover: o.hover === 'all', press: o.hover === 'all' ? o.press : 0, glow: o.allGlow || 0 });
    return { w, h, all: { x: c.x + c.w / 2, y: cy + 13 } };
  }
  // tab de test: candidatul, butoanele de texte, start / give
  const f = F.ui(13, 500);
  text(ctx, 'Candidat:', c.x, cy + 8, { font: f, color: C.dim, base: 'middle' });
  text(ctx, `${CAND.name} (${CAND.id})`, c.x + tw(ctx, 'Candidat: ', f), cy + 8, { font: F.ui(13, 600), color: C.accent, base: 'middle' });
  cy += 22;
  const quiz = ['fish', 'weap', 'mat'].includes(tab.id);
  const labels = quiz ? ['Q1', 'Q2', 'Q3', 'Q4', 'Q5'] : ['T1', 'T2', 'T3'];
  const bw = (c.w - (labels.length - 1) * 5) / labels.length;
  labels.forEach((l, i) => uiButton(ctx, c.x + i * (bw + 5), cy, bw, 28, l, {}));
  cy += 34;
  const half = (c.w - 5) / 2;
  uiButton(ctx, c.x, cy, half, 26, 'Start lesson', { kind: 'primary' });
  uiButton(ctx, c.x + half + 5, cy, half, 26, 'Give ' + tab.name.replace('Weapons', 'Weapon'), {});
  cy += 32;
  uiButton(ctx, c.x, cy, half, 24, '/requestlicenses', { icon: 'idCard', font: F.ui(12, 600) });
  uiButton(ctx, c.x + half + 5, cy, half, 24, '/stoplesson', { font: F.ui(12, 600) });
  return { w, h };
}

// ---------- /info <id> (buletinul jucatorului) ----------
function uiInfo(ctx, x, y, o = {}) {
  const w = 360, h = 238;
  const c = uiWindow(ctx, x, y, w, h, `Info  -  ${CAND.name} (${CAND.id})`, { glow: o.glow });
  // poza de skin (165x300, proportii pastrate)
  const ph = 180, pw = ph * 165 / 300;
  fillRR(ctx, c.x, c.y, pw + 8, ph + 8, 4, '#0A120E');
  strokeRR(ctx, c.x + 0.5, c.y + 0.5, pw + 7, ph + 7, 4, C.idleBorder);
  // portretul HD al candidatului (desenat, nu poza din joc)
  ctx.save();
  rr(ctx, c.x + 4, c.y + 4, pw, ph, 3); ctx.clip();
  const pg = ctx.createLinearGradient(0, c.y, 0, c.y + ph);
  pg.addColorStop(0, '#15372a'); pg.addColorStop(1, '#06110c');
  ctx.fillStyle = pg; ctx.fillRect(c.x + 4, c.y + 4, pw, ph);
  drawToon(ctx, STROE, c.x + 4 + pw / 2, c.y + 4 + 118 * 1.62 + 8, 1.62, { t: o.t || 0, headTurn: 0.15, smile: 0.3 }, { noShadow: true, ow: 1.4 });
  ctx.restore();
  // scanarea fetei
  if (o.scan !== undefined && o.scan > 0 && o.scan < 1) {
    const sy = c.y + 4 + ph * o.scan;
    ctx.save();
    const g = ctx.createLinearGradient(0, sy - 30, 0, sy);
    g.addColorStop(0, hexA(C.primary, 0)); g.addColorStop(1, hexA(C.primary, 0.45));
    ctx.fillStyle = g; ctx.fillRect(c.x + 4, sy - 30, pw, 30);
    glow(ctx, C.primary, 10); line(ctx, c.x + 2, sy, c.x + pw + 6, sy, C.accent, 1.5); noGlow(ctx);
    ctx.restore();
  }
  const rx = c.x + pw + 20;
  const rows = [
    ['Nivel', String(CAND.level), C.accent], ['Ping', '38', C.text], ['FPS', '60', C.text],
    ['Factiune', 'Civil', C.text], ['Limba', 'RO', C.text], ['Licente', o.licKnown ? '5 expirate' : 'da /rl', o.licKnown ? C.red : C.dim],
    ['Distanta', o.dist || '1.3 km', C.text],
  ];
  const typed = o.typed ?? 1;
  rows.forEach((r, i) => {
    const ap = clamp(typed * rows.length - i);
    if (ap <= 0) return;
    ctx.save(); ctx.globalAlpha *= ap;
    const ry = c.y + 10 + i * 23;
    text(ctx, r[0], rx, ry, { font: F.ui(12.5, 500), color: C.dim, base: 'middle' });
    text(ctx, r[1], rx + 70, ry, { font: F.ui(13, 700), color: r[2], base: 'middle' });
    ctx.restore();
  });
  // etichetele (notitele tale)
  const tags = ['candidat', 'renew'];
  let tx = rx;
  const ty = c.y + ph - 14;
  tags.forEach(tg => {
    const tww = tw(ctx, tg, F.ui(11, 600)) + 14;
    fillRR(ctx, tx, ty, tww, 18, 9, C.selBg);
    strokeRR(ctx, tx, ty, tww, 18, 9, C.selBorder);
    text(ctx, tg, tx + tww / 2, ty + 9.5, { font: F.ui(11, 600), color: C.accent, align: 'center', base: 'middle' });
    tx += tww + 6;
  });
  return { w, h };
}

// ---------- raportul saptamanal ----------
function uiReport(ctx, x, y, o = {}) {
  const w = 300, h = 196;
  const c = uiWindow(ctx, x, y, w, h, 'Raport saptamanal', { glow: o.glow });
  const f = F.ui(12.5, 500);
  let cy = c.y + 6;
  text(ctx, 'Timp ramas (zile): ', c.x, cy, { font: f, color: C.dim, base: 'middle' });
  text(ctx, '3', c.x + tw(ctx, 'Timp ramas (zile): ', f), cy, { font: F.ui(13, 700), color: C.text, base: 'middle' });
  cy += 20;
  const bar = (label, v, max, fill) => {
    text(ctx, label, c.x, cy, { font: f, color: C.text, base: 'middle' });
    text(ctx, `${Math.round(v)}/${max}`, c.x + c.w, cy, { font: F.ui(12.5, 700), color: C.accent, align: 'right', base: 'middle' });
    cy += 13;
    fillRR(ctx, c.x, cy, c.w, 10, 3, '#0B1310');
    fillRR(ctx, c.x, cy, Math.max(0.001, c.w * fill), 10, 3, C.primary);
    cy += 22;
  };
  const p = o.fill ?? 1;
  bar('Raport', 7 * p, 10, 0.7 * p);
  bar('Bonus', 2 * p, 10, 0.2 * p);
  const half = (c.w - 6) / 2;
  [['1-49', '3'], ['50+', '2']].forEach(([k, v], i) => {
    const bx = c.x + i * (half + 6);
    fillRR(ctx, bx, cy, half, 34, 4, '#0D1512');
    strokeRR(ctx, bx + 0.5, cy + 0.5, half - 1, 33, 4, C.idleBorder);
    text(ctx, k, bx + 8, cy + 17, { font: F.ui(12, 500), color: C.dim, base: 'middle' });
    text(ctx, v, bx + half - 10, cy + 17, { font: F.ui(15, 800), color: C.text, align: 'right', base: 'middle' });
  });
  cy += 42;
  uiButton(ctx, c.x, cy, c.w, 24, 'Actualizeaza (/raport)', { kind: 'primary', font: F.ui(12, 700) });
  return { w, h };
}

// ---------- panoul de dovezi (checklist) ----------
const CHECK_STEPS = ['/accept needlicense', '/requestlicenses', 'Anunt pe /f', 'Raspuns / ultimul task', '/givelicense sau /stoplesson'];
function uiChecklist(ctx, x, y, o = {}) {
  const w = 250, rowH = 24, h = 38 + CHECK_STEPS.length * rowH + 6;
  ctx.save();
  if (o.glow) glow(ctx, hexA(C.primary, 0.5 * o.glow), 24 * o.glow);
  fillRR(ctx, x, y, w, h, 6, 'rgba(14,20,24,0.9)');
  noGlow(ctx);
  strokeRR(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 6, C.idleBorder);
  icon(ctx, 'clipCheck', x + 16, y + 19, 13, C.accent);
  text(ctx, 'DOVEZI', x + 30, y + 19.5, { font: F.ui(13, 800), color: C.accent, base: 'middle', ls: 1 });
  text(ctx, `${CAND.name} (${CAND.id})`, x + w - 12, y + 19.5, { font: F.ui(11.5, 600), color: C.dim, align: 'right', base: 'middle' });
  CHECK_STEPS.forEach((s, i) => {
    const ry = y + 38 + i * rowH;
    const d = o.done ? clamp(o.done[i] || 0) : 0;
    fillRR(ctx, x + 12, ry + 4, 16, 16, 3, d > 0 ? hexA(C.primary, 0.25 + 0.6 * d) : '#0B1310');
    strokeRR(ctx, x + 12.5, ry + 4.5, 15, 15, 3, d > 0 ? C.primary : C.idleBorder);
    if (d > 0) {
      ctx.save(); ctx.globalAlpha *= d;
      const sc = 0.6 + 0.4 * E.outBackBig(d);
      ctx.translate(x + 20, ry + 12); ctx.scale(sc, sc);
      icon(ctx, 'check', 0, 0.5, 11, C.dark);
      ctx.restore();
    }
    text(ctx, s, x + 38, ry + 12.5, { font: F.ui(12.5, d > 0 ? 600 : 500), color: d > 0 ? C.text : C.dim, base: 'middle' });
  });
  ctx.restore();
  return { w, h };
}

// ---------- chatul SA-MP (in pixeli de ecran) ----------
// lines: [{ s, t0 }] ; t = timpul curent ; se vad ultimele maxRows randuri (dupa impartire)
function sampChat(ctx, x, y, lines, t, o = {}) {
  const size = o.size || 29, font = F.chat(size), lh = Math.round(size * 1.22), maxW = o.maxW || (W - x - 40);
  const maxRows = o.maxRows || 6;
  const visible = lines.filter(l => l.t0 <= t);
  const rows = [];
  for (const l of visible) {
    const wr = wrapColored(ctx, parseColored(l.s), font, maxW);
    wr.forEach(r => rows.push({ words: r, t0: l.t0 }));
  }
  const show = rows.slice(-maxRows);
  // derulare lina: cand apare un rand nou, restul urca
  const newest = show.length ? show[show.length - 1].t0 : 0;
  const k = E.outCubic(seg(t, newest, newest + 0.18));
  const n = show.length;
  show.forEach((r, i) => {
    const ry = y + (i - (n - 1) + (maxRows - 1)) * lh + (1 - k) * (r.t0 === newest ? lh * 0.35 : lh * 0.3);
    const a = r.t0 === newest ? k : 1;
    ctx.save();
    ctx.globalAlpha *= a * (o.alpha ?? 1);
    drawColoredLine(ctx, r.words, x, ry, font, { stroke: 'rgba(0,0,0,0.95)', sw: Math.max(3, size * 0.16) });
    ctx.restore();
  });
}
// campul de scris din chat
function sampInput(ctx, x, y, s, t, o = {}) {
  const size = o.size || 29, font = F.chat(size);
  const wbox = o.w || 760, hbox = size + 18;
  ctx.save();
  ctx.globalAlpha *= o.alpha ?? 1;
  fillRR(ctx, x - 10, y - size - 4, wbox, hbox, 3, 'rgba(0,0,0,0.55)');
  strokeRR(ctx, x - 10, y - size - 4, wbox, hbox, 3, 'rgba(255,255,255,0.25)', 1.5);
  text(ctx, s, x, y + 3, { font, color: '#FFFFFF', stroke: 'rgba(0,0,0,0.9)', sw: 4 });
  if (Math.floor(t * 2.4) % 2 === 0) {
    const cw = tw(ctx, s, font);
    ctx.fillStyle = '#FFFFFF'; ctx.fillRect(x + cw + 3, y - size + 6, 3, size);
  }
  ctx.restore();
}

// ---------- dialogul serverului (stil SA-MP) ----------
function sampDialog(ctx, x, y, o = {}) {
  const w = 520, lh = 30;
  const lines = o.lines || [];
  const h = 50 + lines.length * lh + 70;
  ctx.save();
  ctx.globalAlpha *= o.alpha ?? 1;
  fillRR(ctx, x, y, w, h, 2, 'rgba(4,5,7,0.86)');
  strokeRR(ctx, x, y, w, h, 2, 'rgba(255,255,255,0.12)', 1);
  text(ctx, o.title || '', x + 16, y + 30, { font: F.chat(19), color: '#FFFFFF', stroke: 'rgba(0,0,0,0.8)', sw: 3 });
  line(ctx, x + 10, y + 44, x + w - 10, y + 44, 'rgba(255,255,255,0.18)', 1);
  lines.forEach((ln, i) => {
    const segs = parseColored(ln);
    drawColoredLine(ctx, segs.map(s => ({ c: s.c, s: s.s })), x + 18, y + 50 + (i + 0.75) * lh, F.chat(19), { stroke: 'rgba(0,0,0,0.8)', sw: 3 });
  });
  // butonul
  const bw = 120, bx = x + w / 2 - bw / 2, by = y + h - 50;
  const g = ctx.createLinearGradient(0, by, 0, by + 30);
  g.addColorStop(0, '#4a4a4a'); g.addColorStop(1, '#1c1c1c');
  fillRR(ctx, bx, by, bw, 30, 2, g);
  strokeRR(ctx, bx, by, bw, 30, 2, 'rgba(255,255,255,0.3)', 1);
  text(ctx, 'Inchide', bx + bw / 2, by + 16, { font: F.chat(17), color: '#FFFFFF', align: 'center', base: 'middle' });
  ctx.restore();
  return { w, h, lineY: i => y + 50 + (i + 0.5) * lh, lh };
}

// ---------- tasta apasata ----------
function keycap(ctx, x, y, label, press = 0, s = 1) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(s, s);
  const d = press * 6;
  fillRR(ctx, -44, -38 + 10, 88, 76, 12, '#0a0f0d');
  glow(ctx, hexA(C.primary, 0.3 + press * 0.6), 20 + press * 30);
  fillRR(ctx, -44, -38 + d, 88, 70, 12, '#16211c');
  noGlow(ctx);
  strokeRR(ctx, -44, -38 + d, 88, 70, 12, press > 0.1 ? C.primary : C.selBorder, 2.5);
  text(ctx, label, 0, -3 + d, { font: F.ui(30, 800), color: press > 0.1 ? C.accent : C.text, align: 'center', base: 'middle' });
  ctx.restore();
}

// ---------- elemente "Jarvis" ----------
function brackets(ctx, x, y, w, h, len, color, lw = 2) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.lineCap = 'square';
  ctx.beginPath();
  ctx.moveTo(x, y + len); ctx.lineTo(x, y); ctx.lineTo(x + len, y);
  ctx.moveTo(x + w - len, y); ctx.lineTo(x + w, y); ctx.lineTo(x + w, y + len);
  ctx.moveTo(x + w, y + h - len); ctx.lineTo(x + w, y + h); ctx.lineTo(x + w - len, y + h);
  ctx.moveTo(x + len, y + h); ctx.lineTo(x, y + h); ctx.lineTo(x, y + h - len);
  ctx.stroke();
  ctx.restore();
}
function hudTag(ctx, x, y, label, o = {}) {
  const f = o.font || F.hud(26, 700);
  const wl = tw(ctx, label, f, 2) + 28;
  ctx.save();
  ctx.globalAlpha *= o.alpha ?? 1;
  const col = o.color || C.jarvis;
  fillRR(ctx, x, y, wl, 40, 3, o.bg || hexA('#04100A', 0.8));
  strokeRR(ctx, x, y, wl, 40, 3, hexA(col, 0.8), 1.5);
  fillRR(ctx, x, y, 5, 40, 1, col);
  text(ctx, label, x + 16, y + 21, { font: f, color: col, base: 'middle', ls: 2 });
  ctx.restore();
  return wl;
}
// text scris litera cu litera
function typed(s, p) { return s.slice(0, Math.floor(s.length * clamp(p))); }
