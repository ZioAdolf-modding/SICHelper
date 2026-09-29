// SICHelper short - lumea: personajele (dupa skinuri), strada, sediul SI, masina, harta, fundalul "Jarvis"
'use strict';

// ============================================================
// PERSONAJE (marionete 2D, 100 unitati inaltime, originea la talpi)
// ============================================================
const ZIO = { // instructorul [XO]ZioAdolf - skin Ryder: geaca bomber verde inchis, tricou bej, blugi negri largi, adidasi, ochelari de soare
  kind: 'bomber', skin: '#6a4630', skinShade: '#4a2f1f', hair: '#16110d',
  top: '#2e4a2c', topShade: '#1f331e', topHi: '#4a6d42', rib: '#1c2a1a',
  shirt: '#d9cdb0', shirtShade: '#b3a585', pants: '#1e1f24', pantsShade: '#131418',
  shoes: '#34353b', sole: '#e9e9e9', glasses: true,
};
const STROE = { // candidatul [XO]Stroe - costum negru, camasa deschisa, cravata rosie
  kind: 'suit', skin: '#6b4731', skinShade: '#4b3020', hair: '#120e0b',
  top: '#1d1d23', topShade: '#111115', topHi: '#34343d', rib: '#16161b',
  shirt: '#d3dccf', shirtShade: '#aab5a6', tie: '#9a1d24', tieShade: '#6e1218',
  pants: '#18181d', pantsShade: '#0f0f12', shoes: '#0c0c0e', sole: '#1c1c1f', glasses: false,
};

function limb(ctx, x, y, a1, l1, a2, l2, w1, w2, col, shade) {
  const kx = x - Math.sin(a1) * l1, ky = y + Math.cos(a1) * l1;
  const ex = kx - Math.sin(a2) * l2, ey = ky + Math.cos(a2) * l2;
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.strokeStyle = col;
  ctx.lineWidth = w1; ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(kx, ky); ctx.stroke();
  ctx.lineWidth = w2; ctx.beginPath(); ctx.moveTo(kx, ky); ctx.lineTo(ex, ey); ctx.stroke();
  if (shade) { // umbra pe partea dreapta
    ctx.strokeStyle = shade;
    ctx.lineWidth = w1 * 0.42; ctx.beginPath(); ctx.moveTo(x + w1 * 0.27, y); ctx.lineTo(kx + w1 * 0.27, ky); ctx.stroke();
    ctx.lineWidth = w2 * 0.42; ctx.beginPath(); ctx.moveTo(kx + w2 * 0.27, ky); ctx.lineTo(ex + w2 * 0.27, ey); ctx.stroke();
  }
  return { kx, ky, ex, ey };
}

