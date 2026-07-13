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

import { copyFileSync, mkdirSync, writeFileSync, existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { build as esbuild } from 'esbuild';

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

// --- Extensions ---

const EXTENSIONS = [
  { name: 'extension-touchscreen-buttons', pkg: '@jspsych-contrib/extension-touchscreen-buttons' },
];

for (const { name, pkg } of EXTENSIONS) {
  const pkgDir = nmPath(pkg);
  if (!existsSync(pkgDir)) {
    console.warn(`⚠  ${pkg} not found in node_modules — skipping`);
    continue;
  }
  const browserBuild = join(pkgDir, 'dist/index.browser.min.js');
  if (!existsSync(browserBuild)) {
    console.warn(`⚠  ${pkg}: dist/index.browser.min.js not found — skipping`);
    continue;
  }
  const outPath = join(VENDOR_DIR, `${name}.js`);
  let src = readFileSync(browserBuild, 'utf8');

  // Patch: also fire mousedown/mouseup so buttons work with mouse clicks (not just touch).
  src = src.replace(
    'addEventListener("touchend",a.end_listener.bind(a),!1),b.appendChild(a.div)',
    'addEventListener("touchend",a.end_listener.bind(a),!1),' +
    'a.div.addEventListener("mousedown",a.start_listener.bind(a),!1),' +
    'a.div.addEventListener("mouseup",a.end_listener.bind(a),!1),' +
    'b.appendChild(a.div)'
  );

  writeFileSync(outPath, src);
  console.log(`✓ ${name}`);
}

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
  'iat-image',
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
  let pluginSrc = readFileSync(browserBuild, 'utf8');

  // Patch iat-image: center the stimulus div and set its dimensions.
  if (pluginName === 'iat-image') {
    pluginSrc = pluginSrc.replace(
      "height: 20%; width: 100%; margin-left: auto; margin-right: auto; top: 42%; left: 0; right: 0'><img",
      "height: 4em; width: 16em; margin-left: auto; margin-right: auto; top: 36%; left: 0; right: 0; text-align: center'><img"
    );
  }

  writeFileSync(join(VENDOR_DIR, `${pluginName}.js`), pluginSrc);

  // Copy plugin CSS if present
  const pluginCss = join(pkgDir, `css/${pluginName}.css`);
  if (existsSync(pluginCss)) {
    copyFileSync(pluginCss, join(VENDOR_DIR, `${pluginName}.css`));
  }

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

// ── Custom plugins ────────────────────────────────────────────────────────────

const CUSTOM_PLUGINS_DIR = resolve(__dirname, 'custom_plugins');
const CUSTOM_VENDOR_DIR = resolve(ROOT, 'priv/static/vendor/custom');
const CUSTOM_REGISTRY_PATH = resolve(ROOT, 'priv/custom_plugins_registry.json');

mkdirSync(CUSTOM_VENDOR_DIR, { recursive: true });

function toPascalCase(kebab) {
  return kebab.split('-').map(s => s.charAt(0).toUpperCase() + s.slice(1)).join('');
}

const customRegistry = {};
const customWarnings = [];

const customDirs = existsSync(CUSTOM_PLUGINS_DIR)
  ? readdirSync(CUSTOM_PLUGINS_DIR).filter(name => {
      const full = join(CUSTOM_PLUGINS_DIR, name);
      return !name.startsWith('.') && statSync(full).isDirectory();
    })
  : [];

console.log(`\n── Custom plugins (${customDirs.length} found) ──`);

for (const dirName of customDirs) {
  const pluginPath = join(CUSTOM_PLUGINS_DIR, dirName, 'index.js');

  if (!existsSync(pluginPath)) {
    customWarnings.push(`custom/${dirName}: index.js not found — skipping`);
    continue;
  }

  const jsGlobalName = `jsPsych${toPascalCase(dirName)}`;
  const tempGlobal = '__jsPsychCustomPlugin__';
  const outfile = join(CUSTOM_VENDOR_DIR, `${dirName}.js`);

  try {
    // Bundle to browser-ready IIFE and expose as the correct global variable.
    // We use a temp global name so the IIFE result object is captured, then
    // a footer extracts .default (ESM default export) as the real global.
    await esbuild({
      entryPoints: [pluginPath],
      bundle: true,
      format: 'iife',
      globalName: tempGlobal,
      footer: { js: `var ${jsGlobalName} = ${tempGlobal}.default ?? ${tempGlobal};` },
      outfile,
      logLevel: 'silent',
    });

    // Import the ESM module in Node to extract the static info object.
    const mod = await import(toFileUrl(pluginPath));
    const Plugin = mod.default ?? Object.values(mod).find(v => v?.info?.parameters);

    if (Plugin?.info) {
      customRegistry[dirName] = {
        name: Plugin.info.name ?? dirName,
        version: Plugin.info.version ?? null,
        description: Plugin.info.description ?? null,
        parameters: serializeParameters(Plugin.info.parameters ?? {}),
        custom: true,
      };
      console.log(`✓ custom/${dirName}  →  ${jsGlobalName}`);
    } else {
      customWarnings.push(`custom/${dirName}: no static info found on default export`);
    }
  } catch (err) {
    customWarnings.push(`custom/${dirName}: ${err.message}`);
  }
}

writeFileSync(CUSTOM_REGISTRY_PATH, JSON.stringify(customRegistry, null, 2));
console.log(`\nCustom registry → priv/custom_plugins_registry.json (${Object.keys(customRegistry).length} plugins)`);

if (customWarnings.length > 0) {
  console.warn('\nCustom plugin warnings:');
  customWarnings.forEach(w => console.warn(`  ⚠  ${w}`));
}
