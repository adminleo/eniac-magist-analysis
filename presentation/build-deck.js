const pptxgen = require("pptxgenjs");

const THEME = {
  name: "Magist Decision",
  headFontFace: "Cambria", bodyFontFace: "Calibri",
  colors: {
    dk1: "12302B", lt1: "FFFFFF", dk2: "0B4F4A", lt2: "EDF4F1",
    accent1: "0B4F4A", accent2: "C2541B", accent3: "7FB7A3",
    accent4: "D9A441", accent5: "5A7D78", accent6: "9AA7A4",
    hlink: "0B5351", folHlink: "5A7D78",
  },
};
const TEAL = "0B4F4A", ORANGE = "C2541B", SAGE = "7FB7A3", MIST = "EDF4F1",
      INK = "12302B", MUTED = "5A7D78", WHITE = "FFFFFF";

const pres = new pptxgen();
pres.layout = "LAYOUT_16x9";              // 10 x 5.625 in — matches Google Slides
pres.theme = { headFontFace: THEME.headFontFace, bodyFontFace: THEME.bodyFontFace };
pres.author = "Eniac Data Analytics";
pres.title  = "Brazil market entry — the Magist decision";

const C = pres.SchemeColor;

pres.defineSlideMaster({
  title: "DARK", background: { color: TEAL },
  objects: [
    { text: { text: "Eniac · Data Analytics", options: {
      x: 0.55, y: 5.0, w: 5, h: 0.3, fontSize: 10, color: SAGE, isTextBox: true, margin: 0 } } },
  ],
  slideNumber: { x: 8.95, y: 5.0, fontSize: 10, color: SAGE },
});

pres.defineSlideMaster({
  title: "LIGHT", background: { color: WHITE },
  objects: [
    { placeholder: { options: { name: "title", type: "title",
        x: 0.55, y: 0.36, w: 8.9, h: 0.8, fontSize: 30, bold: true,
        color: INK, align: "left", valign: "middle", margin: 0 }, text: " " } },
  ],
  slideNumber: { x: 8.95, y: 5.05, fontSize: 10, color: MUTED },
});

/* ---------- small composition helpers ---------- */
const statCard = (s, { x, y, w, h, value, label, tone }) => {
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.08, fill: { color: tone === "warn" ? "FBEFE8" : MIST },
    line: { color: tone === "warn" ? "F0D6C6" : "DCE8E3", width: 0.75 },
    objectName: `card-${label}`,
  });
  s.addText(value, { x: x + 0.12, y: y + 0.12, w: w - 0.24, h: 0.46, fontSize: 26, bold: true,
    color: tone === "warn" ? ORANGE : TEAL, align: "center", isTextBox: true, margin: 0 });
  s.addText(label, { x: x + 0.1, y: y + 0.58, w: w - 0.2, h: 0.3, fontSize: 10.5,
    color: MUTED, align: "center", isTextBox: true, margin: 0 });
};

const chip = (s, { x, y, text, tone }) => {
  const bg = tone === "no" ? ORANGE : TEAL;
  s.addShape(pres.ShapeType.roundRect, { x, y, w: 1.25, h: 0.3, rectRadius: 0.15,
    fill: { color: bg }, line: { color: bg }, objectName: `chip-${text}` });
  s.addText(text, { x, y, w: 1.25, h: 0.3, fontSize: 10, bold: true, color: WHITE,
    align: "center", valign: "middle", charSpacing: 1, isTextBox: true, margin: 0 });
};

const chartBase = {
  showLegend: false, showTitle: false,
  catAxisLabelColor: MUTED, valAxisLabelColor: MUTED,
  catAxisLabelFontSize: 10, valAxisLabelFontSize: 10,
  catAxisLabelFontFace: "+mn-lt", valAxisLabelFontFace: "+mn-lt",
  dataLabelFontFace: "+mn-lt", dataLabelFontSize: 10,
  valGridLine: { color: "E6EDEA", size: 0.75 }, catGridLine: { style: "none" },
};

/* ================= 1 — title ================= */
let s = pres.addSlide({ masterName: "DARK", sectionTitle: "Decision" });
pres.addSection({ title: "Decision" });
s.addText("Brazil: sign with Magist?", { x: 0.55, y: 1.72, w: 8.6, h: 1.0,
  fontSize: 40, bold: true, color: WHITE, isTextBox: true, margin: 0 });