// pose: { t, walk, walkAmt, armL:{s,e}, armR:{s,e}, headTurn, headTilt, lean, bob, rim, rimA, smile, blink, nod }
function drawPerson(ctx, P, x, y, scale, pose = {}) {
  const t = pose.t || 0;
  const wa = pose.walkAmt || 0, ph = pose.walk || 0;
  const breath = Math.sin(t * 2.2) * 0.35;
  const bob = (pose.bob || 0) + (wa ? -Math.abs(Math.sin(ph)) * 1.6 * wa : 0);
  ctx.save();
  ctx.translate(x, y);
  ctx.scale(scale * (pose.flip ? -1 : 1), scale);
  if (!pose.noShadow) groundShadow(ctx, 0, 0, 1);

  ctx.translate(0, bob);
  const hipY = -48;
  // ---- picioare ----
  const legSw = Math.sin(ph) * 0.42 * wa;
  const kneeL = (0.5 + 0.5 * Math.cos(ph)) * 0.55 * wa, kneeR = (0.5 - 0.5 * Math.cos(ph)) * 0.55 * wa;
  const legW = P.kind === 'bomber' ? 12.5 : 11;
  const drawLeg = (sx, a, k) => {
    const r = limb(ctx, sx, hipY, a, 24, a - k * (sx < 0 ? 1 : 1), 23, legW, legW - 1, P.pants, P.pantsShade);
    // pantof
    ctx.save();
    ctx.translate(r.ex, r.ey);
    fillRR(ctx, -7.5 + (sx < 0 ? -1.5 : 1.5), -3.2, 15, 6.4, 3, P.shoes);
    if (P.kind === 'bomber') fillRR(ctx, -7.5 + (sx < 0 ? -1.5 : 1.5), 1.6, 15, 1.8, 1, P.sole);
    ctx.restore();
  };
  drawLeg(-6, legSw, kneeL);
  drawLeg(6, -legSw, kneeR);

  // ---- trunchi ----
  ctx.save();
  ctx.translate(0, hipY);
  ctx.rotate(pose.lean || 0);
  ctx.translate(0, -hipY);
  const sh = P.kind === 'bomber' ? 16.5 : 15.5;
  const waist = P.kind === 'bomber' ? 15 : 13.5;
  const bottom = P.kind === 'bomber' ? -49 : -44;
  const torsoTop = -79 + breath * 0.3;
  const torso = new Path2D();
  torso.moveTo(-sh, torsoTop);
  torso.quadraticCurveTo(-sh - 2.2, -66, -waist, bottom);
  torso.lineTo(waist, bottom);
  torso.quadraticCurveTo(sh + 2.2, -66, sh, torsoTop);
  torso.quadraticCurveTo(0, torsoTop - 3.5, -sh, torsoTop);
  torso.closePath();

  // gatul
  ctx.fillStyle = P.skinShade; ctx.fillRect(-4.2, -86, 8.4, 9);

  ctx.fillStyle = P.top; ctx.fill(torso);
  ctx.save();
  ctx.clip(torso);
  if (P.kind === 'bomber') {
    // tricoul bej la mijloc (geaca deschisa)
    ctx.fillStyle = P.shirt;
    ctx.beginPath(); ctx.moveTo(-5.5, torsoTop - 2); ctx.lineTo(5.5, torsoTop - 2); ctx.lineTo(4.2, bottom); ctx.lineTo(-4.2, bottom); ctx.closePath(); ctx.fill();
    ctx.fillStyle = P.shirtShade; ctx.fillRect(1.5, torsoTop, 3.5, bottom - torsoTop);
    // fermoarele
    ctx.fillStyle = P.topHi; ctx.fillRect(-6.4, torsoTop, 1.1, bottom - torsoTop); ctx.fillRect(5.3, torsoTop, 1.1, bottom - torsoTop);
    // tivul cu dungi
    ctx.fillStyle = P.rib; ctx.fillRect(-20, bottom - 4, 15, 4); ctx.fillRect(5, bottom - 4, 15, 4);
    ctx.strokeStyle = 'rgba(255,255,255,0.06)'; ctx.lineWidth = 0.5;
    for (let i = -19; i < 20; i += 1.6) { if (Math.abs(i) < 5) continue; ctx.beginPath(); ctx.moveTo(i, bottom - 4); ctx.lineTo(i, bottom); ctx.stroke(); }
    // cute ale gecii
    ctx.strokeStyle = P.topShade; ctx.lineWidth = 0.8;
    ctx.beginPath(); ctx.moveTo(-13, -70); ctx.quadraticCurveTo(-9, -66, -8, -60); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(12, -71); ctx.quadraticCurveTo(9, -64, 9, -58); ctx.stroke();
  } else {
    // camasa + cravata in V-ul reverelor
    ctx.fillStyle = P.shirt;
    ctx.beginPath(); ctx.moveTo(-6.5, torsoTop - 2); ctx.lineTo(6.5, torsoTop - 2); ctx.lineTo(0, -60); ctx.closePath(); ctx.fill();
    ctx.fillStyle = P.tie;
    ctx.beginPath(); ctx.moveTo(-1.7, torsoTop + 0.5); ctx.lineTo(1.7, torsoTop + 0.5); ctx.lineTo(1.2, torsoTop + 3.2); ctx.lineTo(-1.2, torsoTop + 3.2); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(-1.1, torsoTop + 3); ctx.lineTo(1.1, torsoTop + 3); ctx.lineTo(2.3, -63); ctx.lineTo(0, -60.5); ctx.lineTo(-2.3, -63); ctx.closePath(); ctx.fill();
    ctx.fillStyle = P.tieShade; ctx.fillRect(0.4, torsoTop + 3, 1.1, 14);
    // reverele
    ctx.fillStyle = P.topHi;
    ctx.beginPath(); ctx.moveTo(-6.5, torsoTop - 1); ctx.lineTo(-9, torsoTop + 3); ctx.lineTo(-4.5, -67); ctx.lineTo(0, -60); ctx.closePath(); ctx.fill();
    ctx.beginPath(); ctx.moveTo(6.5, torsoTop - 1); ctx.lineTo(9, torsoTop + 3); ctx.lineTo(4.5, -67); ctx.lineTo(0, -60); ctx.closePath(); ctx.fill();
    // nasturii si buzunarul
    circle(ctx, 0.4, -55.5, 0.9, '#3a3a44'); circle(ctx, 0.4, -50, 0.9, '#3a3a44');
    ctx.fillStyle = P.topHi; ctx.fillRect(-12, -71.5, 5.5, 0.9);
    ctx.fillStyle = P.shirt; ctx.fillRect(-11.2, -72.4, 3, 0.9);
    ctx.strokeStyle = P.topShade; ctx.lineWidth = 0.7;
    ctx.beginPath(); ctx.moveTo(0, -60); ctx.lineTo(0.6, bottom); ctx.stroke();
  }
  // umbra pe dreapta + lumina de contur pe stanga
  ctx.fillStyle = 'rgba(0,0,0,0.22)'; ctx.fillRect(3, -90, 20, 50);
  if (pose.rim) {
    const rg = ctx.createLinearGradient(-sh - 2, 0, -sh + 6, 0);
    rg.addColorStop(0, hexA(pose.rim, pose.rimA ?? 0.6)); rg.addColorStop(1, hexA(pose.rim, 0));
    ctx.fillStyle = rg; ctx.fillRect(-sh - 3, -90, 10, 50);
  }
  ctx.restore();
  if (P.kind === 'bomber') { // gulerul
    ctx.fillStyle = P.rib;
    ctx.beginPath(); ctx.moveTo(-7, torsoTop - 1.5); ctx.quadraticCurveTo(0, torsoTop + 1.2, 7, torsoTop - 1.5); ctx.lineTo(6, torsoTop - 3.6); ctx.quadraticCurveTo(0, torsoTop - 1.6, -6, torsoTop - 3.6); ctx.closePath(); ctx.fill();
  }

  // ---- brate ----
  const armSw = Math.sin(ph) * 0.35 * wa;
  const aL = pose.armL || {}, aR = pose.armR || {};
  const sL = (aL.s ?? 0.1) + armSw, eL = aL.e ?? 0.08;
  const sR = (aR.s ?? 0.1) - armSw, eR = aR.e ?? 0.08;
  const armW = P.kind === 'bomber' ? 9.5 : 8.6;
  // stanga (privitorului): unghi pozitiv = spre exterior
  const rl = limb(ctx, -sh + 2.2, torsoTop + 3.5, sL, 21, sL - eL, 19, armW, armW - 1, P.top, P.topShade);
  circle(ctx, rl.ex, rl.ey + 1, 4.2, P.skin);
  // dreapta: oglindit
  const rr_ = limb(ctx, sh - 2.2, torsoTop + 3.5, -sR, 21, -sR + eR, 19, armW, armW - 1, P.top, P.topShade);
  circle(ctx, rr_.ex, rr_.ey + 1, 4.2, P.skin);
  if (P.kind === 'bomber') { // mansetele gecii
    ctx.strokeStyle = P.rib; ctx.lineWidth = 3; ctx.lineCap = 'butt';
    [[rl.kx, rl.ky, rl.ex, rl.ey], [rr_.kx, rr_.ky, rr_.ex, rr_.ey]].forEach(([kx, ky, ex, ey]) => {
      const dx = ex - kx, dy = ey - ky, L = Math.hypot(dx, dy);
      const ux = dx / L, uy = dy / L;
      ctx.lineWidth = 8.2;
      ctx.beginPath(); ctx.moveTo(ex - ux * 5.5, ey - uy * 5.5); ctx.lineTo(ex - ux * 3, ey - uy * 3); ctx.stroke();
    });
  } else { // mansetele camasii
    ctx.strokeStyle = P.shirt; ctx.lineCap = 'butt';
    [[rl.kx, rl.ky, rl.ex, rl.ey], [rr_.kx, rr_.ky, rr_.ex, rr_.ey]].forEach(([kx, ky, ex, ey]) => {
      const dx = ex - kx, dy = ey - ky, L = Math.hypot(dx, dy);
      const ux = dx / L, uy = dy / L;
      ctx.lineWidth = 7;
      ctx.beginPath(); ctx.moveTo(ex - ux * 4.2, ey - uy * 4.2); ctx.lineTo(ex - ux * 2.6, ey - uy * 2.6); ctx.stroke();
    });
  }

  // ---- capul ----
  const turn = pose.headTurn || 0;
  const nod = pose.nod || 0;
  const HS = pose.headScale ?? 1.3;   // cap mai mare: stil cartoon
  ctx.save();
  ctx.translate(0, -84 + nod * 1.5 + breath * 0.2);
  ctx.rotate((pose.headTilt || 0) + Math.sin(t * 1.3) * 0.015);
  ctx.scale(HS, HS);
  ctx.translate(0, 84);
  const hx = turn * 1.1, hy = -93;
  // urechi
  circle(ctx, hx - 8.1 + turn * 0.8, hy + 1, 2.2, P.skinShade);
  circle(ctx, hx + 8.1 + turn * 0.8, hy + 1, 2.2, P.skinShade);
  const head = new Path2D();
  head.ellipse(hx, hy, 8.1, 9.8, 0, 0, TAU);
  ctx.fillStyle = P.skin; ctx.fill(head);
  ctx.save();
  ctx.clip(head);
  // falca / umbra din dreapta
  ctx.fillStyle = 'rgba(0,0,0,0.2)';
  ctx.beginPath(); ctx.ellipse(hx + 7 + turn * 2, hy + 1, 6, 12, 0, 0, TAU); ctx.fill();
  if (pose.rim) {
    const rg = ctx.createLinearGradient(hx - 9, 0, hx - 4, 0);
    rg.addColorStop(0, hexA(pose.rim, (pose.rimA ?? 0.6) * 0.9)); rg.addColorStop(1, hexA(pose.rim, 0));
    ctx.fillStyle = rg; ctx.fillRect(hx - 10, hy - 12, 7, 24);
  }
  // parul scurt
  ctx.fillStyle = P.hair;
  ctx.beginPath(); ctx.ellipse(hx, hy - 3.2, 8.5, 7.4, 0, Math.PI, TAU); ctx.lineTo(hx + 8.5, hy - 2.2); ctx.quadraticCurveTo(hx, hy - 6.4, hx - 8.5, hy - 2.2); ctx.closePath(); ctx.fill();
  ctx.restore();
  const fx = hx + turn * 2.6;
  if (P.glasses) {
    ctx.fillStyle = '#060607';
    fillRR(ctx, fx - 7.6, hy - 1.8, 6.6, 3.9, 1.6, '#060607');
    fillRR(ctx, fx + 1.0, hy - 1.8, 6.6, 3.9, 1.6, '#060607');
    ctx.fillRect(fx - 1.2, hy - 1.2, 2.4, 0.9);
    ctx.fillStyle = 'rgba(255,255,255,0.35)';
    ctx.fillRect(fx - 6.4, hy - 1.1, 2.4, 0.7); ctx.fillRect(fx + 2.2, hy - 1.1, 2.4, 0.7);
  } else {
    const bl = pose.blink ? clamp(pose.blink) : 0;
    ctx.fillStyle = '#f3efe8';
    ctx.beginPath(); ctx.ellipse(fx - 3.3, hy - 0.2, 1.7, 1.15 * (1 - bl), 0, 0, TAU); ctx.fill();
    ctx.beginPath(); ctx.ellipse(fx + 3.3, hy - 0.2, 1.7, 1.15 * (1 - bl), 0, 0, TAU); ctx.fill();
    circle(ctx, fx - 3.1 + turn * 0.5, hy - 0.1, 0.85 * (1 - bl), '#1a0f09');
    circle(ctx, fx + 3.5 + turn * 0.5, hy - 0.1, 0.85 * (1 - bl), '#1a0f09');
    const br = (pose.brow || 0) * 1.2;
    ctx.strokeStyle = P.hair; ctx.lineWidth = 1.1; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(fx - 5, hy - 2.8 - br); ctx.lineTo(fx - 1.8, hy - 3.2 - br * 1.3); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(fx + 1.8, hy - 3.2 - br * 1.3); ctx.lineTo(fx + 5, hy - 2.8 - br); ctx.stroke();
  }
  if (P.glasses && pose.brow) { // sprancenele peste ochelari
    const br = pose.brow * 1.4;
    ctx.strokeStyle = P.hair; ctx.lineWidth = 1.1; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(fx - 6.5, hy - 2.8 - br); ctx.lineTo(fx - 2, hy - 3.2 - br * 1.2); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(fx + 2, hy - 3.2 - br * 1.2); ctx.lineTo(fx + 6.5, hy - 2.8 - br); ctx.stroke();
  }
  // nasul si gura
  ctx.fillStyle = P.skinShade;
  ctx.beginPath(); ctx.ellipse(fx + 0.3, hy + 3.2, 1.6, 1.1, 0, 0, TAU); ctx.fill();
  ctx.strokeStyle = '#2b1810'; ctx.lineWidth = 0.9; ctx.lineCap = 'round';
  const sm = pose.smile || 0;
  if (sm > 0.6) { // zambet mare, cu dinti
    ctx.fillStyle = '#2b1810';
    ctx.beginPath(); ctx.moveTo(fx - 3, hy + 5.6); ctx.quadraticCurveTo(fx, hy + 5.6 + sm * 3.4, fx + 3, hy + 5.6); ctx.closePath(); ctx.fill();
    ctx.fillStyle = '#f4f1ea'; ctx.fillRect(fx - 2.3, hy + 5.7, 4.6, 0.9);
  } else {
    ctx.beginPath(); ctx.moveTo(fx - 2.4, hy + 6); ctx.quadraticCurveTo(fx, hy + 6 + sm * 1.6, fx + 2.4, hy + 6); ctx.stroke();
  }
  ctx.restore();
  ctx.restore(); // trunchi

  // punctul de deasupra capului, in coordonate de ecran (pentru eticheta cu numele)
  const m = ctx.getTransform();
  const top = m.transformPoint(new DOMPoint(0, -84 - 20 * (pose.headScale ?? 1.3) - 3));
  ctx.restore();
  return { headX: top.x, headY: top.y };
}

