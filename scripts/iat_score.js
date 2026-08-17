// Minimal browser globals required to load the jspsych CJS bundle
global.window = {
  location: { search: "", href: "", protocol: "https:" },
  addEventListener: () => {},
  AudioContext: undefined,
  webkitAudioContext: undefined,
};
global.document = {
  createElement: () => ({ style: {} }),
  querySelector: () => null,
  body: { appendChild: () => {} },
};

const { DataCollection } = require("../assets/node_modules/jspsych/dist/index.cjs");
const fs = require("fs");

const path = process.argv[2];
if (!path) {
  console.error("Usage: node scripts/iat_score.js <path/to/iat_data.json>");
  process.exit(1);
}
if (!fs.existsSync(path)) {
  console.error("File not found:", path);
  process.exit(1);
}

const trials = JSON.parse(fs.readFileSync(path, "utf8"));
const data = new DataCollection(trials);

console.log("=== IAT D-score (jsPsych DataCollection) ===");
console.log("File:", path);
console.log("Total trials:", data.count());
console.log("");

// Print embedded iat_summary if present
const summary = data.filterCustom((x) => x.iat_type === "iat_summary").values();
if (summary.length > 0) {
  const s = summary[0];
  console.log("=== Embedded iat_summary (computed by jsPsych in browser) ===");
  console.log("  d_score :", s.d_score?.toFixed(4));
  console.log("  mean_c1 :", s.mean_c1?.toFixed(2), "ms");
  console.log("  mean_c2 :", s.mean_c2?.toFixed(2), "ms");
  console.log("");
}

// Mirror the exact filter from iat.ex stimulus_function
const c1_practice = data.filterCustom((x) => x.iat_type === "combined1_practice" && x.rt >= 400 && x.rt < 10000);
const c1_test     = data.filterCustom((x) => x.iat_type === "combined1_test"     && x.rt >= 400 && x.rt < 10000);
const c2_practice = data.filterCustom((x) => x.iat_type === "combined2_practice" && x.rt >= 400 && x.rt < 10000);
const c2_test     = data.filterCustom((x) => x.iat_type === "combined2_test"     && x.rt >= 400 && x.rt < 10000);

console.log("=== Trials after RT filter (400–10000 ms) ===");
console.log("  combined1_practice :", c1_practice.count());
console.log("  combined1_test     :", c1_test.count());
console.log("  combined2_practice :", c2_practice.count());
console.log("  combined2_test     :", c2_test.count());
console.log("");

if ([c1_practice, c1_test, c2_practice, c2_test].some((b) => b.count() === 0)) {
  console.error("ERROR: one or more blocks are empty — cannot compute D-score.");
  process.exit(1);
}

// Exact same arithmetic as iat.ex stimulus_function.
// Fresh filterCustom for pooled sets — DataCollection.join() mutates its receiver in place.
const c1_pool       = data.filterCustom((x) => (x.iat_type === "combined1_practice" || x.iat_type === "combined1_test")     && x.rt >= 400 && x.rt < 10000);
const c2_pool       = data.filterCustom((x) => (x.iat_type === "combined2_practice" || x.iat_type === "combined2_test")     && x.rt >= 400 && x.rt < 10000);
const practice_pool = data.filterCustom((x) => (x.iat_type === "combined1_practice" || x.iat_type === "combined2_practice") && x.rt >= 400 && x.rt < 10000);
const test_pool     = data.filterCustom((x) => (x.iat_type === "combined1_test"     || x.iat_type === "combined2_test")     && x.rt >= 400 && x.rt < 10000);
const mean_c1 = c1_pool.select("rt").mean();
const mean_c2 = c2_pool.select("rt").mean();
const sd1 = practice_pool.select("rt").sd();
const sd2 = test_pool.select("rt").sd();
const d1 = (c2_practice.select("rt").mean() - c1_practice.select("rt").mean()) / sd1;
const d2 = (c2_test.select("rt").mean()     - c1_test.select("rt").mean())     / sd2;
const d  = (d1 + d2) / 2;

console.log("=== Block means (ms) ===");
console.log("  combined1_practice mean :", c1_practice.select("rt").mean().toFixed(2));
console.log("  combined1_test mean     :", c1_test.select("rt").mean().toFixed(2));
console.log("  combined2_practice mean :", c2_practice.select("rt").mean().toFixed(2));
console.log("  combined2_test mean     :", c2_test.select("rt").mean().toFixed(2));
console.log("");
console.log("  mean_c1 (c1 practice+test) :", mean_c1.toFixed(2), "ms");
console.log("  mean_c2 (c2 practice+test) :", mean_c2.toFixed(2), "ms");
console.log("");
console.log("=== Pooled SDs ===");
console.log("  sd1 (practice pool) :", sd1.toFixed(2));
console.log("  sd2 (test pool)     :", sd2.toFixed(2));
console.log("");
console.log("=== D-score components ===");
console.log("  d1 (practice) :", d1.toFixed(4));
console.log("  d2 (test)     :", d2.toFixed(4));
console.log("");
console.log("=== D-score :", d.toFixed(2), "===");
console.log("");
console.log("Interpretation: >0.15 slight, >0.35 moderate, >0.65 strong");
console.log("Positive = cat1+att1 paired faster; negative = cat2+att1 paired faster");