s.addText("Two objections. 99,441 orders of their data. One recommendation.",
  { x: 0.55, y: 2.72, w: 8.6, h: 0.4, fontSize: 16, color: MIST, isTextBox: true, margin: 0 });
s.addShape(pres.ShapeType.roundRect, { x: 0.55, y: 3.45, w: 2.9, h: 0.38, rectRadius: 0.19,
  fill: { color: "0E6159" }, line: { color: "0E6159" }, objectName: "window-chip" });
s.addText("Sep 2016 – Aug 2018", { x: 0.55, y: 3.45, w: 2.9, h: 0.38, fontSize: 11,
  color: SAGE, align: "center", valign: "middle", isTextBox: true, margin: 0 });
s.addNotes("Eniac wants Brazil within a year and cannot build a supply chain that fast. Magist offers one. Two objections were raised; we took both to their data.");

/* ================= 2 — scale ================= */
pres.addSection({ title: "Scale" });
s = pres.addSlide({ masterName: "LIGHT", sectionTitle: "Scale" });
s.addText("Magist is worth taking seriously", { placeholder: "title" });
[["99,441", "orders"], ["R$ 13.6m", "product revenue"],
 ["3,095", "active sellers"], ["8×", "growth in 20 months"]]
  .forEach(([v, l], i) => statCard(s, { x: 0.55 + i * 2.29, y: 1.2, w: 2.04, h: 0.95, value: v, label: l }));
s.addChart(pres.ChartType.line, [{
  name: "Delivered orders",
  labels: ["Jan 17","","Mar","","May","","Jul","","Sep","","Nov","","Jan 18","","Mar","","May","","Jul","Aug"],
  values: [750,1653,2546,2303,3546,3135,3872,4193,4150,4478,7289,5513,7069,6555,7003,6798,6749,6099,6159,6351],
}], { ...chartBase, x: 0.55, y: 2.45, w: 8.9, h: 2.4,
  chartColors: [TEAL], lineSize: 2.5, lineSmooth: false, showValue: false });
s.addText("Monthly delivered orders. Growth is real but flattens through 2018 at roughly 6,300 a month.",
  { x: 0.55, y: 4.88, w: 8.9, h: 0.3, fontSize: 10.5, color: MUTED, italic: true, isTextBox: true, margin: 0 });
s.addNotes("Whatever we decide, this is not a small player. Order volume grew eightfold in twenty months, then settled around 6,300 a month.");

/* ================= 3 — concern 1 ================= */
pres.addSection({ title: "Catalogue" });
s = pres.addSlide({ masterName: "LIGHT", sectionTitle: "Catalogue" });
s.addText("Right catalogue, wrong price class", { placeholder: "title" });

chip(s, { x: 0.55, y: 1.2, text: "TECH FITS", tone: "yes" });
s.addText([
  { text: "computers_accessories is the 5th biggest category on the whole platform", options: { bullet: true, breakLine: true } },
  { text: "R$ 912k revenue, 7,827 items sold", options: { bullet: true, breakLine: true } },
  { text: "Tech overall: 15.3 % of items, 13.9 % of revenue", options: { bullet: true } },
], { x: 0.55, y: 1.62, w: 4.3, h: 1.15, fontSize: 13, color: INK, paraSpaceAfter: 6, isTextBox: true, margin: 0 });

chip(s, { x: 0.55, y: 2.95, text: "PRICE DOESN'T", tone: "no" });
s.addText([
  { text: "Median item sells for R$ 74.99", options: { bullet: true, breakLine: true } },
  { text: "99th percentile is R$ 890 — a 2018 iPhone cost R$ 3,500–5,000", options: { bullet: true, breakLine: true } },
  { text: "Only 202 of 3,095 sellers ever shipped an item over R$ 1,000", options: { bullet: true } },
], { x: 0.55, y: 3.37, w: 4.3, h: 1.3, fontSize: 13, color: INK, paraSpaceAfter: 6, isTextBox: true, margin: 0 });

s.addChart(pres.ChartType.bar, [{
  name: "Share of items", labels: ["< R$50", "R$50–199", "R$200–999", "≥ R$1,000"],
  values: [34.6, 53.4, 11.2, 0.8],
}], { ...chartBase, x: 5.15, y: 1.3, w: 4.3, h: 3.1, barDir: "bar",
  chartColors: [SAGE, SAGE, SAGE, ORANGE], showValue: true, dataLabelPosition: "outEnd",
  dataLabelFormatCode: '0.0"%"', dataLabelColor: INK, valAxisHidden: true, valGridLine: { style: "none" } });