function groundShadow(ctx, x, y, s) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(s, s * 0.22);
  const sg = ctx.createRadialGradient(0, 0, 2, 0, 0, 28);
  sg.addColorStop(0, 'rgba(0,0,0,0.55)'); sg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(0, 0, 28, 0, TAU); ctx.fill();
  ctx.restore();
}
// personajul cu contur gros (stil sticker): desenat intr-un canvas separat, apoi conturat
const TOON = {};
function drawToon(ctx, P, x, y, s, pose = {}, o = {}) {
  const pad = 20, halfW = 58, top = 136, bot = 12;
  const cw = Math.ceil(halfW * 2 * s + pad * 2), ch = Math.ceil((top + bot) * s + pad * 2);
  if (!TOON.a || TOON.a.width < cw || TOON.a.height < ch) {
    TOON.a = makeCanvas(Math.max(cw, 900), Math.max(ch, 1300));
    TOON.b = makeCanvas(TOON.a.width, TOON.a.height);
  }
  const A = TOON.a, ga = A.getContext('2d'), B = TOON.b, gb = B.getContext('2d');
  ga.setTransform(1, 0, 0, 1, 0, 0); ga.clearRect(0, 0, cw, ch);
  const ox = cw / 2, oy = pad + top * s;
  const r = drawPerson(ga, P, ox, oy, s, Object.assign({}, pose, { noShadow: true }));
  gb.setTransform(1, 0, 0, 1, 0, 0); gb.clearRect(0, 0, cw, ch);
  gb.globalCompositeOperation = 'source-over'; gb.drawImage(A, 0, 0);
  gb.globalCompositeOperation = 'source-in'; gb.fillStyle = o.outline || '#07080b'; gb.fillRect(0, 0, cw, ch);
  gb.globalCompositeOperation = 'source-over';
  if (!o.noShadow) groundShadow(ctx, x, y, s * 1.05);
  const ow = o.ow ?? Math.max(2.5, s * 0.75);
  ctx.save();
  if (o.alpha !== undefined) ctx.globalAlpha *= o.alpha;
  if (o.glow) { ctx.shadowColor = o.glowColor || hexA(C.primary, 0.8); ctx.shadowBlur = o.glow; }
  for (let k = 0; k < 12; k++) {
    const a = k / 12 * TAU;
    ctx.drawImage(B, 0, 0, cw, ch, x - ox + Math.cos(a) * ow, y - oy + Math.sin(a) * ow, cw, ch);
  }
  noGlow(ctx);
  ctx.drawImage(A, 0, 0, cw, ch, x - ox, y - oy, cw, ch);
  ctx.restore();
  // capul, in coordonate de ecran (dupa transformarea camerei)
  const m = ctx.getTransform().transformPoint(new DOMPoint(r.headX - ox + x, r.headY - oy + y));
  return { headX: m.x, headY: m.y };
}

