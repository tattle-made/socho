/**
 * Vendoring script for jsPsych plugins.
 *
 * Run after `npm install --prefix assets`:
 *   node assets/setup_jspsych.mjs
 *
 * What it does:
 *   1. Copies each plugin's browser build to priv/static/vendor/jspsych/
 *   2. Extracts each plugin's `info.parameters` schema and writes
 *      priv/jspsych_registry.json — used by the Elixir backend to know
 *      what fields are configurable per plugin.
 */

import { copyFileSync, mkdirSync, writeFileSync, existsSync, readFileSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// --- Minimal browser stubs so jsPsych modules load in Node.js without crashing.
// We only need the class definitions and static `info` objects; no DOM access occurs
// at import time in jsPsych 8 plugin modules.
globalThis.window = globalThis;
globalThis.document = {
  addEventListener: () => {},
  removeEventListener: () => {},
  createElement: () => ({ style: {}, setAttribute: () => {}, addEventListener: () => {} }),
  querySelector: () => null,
  querySelectorAll: () => [],
  body: { appendChild: () => {}, removeChild: () => {}, style: {} },
};
Object.defineProperty(globalThis, 'navigator', { value: { userAgent: '' }, writable: true });
globalThis.performance = { now: () => 0 };

// --- Paths ---

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const NODE_MODULES = resolve(__dirname, 'node_modules');
const VENDOR_DIR = resolve(ROOT, 'priv/static/vendor/jspsych');
const REGISTRY_PATH = resolve(ROOT, 'priv/jspsych_registry.json');

mkdirSync(VENDOR_DIR, { recursive: true });

function nmPath(...parts) {
  return resolve(NODE_MODULES, ...parts);
}

function toFileUrl(p) {
  return pathToFileURL(p).href;
}

// --- jsPsych core ---

copyFileSync(nmPath('jspsych/dist/index.browser.min.js'), join(VENDOR_DIR, 'jspsych.js'));
copyFileSync(nmPath('jspsych/css/jspsych.css'), join(VENDOR_DIR, 'jspsych.css'));
console.log('✓ jspsych core + css');

// --- ParameterType mapping ---
// Numeric enum values from jsPsych 8.x (ParameterType in packages/jspsych/src/modules/plugins.ts).
// Used to convert numeric type values in plugin info to readable strings.
const PARAMETER_TYPE_NAMES = {
  0: 'BOOL',
  1: 'STRING',
  2: 'INT',
  3: 'FLOAT',
  4: 'FUNCTION',
  5: 'KEY',
  6: 'KEYS',
  7: 'SELECT',
  8: 'HTML_STRING',
  9: 'IMAGE',
  10: 'AUDIO',
  11: 'VIDEO',
  12: 'OBJECT',
  13: 'COMPLEX',
  14: 'TIMELINE',
};

// Try loading the live ParameterType enum in case values changed in this version
let paramTypeNames = { ...PARAMETER_TYPE_NAMES };
try {
  const jspsychMod = await import(toFileUrl(nmPath('jspsych/dist/index.js')));
  const PT = jspsychMod.ParameterType;
  if (PT) {
    const inverted = {};
    for (const [k, v] of Object.entries(PT)) {
      if (typeof v === 'number') inverted[v] = k;
    }
    if (Object.keys(inverted).length > 0) paramTypeNames = inverted;
  }
} catch {
  // Fall back to hardcoded map — fine for all jsPsych 8.x releases
}

// --- Helpers ---

function serializeParameters(params) {
  if (!params || typeof params !== 'object') return {};
  const result = {};
  for (const [key, value] of Object.entries(params)) {
    result[key] = {
      type: paramTypeNames[value.type] ?? String(value.type),
      default: value.default !== undefined ? value.default : null,
      description: value.description ?? null,
      array: value.array ?? false,
    };
    // COMPLEX parameters can have nested parameter definitions
    if (value.nested) {
      result[key].nested = serializeParameters(value.nested);
    }
  }
  return result;
}

// --- Plugin list ---

const PLUGINS = [
  'animation',
  'audio-button-response',
  'audio-keyboard-response',
  'canvas-button-response',
  'canvas-keyboard-response',
  'categorize-html',
  'categorize-image',
  'free-sort',
  'fullscreen',
  'html-button-response',
  'html-keyboard-response',
  'iat-html',
  'image-button-response',
  'image-keyboard-response',
  'instructions',
  'preload',
  'reconstruction',
  'resize',
  'same-different-html',
  'same-different-image',
  'serial-reaction-time',
  'serial-reaction-time-mouse',
  'sketchpad',
  'survey',
  'survey-html-form',
  'survey-likert',
  'survey-multi-choice',
  'survey-multi-select',
  'survey-slider',
  'survey-text',
  'video-button-response',
  'video-keyboard-response',
  'virtual-chinrest',
];

// --- Process plugins ---

const registry = {};
const warnings = [];

for (const pluginName of PLUGINS) {
  const pkgName = `@jspsych/plugin-${pluginName}`;
  const pkgDir = nmPath(pkgName);

  if (!existsSync(pkgDir)) {
    warnings.push(`${pkgName} not found in node_modules — skipping`);
    continue;
  }

  // Copy browser build
  const browserBuild = join(pkgDir, 'dist/index.browser.min.js');
  if (!existsSync(browserBuild)) {
    warnings.push(`${pkgName}: dist/index.browser.min.js not found — skipping`);
    continue;
  }
  copyFileSync(browserBuild, join(VENDOR_DIR, `${pluginName}.js`));

  // Extract info schema
  try {
    const pkgJson = JSON.parse(readFileSync(join(pkgDir, 'package.json'), 'utf8'));
    const mod = await import(toFileUrl(join(pkgDir, 'dist/index.js')));
    // Plugins export their class as default; fall back to scanning all exports
    const Plugin = mod.default ?? Object.values(mod).find(v => v?.info?.parameters);
    if (Plugin?.info) {
      registry[pluginName] = {
        name: Plugin.info.name,
        version: Plugin.info.version ?? null,
        description: pkgJson.description ?? null,
        parameters: serializeParameters(Plugin.info.parameters ?? {}),
      };
      console.log(`✓ ${pluginName}`);
    } else {
      warnings.push(`${pkgName}: info object not found on exported class`);
    }
  } catch (err) {
    warnings.push(`${pkgName}: import failed — ${err.message}`);
  }
}

// --- Write registry ---

writeFileSync(REGISTRY_PATH, JSON.stringify(registry, null, 2));

const pluginCount = Object.keys(registry).length;
console.log(`\nRegistry → priv/jspsych_registry.json (${pluginCount}/${PLUGINS.length} plugins)`);

if (warnings.length > 0) {
  console.warn('\nWarnings:');
  warnings.forEach(w => console.warn(`  ⚠  ${w}`));
}