s.addText("Share of all items sold, by price. Our product sits in the orange sliver.",
  { x: 5.15, y: 4.45, w: 4.3, h: 0.5, fontSize: 10.5, color: MUTED, italic: true, isTextBox: true, margin: 0 });
s.addNotes("Our accessories fit perfectly — that band is exactly where this platform lives. Our flagship hardware has no precedent here: past the 99th percentile of everything Magist has ever sold.");

/* ================= 4 — concern 2 ================= */
pres.addSection({ title: "Delivery" });
s = pres.addSlide({ masterName: "LIGHT", sectionTitle: "Delivery" });
s.addText("Deliveries are adequate, not fast", { placeholder: "title" });
s.addShape(pres.ShapeType.roundRect, { x: 0.55, y: 1.25, w: 3.5, h: 1.5, rectRadius: 0.08,
  fill: { color: MIST }, line: { color: "DCE8E3", width: 0.75 }, objectName: "card-headline" });
s.addText("12.1 days", { x: 0.7, y: 1.4, w: 3.2, h: 0.6, fontSize: 34, bold: true, color: TEAL,
  isTextBox: true, margin: 0 });
s.addText("average delivery — against a promised window of 23.4 days",
  { x: 0.7, y: 2.0, w: 3.2, h: 0.65, fontSize: 12, color: MUTED, isTextBox: true, margin: 0 });
s.addText([
  { text: "They hit the promise 92 % of the time — by promising three weeks.", options: { breakLine: true } },
  { text: "São Paulo, 42 % of all orders: 8.3 days. The northern states: 20–24.", options: {} },
], { x: 0.55, y: 2.95, w: 3.5, h: 1.3, fontSize: 12.5, color: INK, paraSpaceAfter: 8, isTextBox: true, margin: 0 });

s.addChart(pres.ChartType.bar, [{
  name: "Avg days", labels: ["17 Q1","17 Q2","17 Q3","17 Q4","18 Q1","18 Q2","18 Q3"],
  values: [12.4, 11.9, 11.1, 13.9, 15.3, 10.3, 7.9],
}], { ...chartBase, x: 4.35, y: 1.25, w: 5.1, h: 3.0,
  chartColors: [SAGE, SAGE, SAGE, SAGE, ORANGE, SAGE, TEAL],
  showValue: true, dataLabelPosition: "outEnd", dataLabelColor: INK, varyColors: true });
s.addText("Average days to delivery by quarter. The 2018-Q1 peak is peak-season strain; it halved within two quarters.",
  { x: 4.35, y: 4.3, w: 5.1, h: 0.55, fontSize: 10.5, color: MUTED, italic: true, isTextBox: true, margin: 0 });
s.addNotes("Read the two numbers together: reliability bought with a conservative quote, not with speed. The trend is the better news — 15.3 days in Q1 down to 7.9 by Q3.");

/* ================= 5 — the real risk ================= */
pres.addSection({ title: "Risk" });
s = pres.addSlide({ masterName: "LIGHT", sectionTitle: "Risk" });
s.addText("One missed date undoes our promise", { placeholder: "title" });
s.addChart(pres.ChartType.bar, [{
  name: "Average review score", labels: ["Delivered on time", "Delivered late"], values: [4.29, 2.55],
}], { ...chartBase, x: 0.55, y: 1.35, w: 5.0, h: 2.6, barDir: "bar",
  chartColors: [TEAL, ORANGE], showValue: true, dataLabelPosition: "outEnd",
  dataLabelFormatCode: "0.00", dataLabelColor: INK, valAxisHidden: true, valGridLine: { style: "none" },
  varyColors: true, barGapWidthPct: 60 });
s.addText("Average review score, 95,489 delivered orders",
  { x: 0.55, y: 4.0, w: 5.0, h: 0.3, fontSize: 10.5, color: MUTED, italic: true, isTextBox: true, margin: 0 });