// eticheta SA-MP de deasupra capului: nume (id) + bara de viata
function nameTag(ctx, x, y, name, id, color, s = 1, alpha = 1) {
  ctx.save();
  ctx.globalAlpha *= alpha;
  const f = F.chat(Math.round(24 * s));
  text(ctx, `${name} (${id})`, x, y, { font: f, color, align: 'center', stroke: 'rgba(0,0,0,0.95)', sw: 4 * s });
  const bw = 90 * s, bh = 10 * s;
  ctx.fillStyle = '#000'; ctx.fillRect(x - bw / 2, y + 10 * s, bw, bh);
  ctx.fillStyle = '#5a0c0c'; ctx.fillRect(x - bw / 2 + 2 * s, y + 12 * s, bw - 4 * s, bh - 4 * s);
  ctx.fillStyle = '#b4191d'; ctx.fillRect(x - bw / 2 + 2 * s, y + 12 * s, (bw - 4 * s) * 0.97, bh - 4 * s);
  ctx.restore();
}

// ============================================================
// MASINA (vedere laterala), originea la sol, in centru, fata spre dreapta
// ============================================================
function drawCarSide(ctx, x, y, s, o = {}) {
  ctx.save();
  ctx.translate(x, y); ctx.scale(s * (o.flip ? -1 : 1), s);
  // umbra
  const sg = ctx.createRadialGradient(0, 0, 10, 0, 0, 280);
  sg.addColorStop(0, 'rgba(0,0,0,0.55)'); sg.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.save(); ctx.scale(1, 0.1); ctx.fillStyle = sg; ctx.beginPath(); ctx.arc(0, 0, 280, 0, TAU); ctx.fill(); ctx.restore();
  ctx.translate(0, o.bounce || 0);
  const body = new Path2D();
  body.moveTo(-242, -38);
  body.lineTo(-244, -80);
  body.quadraticCurveTo(-240, -96, -215, -98);
  body.lineTo(-150, -102);
  body.lineTo(-108, -160);
  body.quadraticCurveTo(-100, -166, -88, -166);
  body.lineTo(38, -166);
  body.quadraticCurveTo(50, -166, 58, -158);
  body.lineTo(104, -108);
  body.lineTo(208, -96);
  body.quadraticCurveTo(238, -92, 244, -72);
  body.lineTo(246, -40);
  body.quadraticCurveTo(246, -30, 236, -30);
  body.lineTo(-232, -30);
  body.quadraticCurveTo(-242, -30, -242, -38);
  body.closePath();
  const bg = ctx.createLinearGradient(0, -166, 0, -30);
  bg.addColorStop(0, '#3a434b'); bg.addColorStop(0.45, '#252c32'); bg.addColorStop(1, '#14191d');
  ctx.fillStyle = bg; ctx.fill(body);
  // geamurile
  const win = new Path2D();
  win.moveTo(-140, -106); win.lineTo(-103, -154); win.quadraticCurveTo(-98, -158, -90, -158);
  win.lineTo(36, -158); win.quadraticCurveTo(44, -158, 50, -152); win.lineTo(92, -108); win.closePath();
  const wg = ctx.createLinearGradient(-140, -158, 90, -106);
  wg.addColorStop(0, '#0b1116'); wg.addColorStop(0.5, '#1c2a33'); wg.addColorStop(1, '#0b1116');
  ctx.fillStyle = wg; ctx.fill(win);
  ctx.save(); ctx.clip(win);
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  ctx.beginPath(); ctx.moveTo(-60, -170); ctx.lineTo(-20, -170); ctx.lineTo(-70, -100); ctx.lineTo(-110, -100); ctx.closePath(); ctx.fill();
  ctx.fillStyle = 'rgba(110,242,172,0.12)';
  ctx.beginPath(); ctx.moveTo(10, -170); ctx.lineTo(24, -170); ctx.lineTo(-26, -100); ctx.lineTo(-40, -100); ctx.closePath(); ctx.fill();
  if (o.driver) { // silueta soferului
    ctx.fillStyle = 'rgba(5,6,8,0.85)';
    ctx.beginPath(); ctx.ellipse(-8, -132, 12, 14, 0, 0, TAU); ctx.fill();
    ctx.fillRect(-26, -120, 36, 20);
  }
  ctx.restore();
  // stalpul dintre usi
  ctx.fillStyle = '#12171b'; ctx.fillRect(-26, -160, 8, 56);
  // linia usilor
  ctx.strokeStyle = 'rgba(0,0,0,0.5)'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(-138, -102); ctx.lineTo(-136, -38); ctx.moveTo(-22, -104); ctx.lineTo(-20, -38); ctx.moveTo(96, -104); ctx.lineTo(92, -40); ctx.stroke();
  // dunga verde + textul factiunii
  ctx.save();
  glow(ctx, hexA(C.primary, 0.8), 10);
  ctx.fillStyle = C.primary; ctx.fillRect(-238, -76, 480, 5);
  noGlow(ctx);
  ctx.restore();
  text(ctx, 'SCHOOL INSTRUCTORS', -24, -54, { font: F.hud(19, 700), color: 'rgba(230,240,235,0.85)', align: 'center', ls: 2 });
  // clanta, oglinda
  fillRR(ctx, -58, -94, 16, 4, 2, '#8b959d'); fillRR(ctx, 60, -94, 16, 4, 2, '#8b959d');
  fillRR(ctx, 88, -120, 16, 12, 3, '#1b2126');
  // faruri / stopuri
  ctx.save();
  glow(ctx, 'rgba(255,245,210,0.9)', o.lights ? 30 : 8);
  fillRR(ctx, 226, -88, 18, 12, 4, '#fff6dc');
  glow(ctx, 'rgba(255,40,40,0.9)', o.brake ? 34 : 10);
  fillRR(ctx, -246, -88, 12, 14, 3, o.brake ? '#ff3a3a' : '#b01818');
  noGlow(ctx);
  ctx.restore();
  // bara de protectie
  fillRR(ctx, 214, -46, 34, 10, 4, '#0f1316'); fillRR(ctx, -248, -46, 34, 10, 4, '#0f1316');
  // roti
  const wheel = (wx) => {
    ctx.save();
    ctx.translate(wx, -40);
    circle(ctx, 0, 0, 47, '#0a0c0e');
    circle(ctx, 0, 0, 39, '#141618');
    circle(ctx, 0, 0, 25, '#9aa3aa');
    circle(ctx, 0, 0, 21, '#5b646b');
    ctx.rotate(o.wheelRot || 0);
    ctx.strokeStyle = '#b8c1c8'; ctx.lineWidth = 5; ctx.lineCap = 'round';
    for (let i = 0; i < 5; i++) { ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -19); ctx.stroke(); ctx.rotate(TAU / 5); }
    circle(ctx, 0, 0, 5, '#30373c');
    ctx.restore();
  };
  // arcadele rotilor
  ctx.fillStyle = '#07090b';
  ctx.beginPath(); ctx.arc(-148, -40, 50, Math.PI, TAU); ctx.fill();
  ctx.beginPath(); ctx.arc(148, -40, 50, Math.PI, TAU); ctx.fill();
  wheel(-148); wheel(148);
  // fasciculul farurilor
  if (o.lights) {
    ctx.save();
    ctx.globalCompositeOperation = 'lighter';
    const lg = ctx.createLinearGradient(240, 0, 700, 0);
    lg.addColorStop(0, 'rgba(255,240,200,0.35)'); lg.addColorStop(1, 'rgba(255,240,200,0)');
    ctx.fillStyle = lg;
    ctx.beginPath(); ctx.moveTo(240, -86); ctx.lineTo(720, -140); ctx.lineTo(720, 20); ctx.lineTo(240, -74); ctx.closePath(); ctx.fill();
    ctx.restore();
  }
  ctx.restore();
}

