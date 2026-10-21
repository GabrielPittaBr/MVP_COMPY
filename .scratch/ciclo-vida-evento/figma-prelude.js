// Prelúdio dos scripts use_figma do ticket 01 (arquivo dBrJFCVi0EkAWkBP2Zifmr, página 393:348).
// Cole no início de cada chamada; os componentes e as variáveis já existem no arquivo.
// Cores com transparência usam variáveis com alfa (tint/*, overlay/scrim, state/*, onPrimary/*):
// opacidade na pintura de uma cor ligada a variável é descartada pelo Figma.
const page = await figma.getNodeByIdAsync("393:348");
await figma.setCurrentPageAsync(page);
await Promise.all(["Regular", "Medium", "Semi Bold", "Bold"].map(s => figma.loadFontAsync({ family: "Inter", style: s })));
const V = {}; for (const v of await figma.variables.getLocalVariablesAsync("COLOR")) { V[v.name] = v; if (v.name.startsWith("color/")) V[v.name.slice(6)] = v; }
const MODE = (await figma.variables.getLocalVariableCollectionsAsync()).find(c => c.name === "COMPY").modes[0].modeId;
const hexc = h => ({ r: parseInt(h.slice(1,3),16)/255, g: parseInt(h.slice(3,5),16)/255, b: parseInt(h.slice(5,7),16)/255 });
function P(c) { if (c == null) return []; const s = typeof c === "string" ? { v: c } : c; if (s.v[0] === "#") return [{ type: "SOLID", color: hexc(s.v), opacity: s.op ?? 1 }]; if (s.op != null) throw new Error("use uma variável com alfa: " + s.v); const v = V[s.v]; const k = v.valuesByMode[MODE]; return [figma.variables.setBoundVariableForPaint({ type: "SOLID", color: { r: k.r, g: k.g, b: k.b } }, "color", v)]; }
const SZ = new Map();
function pad(f, p) { if (p == null) return; const a = typeof p === "number" ? [p,p,p,p] : p.length === 2 ? [p[0],p[1],p[0],p[1]] : p; [f.paddingTop, f.paddingRight, f.paddingBottom, f.paddingLeft] = a; }
function add(parent, k) { if (!k) return; parent.appendChild(k); const s = SZ.get(k.id); if (s) { if (s.w) k.layoutSizingHorizontal = s.w; if (s.h) k.layoutSizingVertical = s.h; if (k.type === "TEXT" && s.w === "FILL") k.textAutoResize = "HEIGHT"; } }
function F(dir, o = {}, kids = []) {
  const f = figma.createAutoLayout(dir === "H" ? "HORIZONTAL" : "VERTICAL");
  f.name = o.name || (dir === "H" ? "Linha" : "Coluna");
  f.fills = P(o.fill); f.clipsContent = !!o.clip;
  if (o.gap != null) f.itemSpacing = o.gap;
  pad(f, o.pad);
  if (o.r != null) f.cornerRadius = o.r;
  if (o.stroke) { f.strokes = P(o.stroke); f.strokeWeight = o.sw || 1; f.strokeAlign = o.sa || "INSIDE"; }
  if (o.sides) { f.strokes = P(o.sides.c); f.strokeAlign = "INSIDE"; f.strokeTopWeight = o.sides.t || 0; f.strokeBottomWeight = o.sides.b || 0; f.strokeLeftWeight = 0; f.strokeRightWeight = 0; }
  if (o.align) f.counterAxisAlignItems = o.align;
  if (o.justify) f.primaryAxisAlignItems = o.justify;
  if (o.w != null || o.h != null) { f.resize(o.w ?? f.width, o.h ?? f.height); f.layoutSizingHorizontal = o.w != null ? "FIXED" : "HUG"; f.layoutSizingVertical = o.h != null ? "FIXED" : "HUG"; }
  if (o.wrap) { f.layoutWrap = "WRAP"; f.counterAxisSpacing = o.gap || 0; }
  if (o.effects) f.effects = o.effects;
  for (const k of kids) add(f, k);
  SZ.set(f.id, { w: o.fw ? "FILL" : null, h: o.fh ? "FILL" : null });
  return f;
}
function T(chars, o = {}) {
  const t = figma.createText();
  t.fontName = { family: "Inter", style: o.wt || "Regular" };
  t.characters = chars; t.fontSize = o.size || 14; t.fills = P(o.color || "onSurface");
  if (o.lh) t.lineHeight = { unit: "PERCENT", value: o.lh * 100 };
  if (o.ls != null) t.letterSpacing = { unit: "PERCENT", value: o.ls };
  if (o.align) t.textAlignHorizontal = o.align;
  if (o.w) { t.resize(o.w, t.height); t.textAutoResize = "HEIGHT"; }
  t.name = o.name || chars.slice(0, 40);
  SZ.set(t.id, { w: o.fill ? "FILL" : null });
  return t;
}
const S = h => F("V", { w: 1, h, name: "espaço" });
const IC = {}, SET = {}, COMP = {};
for (const c of page.findAllWithCriteria({ types: ["COMPONENT"] })) { if (c.name.startsWith("icon/")) IC[c.name.slice(5)] = c; else if (c.parent.type !== "COMPONENT_SET") COMP[c.name] = c; }
for (const s of page.findAllWithCriteria({ types: ["COMPONENT_SET"] })) SET[s.name] = s;
function recolor(i, c) { for (const ch of i.findAll(n => n.type === "VECTOR")) ch.fills = P(c); }
function I(name, size = 24, color = "onSurface") { const i = IC[name].createInstance(); if (size !== 24) i.resize(size, size); recolor(i, color); return i; }
function inst(setName, variant) { return SET[setName].children.find(c => c.name === variant).createInstance(); }
function setP(i, props) { const map = {}; for (const k of Object.keys(i.componentProperties)) map[k.split("#")[0]] = k; const o = {}; for (const [k, v] of Object.entries(props)) o[map[k]] = v; i.setProperties(o); return i; }
const nested = (i, prefix) => i.findOne(n => n.type === "INSTANCE" && n.name.startsWith(prefix));
const fillW = n => { SZ.set(n.id, { w: "FILL" }); return n; };
function avatar(size, letter, ring) { const a = inst("Avatar", "Tamanho=" + size); setP(a, { Inicial: letter }); if (ring) { a.strokes = P(ring); a.strokeWeight = 2; a.strokeAlign = "OUTSIDE"; } return a; }
function star(filled, size) { const s = inst("Estrela", filled ? "Estado=Cheia" : "Estado=Vazia"); s.resize(size, size); s.findOne(n => n.type === "VECTOR").strokeWeight = (filled ? 1.1 : 1.3) * size / 24; return s; }
function btn(tipo, label, icon, iconColor) { const b = inst("Botão", "Tipo=" + tipo); setP(b, { "Rótulo": label, "Mostrar ícone": !!icon }); if (icon) { setP(b, { "Ícone": IC[icon].id }); recolor(b.findOne(n => n.type === "INSTANCE"), iconColor || (tipo === "Primário" ? "background" : "primary")); } return fillW(b); }
const tbtn = (label, color = "primary", h = 40) => F("H", { h, pad: [0, 6], align: "CENTER", name: label }, [T(label, { size: 14, wt: "Semi Bold", color })]);
const slot = (icon, color = "onSurface", size = 24) => F("H", { w: 44, h: 44, r: 22, align: "CENTER", justify: "CENTER", name: icon }, [I(icon, size, color)]);
function appBar(left, title, right, o = {}) { return F("H", { w: 390, h: o.h || 64, pad: [0, 8], align: "CENTER", fill: o.fill, name: "AppBar" }, [F("H", { w: 48, h: 44, align: "CENTER" }, left ? [slot(left)] : []), T(title, { size: o.size || 20, wt: "Semi Bold", align: "CENTER", fill: true, name: "titulo" }), F("H", { w: 48, h: 44, align: "CENTER", justify: "MAX" }, right ? [slot(right, o.rightColor)] : [])]); }
const screen = (name, h = 844) => F("V", { w: 390, h, fill: "background", clip: true, name });
const nav = aba => inst("NavBar", "Aba=" + aba);
const shadow = (y, blur, a) => ({ type: "DROP_SHADOW", color: { r: 0.04, g: 0.04, b: 0.04, a }, offset: { x: 0, y }, radius: blur, spread: 0, visible: true, blendMode: "NORMAL" });
const PROG = [];
function bar(h, bg, fg, pct) { const f = F("H", { w: 10, h, r: h / 2, fill: fg, name: "progresso" }); const b = F("H", { h, r: h / 2, fill: bg, clip: true, fw: true, name: "barra" }, [f]); PROG.push([b, f, pct]); return b; }
function fixBars() { for (const [b, f, pct] of PROG.splice(0)) f.resize(Math.max(1, Math.round(b.width * pct)), f.height); }
function overlay(scr, dialog) { const ov = F("V", { w: 390, h: scr.height, fill: "overlay/scrim", align: "CENTER", justify: "CENTER", pad: [0, 28], name: "Scrim" }, [dialog]); scr.appendChild(ov); ov.layoutPositioning = "ABSOLUTE"; ov.x = 0; ov.y = 0; return ov; }
const dialogBox = (kids, padding = 24, gap = 16) => F("V", { fw: true, r: 28, fill: "background", pad: padding, gap, effects: [shadow(12, 32, 0.24)], name: "Diálogo" }, kids);
function makeSection(name, y, h) { const s = figma.createSection(); s.name = name; s.x = 0; s.y = y; s.resizeWithoutConstraints(1960, h); return s; }
function place(section, board, i) { section.appendChild(board); board.x = 80 + i * 470; board.y = 80; }
function sportCircle(sp, size, iconSize) { const s = inst("Ícone de esporte", "Esporte=" + sp); s.resize(size, size); s.cornerRadius = size / 2; nested(s, "icon/").resize(iconSize, iconSize); return s; }
function notif(state, title, body, time, sport) { const n = inst("Item de notificação", "Estado=" + state); setP(n, { "Título": title, "Corpo": body, "Tempo": time }); setP(nested(n, "Ícone de esporte"), { Esporte: sport }); return fillW(n); }