statCard(s, { x: 5.85, y: 1.45, w: 3.6, h: 1.15, value: "54.6 %", label: "of late orders get a 1–2 star review", tone: "warn" });
s.addText([
  { text: "On time, only 9.4 % do.", options: { breakLine: true } },
  { text: "Eniac's differentiator is the human relationship with the customer. This is where a logistics decision becomes a brand decision.", options: {} },
], { x: 5.85, y: 2.8, w: 3.6, h: 1.5, fontSize: 13, color: INK, paraSpaceAfter: 8, isTextBox: true, margin: 0 });
s.addNotes("Pause here. One missed delivery date makes a one-or-two-star review five times more likely.");

/* ================= 6 — recommendation ================= */
pres.addSection({ title: "Recommendation" });
s = pres.addSlide({ masterName: "DARK", sectionTitle: "Recommendation" });
s.addText("Sign — but not this deal", { x: 0.55, y: 0.45, w: 8.9, h: 0.7, fontSize: 32, bold: true,
  color: WHITE, isTextBox: true, margin: 0 });
[["1", "Accessories first", "They sit in the R$75–230 band Magist already owns. Flagship hardware has no precedent on the platform."],
 ["2", "12–18 months, not three years", "The three-year price was set against 2018-Q1 — the worst quarter in the data. Add a delivery SLA."],
 ["3", "São Paulo and the Southeast first", "8.3 days there against 23.8 in the North. Do not sell one promise into both."]]
 .forEach(([n, h, b], i) => {
   const x = 0.55 + i * 3.02;
   s.addShape(pres.ShapeType.roundRect, { x, y: 1.45, w: 2.77, h: 2.75, rectRadius: 0.08,
     fill: { color: "0E6159" }, line: { color: "16716A", width: 0.75 }, objectName: `rec-${n}` });
   s.addShape(pres.ShapeType.ellipse, { x: x + 0.22, y: 1.68, w: 0.42, h: 0.42,
     fill: { color: SAGE }, line: { color: SAGE }, objectName: `recnum-${n}` });
   s.addText(n, { x: x + 0.22, y: 1.68, w: 0.42, h: 0.42, fontSize: 14, bold: true, color: TEAL,
     align: "center", valign: "middle", isTextBox: true, margin: 0 });
   s.addText(h, { x: x + 0.22, y: 2.22, w: 2.35, h: 0.62, fontSize: 15, bold: true, color: WHITE,
     isTextBox: true, margin: 0 });
   s.addText(b, { x: x + 0.22, y: 2.88, w: 2.35, h: 1.15, fontSize: 11.5, color: MIST,
     isTextBox: true, margin: 0 });
 });
s.addNotes("Sign, but reshaped. The data supports Magist as a market-entry vehicle and contradicts it as a three-year, full-catalogue commitment.");

/* ================= 7 — the open question ================= */
s = pres.addSlide({ masterName: "DARK", sectionTitle: "Recommendation" });
s.addText("What we still have to ask Magist", { x: 0.55, y: 1.25, w: 8.9, h: 0.7, fontSize: 30,
  bold: true, color: WHITE, isTextBox: true, margin: 0 });
s.addText("This data shows what Magist's sellers do — not what Magist can do for us.",
  { x: 0.55, y: 2.02, w: 8.4, h: 0.72, fontSize: 17, color: SAGE, italic: true, isTextBox: true, margin: 0 });
s.addText([
  { text: "Delivery performance on parcels above R$ 1,000", options: { bullet: true, breakLine: true } },
  { text: "Insurance and returns terms for high-value electronics", options: { bullet: true, breakLine: true } },
  { text: "Whether sellers above that price band exist and simply don't sell volume", options: { bullet: true } },
], { x: 0.55, y: 2.72, w: 8.4, h: 1.3, fontSize: 14, color: MIST, paraSpaceAfter: 7, isTextBox: true, margin: 0 });
s.addText("It is the one question the data cannot answer — and it is the one the deal turns on.",
  { x: 0.55, y: 4.15, w: 8.4, h: 0.4, fontSize: 13, color: WHITE, bold: true, isTextBox: true, margin: 0 });
s.addNotes("Ending on the open question is deliberate: it shows the analysis knows its own boundaries and hands the head of Eniac a concrete next step.");

(async () => {
  await pres.writeFile({ fileName: "magist-decision.pptx" });
  const { applyTheme } = require("/Users/leonardobornhausser/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/8052765b-aab8-4663-8370-b0752c1a5c11/3b6ab2e6-e965-4617-bd19-354ff93e5f71/skills/pptx/scripts/apply_theme.js");
  await applyTheme("magist-decision.pptx", THEME);
  console.log("built magist-decision.pptx");
})();