// masina vazuta de sus (pe harta), fata in sus
function drawCarTop(ctx, x, y, rot, s, o = {}) {
  ctx.save();
  ctx.translate(x, y); ctx.rotate(rot); ctx.scale(s, s);
  // fasciculul farurilor
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  const lg = ctx.createRadialGradient(0, -40, 5, 0, -120, 150);
  lg.addColorStop(0, 'rgba(255,240,200,0.35)'); lg.addColorStop(1, 'rgba(255,240,200,0)');
  ctx.fillStyle = lg;
  ctx.beginPath(); ctx.moveTo(-14, -40); ctx.lineTo(-70, -210); ctx.lineTo(70, -210); ctx.lineTo(14, -40); ctx.closePath(); ctx.fill();
  ctx.restore();
  glow(ctx, hexA(C.primary, 0.9), 22);
  fillRR(ctx, -22, -44, 44, 88, 12, '#252c32');
  noGlow(ctx);
  strokeRR(ctx, -22, -44, 44, 88, 12, C.primary, 2);
  fillRR(ctx, -17, -24, 34, 18, 5, '#0d1418');  // parbriz
  fillRR(ctx, -18, -4, 36, 28, 5, '#343d45');   // plafon
  fillRR(ctx, -16, 26, 32, 10, 4, '#0d1418');   // luneta
  ctx.fillStyle = C.primary; ctx.fillRect(-2, -44, 4, 88);
  fillRR(ctx, -19, -44, 9, 5, 2, '#fff6dc'); fillRR(ctx, 10, -44, 9, 5, 2, '#fff6dc');
  fillRR(ctx, -19, 40, 9, 4, 2, '#ff3a3a'); fillRR(ctx, 10, 40, 9, 4, 2, '#ff3a3a');
  ctx.restore();
}

// ============================================================
// STRADA (apus in Los Santos), cu parallax
// ============================================================
const STREET = {};
function initStreet() {
  const rnd = mulberry32(77);
  // orizontul indepartat: blocuri din downtown
  const sk = makeCanvas(3600, 900), g = sk.getContext('2d');
  for (let i = 0; i < 70; i++) {
    const bw = 60 + rnd() * 150, bh = 140 + rnd() * 560 * (rnd() < 0.25 ? 1.3 : 0.7);
    const bx = rnd() * 3600;
    g.fillStyle = `rgba(${58 + rnd() * 16},${34 + rnd() * 10},${66 + rnd() * 16},1)`;
    g.fillRect(bx, 900 - bh, bw, bh);
    for (let k = 0; k < bh / 26; k++) for (let j = 0; j < bw / 20; j++) {
      if (rnd() < 0.12) { g.fillStyle = `rgba(255,${190 + rnd() * 50},120,${0.35 + rnd() * 0.4})`; g.fillRect(bx + 6 + j * 20, 900 - bh + 10 + k * 26, 7, 10); }
    }
  }
  STREET.skyline = sk;
  // case (Grove Street), palmieri
  const hs = makeCanvas(4200, 900), h = hs.getContext('2d');
  const house = (x0, w, hh, c1, c2) => {
    h.fillStyle = c1; h.fillRect(x0, 900 - hh, w, hh);
    h.fillStyle = c2; h.beginPath(); h.moveTo(x0 - 20, 900 - hh); h.lineTo(x0 + w / 2, 900 - hh - 90); h.lineTo(x0 + w + 20, 900 - hh); h.closePath(); h.fill();
    // ferestre calde
    for (let i = 0; i < 3; i++) {
      const wx = x0 + 30 + i * (w - 60) / 2.4, wy = 900 - hh + 50;
      h.fillStyle = rnd() < 0.7 ? 'rgba(255,196,120,0.85)' : 'rgba(60,40,50,1)';
      h.fillRect(wx, wy, 44, 56);
      h.fillStyle = 'rgba(40,24,30,0.9)'; h.fillRect(wx + 20, wy, 4, 56); h.fillRect(wx, wy + 26, 44, 4);
    }
    // veranda
    h.fillStyle = c2; h.fillRect(x0 + w * 0.15, 900 - 150, w * 0.7, 14);
    h.fillRect(x0 + w * 0.18, 900 - 150, 10, 150); h.fillRect(x0 + w * 0.82 - 10, 900 - 150, 10, 150);
    h.fillStyle = 'rgba(30,18,24,1)'; h.fillRect(x0 + w / 2 - 26, 900 - 120, 52, 120);
  };
  const cols = [['#5a3a4c', '#3b2533'], ['#4f3a52', '#34243a'], ['#5d4150', '#3e2735'], ['#4a3446', '#2f1f2d']];
  let x = 40;
  while (x < 4100) {
    const w = 330 + rnd() * 140, hh = 300 + rnd() * 120;
    const c = cols[Math.floor(rnd() * cols.length)];
    house(x, w, hh, c[0], c[1]);
    x += w + 90 + rnd() * 120;
  }
  STREET.houses = hs;
  // palmieri (silueta)
  const pc = makeCanvas(4200, 1500), p = pc.getContext('2d');
  const palm = (px, ph, lean) => {
    p.strokeStyle = '#26172a'; p.lineCap = 'round';
    p.lineWidth = 18;
    p.beginPath(); p.moveTo(px, 1500); p.quadraticCurveTo(px + lean * 0.4, 1500 - ph * 0.6, px + lean, 1500 - ph); p.stroke();
    const tx = px + lean, ty = 1500 - ph;
    p.fillStyle = '#26172a';
    for (let i = 0; i < 9; i++) {
      const a = -Math.PI / 2 + (i - 4) * 0.42 + (rnd() - 0.5) * 0.2;
      const L = 150 + rnd() * 60;
      p.beginPath(); p.moveTo(tx, ty);
      p.quadraticCurveTo(tx + Math.cos(a) * L * 0.6, ty + Math.sin(a) * L * 0.6 - 30, tx + Math.cos(a) * L, ty + Math.sin(a) * L + 40);
      p.quadraticCurveTo(tx + Math.cos(a) * L * 0.55, ty + Math.sin(a) * L * 0.55 - 5, tx, ty + 8);
      p.fill();
    }
    circle(p, tx, ty + 6, 16, '#26172a');
  };
  for (let i = 0; i < 9; i++) palm(200 + i * 470 + rnd() * 120, 820 + rnd() * 420, (rnd() - 0.5) * 140);
  STREET.palms = pc;
}

// cam: { x, zoom } ; tint 0..1 = cat de tarziu e (apus -> amurg)
function drawStreet(ctx, cam, tint = 0) {
  const gy = cam.sy ?? H * 0.69; // linia trotuarului pe ecran
  const z = cam.zoom || 1;
  // cerul
  const sky = ctx.createLinearGradient(0, 0, 0, gy);
  sky.addColorStop(0, mixHex('#1a1233', '#0c0a1e', tint));
  sky.addColorStop(0.45, mixHex('#5b2a58', '#35204a', tint));
  sky.addColorStop(0.78, mixHex('#e0714a', '#b04a4a', tint));
  sky.addColorStop(1, mixHex('#f7b267', '#d9894e', tint));
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
  const L = (p, fn) => { // strat cu parallax: p=0 fix, p=1 se misca odata cu camera
    ctx.save();
    ctx.translate(W / 2, gy);
    ctx.scale(lerp(1, z, p), lerp(1, z, p));
    ctx.translate(-cam.x * p, -(cam.y || 0) * p);
    fn();
    ctx.restore();
  };
  // soarele
  L(0.05, () => {
    const sgr = ctx.createRadialGradient(230, -330, 10, 230, -330, 420);
    sgr.addColorStop(0, 'rgba(255,226,160,0.95)'); sgr.addColorStop(0.18, 'rgba(255,190,110,0.6)'); sgr.addColorStop(1, 'rgba(255,150,90,0)');
    ctx.fillStyle = sgr; ctx.fillRect(-400, -800, 1300, 900);
    circle(ctx, 230, -330, 110, 'rgba(255,236,190,0.95)');
  });
  L(0.15, () => { ctx.globalAlpha = 0.85; ctx.drawImage(STREET.skyline, -1800, -150 - 900 + 60); ctx.globalAlpha = 1; });
  // ceata de la orizont
  const haze = ctx.createLinearGradient(0, gy - 420, 0, gy - 60);
  haze.addColorStop(0, 'rgba(247,178,103,0)'); haze.addColorStop(1, `rgba(${Math.round(lerp(240, 200, tint))},140,100,0.35)`);
  ctx.fillStyle = haze; ctx.fillRect(0, gy - 420, W, 360);
  L(0.45, () => ctx.drawImage(STREET.palms, -2100, -1500 + 10));
  L(0.6, () => ctx.drawImage(STREET.houses, -2100, -900 + 8));
  L(1, () => {
    // gardul si trotuarul
    ctx.fillStyle = '#2d1c28'; ctx.fillRect(-3000, -60, 6000, 44);
    for (let i = -3000; i < 3000; i += 38) { ctx.fillStyle = '#3a2533'; ctx.fillRect(i, -92, 8, 76); }
    ctx.fillStyle = '#3a2533'; ctx.fillRect(-3000, -82, 6000, 6);
    const sw = ctx.createLinearGradient(0, -18, 0, 70);
    sw.addColorStop(0, '#8a6a70'); sw.addColorStop(1, '#6a4e58');
    ctx.fillStyle = sw; ctx.fillRect(-3000, -18, 6000, 88);
    ctx.strokeStyle = 'rgba(40,24,32,0.35)'; ctx.lineWidth = 2;
    for (let i = -3000; i < 3000; i += 120) { ctx.beginPath(); ctx.moveTo(i, -18); ctx.lineTo(i - 30, 70); ctx.stroke(); }
    ctx.fillStyle = '#c9a9a0'; ctx.fillRect(-3000, 64, 6000, 10); // bordura
    const rd = ctx.createLinearGradient(0, 74, 0, 900);
    rd.addColorStop(0, '#3a2c3a'); rd.addColorStop(1, '#1c1522');
    ctx.fillStyle = rd; ctx.fillRect(-3000, 74, 6000, 1400);
    // marcajul
    ctx.fillStyle = 'rgba(240,200,120,0.75)';
    for (let i = -3000; i < 3000; i += 200) ctx.fillRect(i, 330, 110, 10);
    // stalpul de iluminat
    for (const lx of [-520, 900]) {
      ctx.fillStyle = '#1d1420'; ctx.fillRect(lx, -620, 12, 620);
      ctx.fillRect(lx, -620, 120, 10);
      const lgw = ctx.createRadialGradient(lx + 110, -600, 5, lx + 110, -600, 220);
      lgw.addColorStop(0, `rgba(255,220,160,${0.25 + tint * 0.5})`); lgw.addColorStop(1, 'rgba(255,220,160,0)');
      ctx.fillStyle = lgw; ctx.fillRect(lx - 120, -830, 460, 460);
      fillRR(ctx, lx + 92, -612, 38, 12, 4, '#ffe6b0');
    }
  });
}

// ============================================================
// SEDIUL SCHOOL INSTRUCTORS (noapte)
// ============================================================
const HQ = {};
function initHQ() {
  const rnd = mulberry32(9);
  const c = makeCanvas(2400, 1500), g = c.getContext('2d');
  // cladirea
  const bg = g.createLinearGradient(0, 0, 0, 1500);
  bg.addColorStop(0, '#1a222a'); bg.addColorStop(1, '#10161b');
  g.fillStyle = bg; g.fillRect(200, 180, 2000, 1320);
  g.fillStyle = '#232d36'; g.fillRect(180, 160, 2040, 30);
  // ferestrele
  for (let r = 0; r < 5; r++) for (let k = 0; k < 14; k++) {
    const wx = 260 + k * 138, wy = 470 + r * 150;
    if (wy > 1180) continue;
    const lit = rnd() < 0.55;
    g.fillStyle = lit ? (rnd() < 0.3 ? 'rgba(160,255,210,0.55)' : 'rgba(210,225,235,0.5)') : '#0b1015';
    g.fillRect(wx, wy, 96, 100);
    g.fillStyle = '#141b21'; g.fillRect(wx + 46, wy, 5, 100); g.fillRect(wx, wy + 48, 96, 5);
  }
  // intrarea
  g.fillStyle = '#0a1210'; g.fillRect(1000, 1200, 400, 300);
  const eg = g.createLinearGradient(0, 1200, 0, 1500);
  eg.addColorStop(0, 'rgba(0,217,106,0.35)'); eg.addColorStop(1, 'rgba(0,217,106,0.05)');
  g.fillStyle = eg; g.fillRect(1010, 1210, 380, 290);
  g.fillStyle = '#16211c'; g.fillRect(1196, 1210, 8, 290);
  g.fillStyle = '#2a343c'; g.fillRect(960, 1180, 480, 24);
  HQ.building = c;
}
function drawHQ(ctx, cam, t) {
  const gy = cam.sy ?? H * 0.69;
  const sky = ctx.createLinearGradient(0, 0, 0, gy);
  sky.addColorStop(0, '#05070d'); sky.addColorStop(0.6, '#0b1422'); sky.addColorStop(1, '#16283a');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H);
  const rnd = mulberry32(3);
  for (let i = 0; i < 70; i++) { const sx = rnd() * W, sy = rnd() * gy * 0.5; ctx.globalAlpha = 0.3 + 0.5 * Math.abs(Math.sin(t * 1.5 + i)); circle(ctx, sx, sy, rnd() * 1.6 + 0.4, '#dfe8ff'); }
  ctx.globalAlpha = 1;
  const z = cam.zoom || 1;
  ctx.save();
  ctx.translate(W / 2, gy); ctx.scale(z, z); ctx.translate(-cam.x, -(cam.y || 0));
  ctx.globalAlpha = 1;
  ctx.drawImage(HQ.building, -1200, -1500 + 4);
  // firma cu neon
  ctx.save();
  const fl = 0.85 + 0.15 * Math.sin(t * 17) * Math.sin(t * 5.3);
  glow(ctx, hexA(C.primary, 0.95 * fl), 40);
  text(ctx, 'SCHOOL INSTRUCTORS', 0, -840, { font: F.hud(84, 700), color: mixHex('#b8ffd9', '#6EF2AC', 0.3), align: 'center', ls: 5 });
  icon(ctx, 'cap', -520, -868, 60, C.accent);
  noGlow(ctx);
  ctx.restore();
  // asfaltul parcarii
  const ag = ctx.createLinearGradient(0, 0, 0, 900);
  ag.addColorStop(0, '#20262c'); ag.addColorStop(1, '#0d1013');
  ctx.fillStyle = ag; ctx.fillRect(-2000, 0, 4000, 1400);
  ctx.fillStyle = 'rgba(220,230,235,0.45)';
  for (let i = -1400; i < 1400; i += 300) { ctx.save(); ctx.translate(i, 60); ctx.transform(1, 0, -0.5, 1, 0, 0); ctx.fillRect(0, 0, 10, 380); ctx.restore(); }
  // lumina verde de la intrare pe asfalt
  const lg = ctx.createRadialGradient(0, 20, 20, 0, 20, 700);
  lg.addColorStop(0, 'rgba(0,217,106,0.22)'); lg.addColorStop(1, 'rgba(0,217,106,0)');
  ctx.fillStyle = lg; ctx.fillRect(-900, -300, 1800, 900);
  ctx.restore();
}

// ============================================================
// HARTA (vedere de sus, stil radar), 1 m = MAP.PPM px
// ============================================================
const MAP = { PPM: 1.6 };
function initMap() {
  const S = 4000, c = makeCanvas(S, S), g = c.getContext('2d');
  const O = S / 2; // originea hartii in mijlocul canvasului
  MAP.canvas = c; MAP.O = O;
  const rnd = mulberry32(42);
  g.fillStyle = '#0b1014'; g.fillRect(0, 0, S, S);
  // apa (coasta) la est
  g.fillStyle = '#081725'; g.fillRect(O + 1150, 0, S, S);
  g.strokeStyle = 'rgba(80,160,220,0.12)'; g.lineWidth = 2;
  for (let i = 0; i < S; i += 40) { g.beginPath(); g.moveTo(O + 1180 + (i % 80), i); g.lineTo(S, i + 30); g.stroke(); }
  const GRID = 300, RW = 46;
  // blocurile dintre drumuri
  for (let gx = -6; gx < 4; gx++) for (let gyi = -6; gyi < 6; gyi++) {
    const x0 = O + gx * GRID + RW / 2, y0 = O + gyi * GRID + RW / 2, bw = GRID - RW;
    if (x0 + bw > O + 1150) continue;
    const r = rnd();
    if (r < 0.14) { g.fillStyle = '#0f2419'; g.fillRect(x0, y0, bw, bw); // parc
      for (let k = 0; k < 14; k++) circle(g, x0 + 20 + rnd() * (bw - 40), y0 + 20 + rnd() * (bw - 40), 8 + rnd() * 10, '#143322');
      continue; }
    g.fillStyle = '#121a20'; g.fillRect(x0, y0, bw, bw);
    // cladiri in bloc
    const n = 2 + Math.floor(rnd() * 3);
    for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
      const cw = bw / n;
      g.fillStyle = `rgb(${22 + rnd() * 10},${30 + rnd() * 10},${38 + rnd() * 12})`;
      g.fillRect(x0 + i * cw + 8, y0 + j * cw + 8, cw - 16, cw - 16);
      g.fillStyle = 'rgba(255,255,255,0.03)'; g.fillRect(x0 + i * cw + 8, y0 + j * cw + 8, cw - 16, 4);
    }
  }
  // drumurile
  for (let k = -6; k <= 4; k++) {
    const xk = O + k * GRID;
    g.fillStyle = '#26303a'; g.fillRect(xk - RW / 2, 0, RW, S);
    g.fillStyle = 'rgba(230,200,120,0.25)'; for (let i = 0; i < S; i += 40) g.fillRect(xk - 1.5, i, 3, 20);
  }
  for (let k = -7; k <= 7; k++) {
    const yk = O + k * GRID;
    g.fillStyle = '#26303a'; g.fillRect(0, yk - RW / 2, O + 1150, RW);
    g.fillStyle = 'rgba(230,200,120,0.25)'; for (let i = 0; i < O + 1150; i += 40) g.fillRect(i, yk - 1.5, 20, 3);
  }
  // bulevardul in diagonala
  g.save(); g.translate(O - 900, O + 1500); g.rotate(-Math.PI / 4);
  g.fillStyle = '#2b3642'; g.fillRect(0, -32, 3000, 64);
  g.fillStyle = 'rgba(230,200,120,0.3)'; for (let i = 0; i < 3000; i += 50) g.fillRect(i, -2, 26, 4);
  g.restore();
  // traseul: coordonate de harta (px, fata de origine)
  const pts = [[-600, 900], [-600, 300], [300, 300], [300, -300], [300, -330]];
  MAP.route = buildRoute(pts, 60);
  MAP.len = MAP.route[MAP.route.length - 1].s;
  MAP.target = { x: 300 + 44, y: -330 };
}
// polilinie cu colturi rotunjite, esantionata; fiecare punct are s (lungimea de arc)
function buildRoute(pts, r) {
  const out = [];
  const push = (x, y) => { const p = out[out.length - 1]; const s = p ? p.s + Math.hypot(x - p.x, y - p.y) : 0; out.push({ x, y, s }); };
  push(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i - 1], [bx, by] = pts[i], [cx, cy] = pts[i + 1];
    const d1 = Math.hypot(bx - ax, by - ay), d2 = Math.hypot(cx - bx, cy - by);
    const u1 = [(bx - ax) / d1, (by - ay) / d1], u2 = [(cx - bx) / d2, (cy - by) / d2];
    const rr2 = Math.min(r, d1 / 2, d2 / 2);
    const p1 = [bx - u1[0] * rr2, by - u1[1] * rr2], p2 = [bx + u2[0] * rr2, by + u2[1] * rr2];
    // linie pana la p1 (in pasi mici)
    const last = out[out.length - 1];
    const L = Math.hypot(p1[0] - last.x, p1[1] - last.y);
    for (let k = 1; k <= Math.ceil(L / 8); k++) { const f = k / Math.ceil(L / 8); push(lerp(last.x, p1[0], f), lerp(last.y, p1[1], f)); }
    for (let k = 1; k <= 12; k++) { const f = k / 12; // bezier patratic prin colt
      const x = (1 - f) * (1 - f) * p1[0] + 2 * (1 - f) * f * bx + f * f * p2[0];
      const y = (1 - f) * (1 - f) * p1[1] + 2 * (1 - f) * f * by + f * f * p2[1];
      push(x, y); }
  }
  const last = out[out.length - 1], end = pts[pts.length - 1];
  const L = Math.hypot(end[0] - last.x, end[1] - last.y);
  for (let k = 1; k <= Math.ceil(L / 8); k++) { const f = k / Math.ceil(L / 8); push(lerp(last.x, end[0], f), lerp(last.y, end[1], f)); }
  return out;
}
function routeAt(s) {
  const R = MAP.route;
  s = clamp(s, 0, MAP.len);
  let i = 1;
  while (i < R.length - 1 && R[i].s < s) i++;
  const a = R[i - 1], b = R[i];
  const f = (s - a.s) / Math.max(1e-6, b.s - a.s);
  return { x: lerp(a.x, b.x, f), y: lerp(a.y, b.y, f), ang: Math.atan2(b.y - a.y, b.x - a.x) };
}

// ============================================================
// FUNDALUL "JARVIS": grila hexagonala, inele, particule
// ============================================================
const JV = {};
function initJarvis() {
  const c = makeCanvas(W, H + 200), g = c.getContext('2d');
  g.strokeStyle = 'rgba(110,242,172,0.07)'; g.lineWidth = 1.2;
  const r = 34, hw = Math.sqrt(3) * r;
  for (let row = 0; row < (H + 200) / (1.5 * r) + 2; row++) for (let col = -1; col < W / hw + 2; col++) {
    const cx = col * hw + (row % 2 ? hw / 2 : 0), cy = row * 1.5 * r;
    g.beginPath();
    for (let k = 0; k < 6; k++) { const a = Math.PI / 6 + k * Math.PI / 3; const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a); k ? g.lineTo(x, y) : g.moveTo(x, y); }
    g.closePath(); g.stroke();
  }
  JV.hex = c;
}
function drawJarvisBG(ctx, t, o = {}) {
  const bg = ctx.createRadialGradient(W / 2, H * 0.45, 50, W / 2, H * 0.45, H * 0.75);
  bg.addColorStop(0, '#07231a'); bg.addColorStop(0.5, '#03110c'); bg.addColorStop(1, '#010604');
  ctx.fillStyle = bg; ctx.fillRect(0, 0, W, H);
  ctx.save();
  ctx.globalAlpha = o.hexA ?? 1;
  ctx.drawImage(JV.hex, 0, -((t * 30) % (1.5 * 34 * 2)));
  ctx.restore();
  // inelele rotative
  const cx = o.cx ?? W / 2, cy = o.cy ?? H * 0.45, k = o.rings ?? 1;
  if (k > 0) {
    ctx.save();
    ctx.globalAlpha = 0.55 * k;
    ctx.translate(cx, cy);
    const rings = [[330, 2, 0.25, [40, 18]], [372, 6, -0.18, [4, 14]], [420, 1.5, 0.1, [200, 40, 20, 40]], [470, 10, -0.06, [2, 22]], [520, 2, 0.14, [120, 60]]];
    rings.forEach(([rad, lw, sp, dash], i) => {
      ctx.save(); ctx.rotate(t * sp * TAU * 0.3 + i);
      ctx.setLineDash(dash); ctx.strokeStyle = i % 2 ? C.jarvisDeep : C.jarvis; ctx.lineWidth = lw;
      ctx.beginPath(); ctx.arc(0, 0, rad * (o.ringScale || 1), 0, TAU); ctx.stroke();
      ctx.restore();
    });
    ctx.setLineDash([]);
    // gradatiile
    ctx.strokeStyle = hexA(C.jarvis, 0.6); ctx.lineWidth = 2;
    for (let i = 0; i < 72; i++) { const a = i / 72 * TAU + t * 0.2; const r1 = 560 * (o.ringScale || 1), r2 = r1 + (i % 6 ? 8 : 20); ctx.beginPath(); ctx.moveTo(Math.cos(a) * r1, Math.sin(a) * r1); ctx.lineTo(Math.cos(a) * r2, Math.sin(a) * r2); ctx.stroke(); }
    ctx.restore();
  }
  // particulele
  const rnd = mulberry32(5);
  ctx.save();
  for (let i = 0; i < 60; i++) {
    const px = rnd() * W, speed = 20 + rnd() * 60, py = (rnd() * H - t * speed) % H;
    ctx.globalAlpha = 0.25 + 0.35 * rnd();
    circle(ctx, px, py < 0 ? py + H : py, 1 + rnd() * 2, C.jarvis);
  }
  ctx.restore();
  // linia de scanare
  const sy = ((t * 0.35) % 1) * H;
  const sg = ctx.createLinearGradient(0, sy - 80, 0, sy);
  sg.addColorStop(0, 'rgba(110,242,172,0)'); sg.addColorStop(1, 'rgba(110,242,172,0.08)');
  ctx.fillStyle = sg; ctx.fillRect(0, sy - 80, W, 80);
}
function scanlines(ctx, a = 0.06) {
  ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = '#000';
  for (let y = 0; y < H; y += 4) ctx.fillRect(0, y, W, 2);
  ctx.restore();
}

// transformarea camerei pentru stratul din fata (personaje, masina)
function worldBegin(ctx, cam) {
  ctx.save();
  ctx.translate(W / 2, cam.sy ?? H * 0.69);
  ctx.scale(cam.zoom || 1, cam.zoom || 1);
  ctx.translate(-cam.x, -(cam.y || 0));
}
