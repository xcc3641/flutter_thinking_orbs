// Differential sweep generator: builds the case list (spec.json) and streams
// the ORIGINAL TypeScript engine's frames, as raw little-endian Float64, into
// a FIFO that the Swift comparer reads. Nothing large touches the disk.
//
// usage: node gen.ts <spec.json out> <fifo path> [--spec-only]

import { closeSync, openSync, writeFileSync, writeSync } from 'node:fs';
import { PRESETS, resolvePreset, STATE_TO_MODE } from './ts/presets.ts';
import { MODE_FRAMES } from './ts/engine/registry.ts';
import { BASE_PROFILES, scaleCounts, scaleRadii } from './ts/engine/profiles.ts';

const [specPath, fifoPath, flag] = process.argv.slice(2);

const STATES = [
  'working',
  'searching',
  'solving',
  'listening',
  'connecting',
  'weaving',
  'composing',
  'breathing',
  'shaping'
] as const;
const SIZES = [64, 20] as const;

// --- float helpers ---------------------------------------------------------
const f64 = new Float64Array(1);
const i64 = new BigInt64Array(f64.buffer);
function nextUp(x: number): number {
  if (x === 0) return Number.MIN_VALUE;
  f64[0] = x;
  i64[0] += x > 0 ? 1n : -1n;
  return f64[0];
}
function nextDown(x: number): number {
  if (x === 0) return -Number.MIN_VALUE;
  f64[0] = x;
  i64[0] += x > 0 ? -1n : 1n;
  return f64[0];
}

// mulberry32 — seeded so both runs are reproducible
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// --- timestamps --------------------------------------------------------------
function timestamps(speed: number, dense: boolean): number[] {
  const s = new Set<number>();
  const addN = (x: number) => {
    if (!(x >= 0)) return; // negatives are probed separately (Swift may trap)
    s.add(x);
    s.add(nextUp(x));
    const d = nextDown(x);
    if (d >= 0) s.add(d);
  };
  s.add(0);
  // regular grid 0..120 step 0.3 (401 values)
  for (let i = 0; i <= 400; i++) s.add(i * 0.3);
  // seeded random in [0,120]
  const r = rng(1234567 + Math.round(speed * 1000));
  for (let i = 0; i < 300; i++) s.add(r() * 120);
  if (dense) {
    // morph: HOLD 1.4 + MORPH 0.9 = SEG 2.3; cycle SEG*3
    const SEG = 1.4 + 0.9;
    for (let k = 0; k * SEG <= 121; k++) {
      addN(k * SEG);
      addN(k * SEG + 1.4);
      addN(k * 2.3);
    }
    for (let k = 0; k * (SEG * 3) <= 121; k++) addN(k * (SEG * 3));
    // rubik: slot 0.42, 2*14*0.42 = 11.76 of moves, cycle 12.96
    for (let k = 0; k * 0.42 <= 121; k++) addN(k * 0.42);
    const cyc = 2 * 14 * 0.42 + 1.2;
    for (let k = 0; k * cyc <= 121; k++) {
      addN(k * cyc);
      addN(k * cyc + 2 * 14 * 0.42);
      addN(k * cyc + 14 * 0.42);
      for (let j = 0; j <= 28; j++) addN(k * cyc + j * 0.42);
    }
    // other moveCounts used by the custom cases (1, 30)
    for (const mc of [1, 30]) {
      const c = 2 * mc * 0.42 + 1.2;
      for (let k = 0; k * c <= 121; k++) {
        addN(k * c);
        addN(k * c + 2 * mc * 0.42);
      }
    }
    // web: seg edges t*0.55 + s*7.31 crossing integers, s up to 12 signals
    for (let sg = 0; sg < 12; sg++) {
      for (let n = Math.ceil(sg * 7.31); (n - sg * 7.31) / 0.55 <= 120; n++) addN((n - sg * 7.31) / 0.55);
    }
    // braid: frac(i/strandN + t*0.045) wraps: t*0.045 crossing integers
    for (let n = 0; n / 0.045 <= 121; n++) addN(n / 0.045);
    // vnoise lattice crossings: t*0.24 / 0.21 / 0.27 integer
    for (const m of [0.24, 0.21, 0.27]) for (let n = 0; n / m <= 121; n++) addN(n / m);
  }
  // large t — process-relative clock after days, plus robustness
  const large = [
    1e3,
    1e4,
    1e5,
    86400,
    86400 * 3,
    86400 * speed,
    86400 * 3 * speed,
    86400 * 30 * speed,
    1e6,
    1e7,
    1e8,
    1e9,
    2 ** 31,
    2 ** 32 + 0.5
  ];
  for (const x of large) {
    s.add(x);
    s.add(nextUp(x));
    s.add(x + 0.123456);
  }
  return [...s].sort((a, b) => a - b);
}

// --- cases -----------------------------------------------------------------
interface Case {
  name: string;
  state?: string;
  mode: string;
  size: number;
  opts: Record<string, number>;
  ts: number[];
}
const cases: Case[] = [];

for (const state of STATES) {
  for (const size of SIZES) {
    const r = resolvePreset(state, size);
    cases.push({
      name: `${state}-${size}`,
      state,
      mode: r.mode,
      size,
      opts: r.opts as Record<string, number>,
      ts: timestamps(r.speed, true)
    });
  }
}

const MODES = ['orbits', 'globe', 'rubik', 'wave', 'web', 'braid', 'ribbon', 'ring', 'morph'];
const custom: Array<[string, string, number, Record<string, number>]> = [];
// base (fine) profiles, unscaled, at both sizes and two off-sizes
for (const m of MODES) {
  for (const size of [64, 20, 300, 37.5]) custom.push([`base-${m}-${size}`, m, size, { ...BASE_PROFILES[m] } as Record<string, number>]);
  // every option missing: pure defaults
  custom.push([`empty-${m}-64`, m, 64, {}]);
}
const B = (m: string) => ({ ...BASE_PROFILES[m] }) as Record<string, number>;
custom.push(
  ['rubik-move1', 'rubik', 64, { ...B('rubik'), moveCount: 1 }],
  ['rubik-move30', 'rubik', 64, { ...B('rubik'), moveCount: 30 }],
  ['rubik-move0', 'rubik', 64, { ...B('rubik'), moveCount: 0 }],
  ['rubik-rings2', 'rubik', 20, { ...B('rubik'), latRings: 2, lonDensity: 3 }],
  ['ribbon-nospin', 'ribbon', 64, { ...B('ribbon') }],
  ['ribbon-spin0.37', 'ribbon', 64, { ...B('ribbon'), spin: 0.37 }],
  ['ribbon-lanes4', 'ribbon', 64, { ...B('ribbon'), bandMul: 0.8 }],
  ['ribbon-lanes1', 'ribbon', 64, { ...B('ribbon'), lanes: 1 }],
  ['ribbon-lanes2', 'ribbon', 64, { ...B('ribbon'), lanes: 2 }],
  ['ribbon-lanes-half', 'ribbon', 64, { ...B('ribbon'), bandMul: 0.5 }],
  ['ribbon-lanes-3.5', 'ribbon', 64, { ...B('ribbon'), bandMul: 0.7 }],
  ['ribbon-lanes-4.5', 'ribbon', 64, { ...B('ribbon'), bandMul: 0.9 }],
  ['ribbon-wob0', 'ribbon', 64, { ...B('ribbon'), wobMul: 0 }],
  ['ribbon-wob2.5', 'ribbon', 64, { ...B('ribbon'), wobMul: 2.5, spin: 0 }],
  ['ring-faceOn0', 'ring', 64, { ...B('ring'), faceOn: 0 }],
  ['ring-faceOn0.5', 'ring', 64, { ...B('ring'), faceOn: 0.5 }],
  ['ring-faceOn-1', 'ring', 64, { ...B('ring'), faceOn: -1 }],
  ['ring-spin1-lanes6', 'ring', 64, { ...B('ring'), spin: 1, lanes: 6 }],
  ['ring-ghost', 'ring', 20, { ...B('ring'), ghostN: 60 }],
  ['globe-scan0-dim0', 'globe', 64, { ...B('globe'), scanMul: 0, dimBase: 0 }],
  ['globe-dim0.02', 'globe', 64, { ...B('globe'), dimBase: 0.02 }],
  ['globe-boost3', 'globe', 20, { ...B('globe'), rBoost: 3, scanMul: 2.2 }],
  ['globe-lat1', 'globe', 64, { ...B('globe'), latRings: 1, lonDensity: 5 }],
  ['web-thrAll', 'web', 64, { ...B('web'), thr: 2.1 }],
  ['web-thr0', 'web', 64, { ...B('web'), thr: 0 }],
  ['web-spread', 'web', 64, { ...B('web'), spread: 1.3 }],
  ['web-sig0', 'web', 64, { ...B('web'), signals: 0 }],
  ['web-sig12', 'web', 20, { ...B('web'), signals: 12 }],
  ['web-node2', 'web', 64, { ...B('web'), nodeN: 2 }],
  ['web-node3', 'web', 64, { ...B('web'), nodeN: 3 }],
  ['web-node1', 'web', 64, { ...B('web'), nodeN: 1 }],
  ['web-node0', 'web', 64, { ...B('web'), nodeN: 0 }],
  ['morph-iconD-min', 'morph', 64, { ...B('morph'), iconD: 0.02 }],
  ['morph-iconD3', 'morph', 64, { ...B('morph'), iconD: 3 }],
  ['morph-noRMin', 'morph', 20, { rDot: 0.001, iconD: 1 }],
  ['morph-spread1', 'morph', 64, { ...B('morph'), spread: 1 }],
  ['braid-turns0', 'braid', 64, { ...B('braid'), turns: 0 }],
  ['braid-turns5.5', 'braid', 64, { ...B('braid'), turns: 5.5 }],
  ['braid-strand1', 'braid', 64, { ...B('braid'), strandN: 1, ghostN: 1 }],
  ['orbits-part0', 'orbits', 64, { ...B('orbits'), particles: 0 }],
  ['orbits-part7', 'orbits', 64, { ...B('orbits'), particles: 7 }],
  ['orbits-ghostA-edge', 'orbits', 64, { ...B('orbits'), ghostA: 0.04 }],
  ['orbits-orbit1', 'orbits', 20, { ...B('orbits'), orbitN: 1, ghostN: 1 }],
  ['wave-rings1', 'wave', 64, { ...B('wave'), rings: 1 }],
  ['wave-rings2', 'wave', 64, { ...B('wave'), rings: 2, lonDensity: 2.5 }]
);
// scaled through the preset machinery with non-shipped multipliers
const r2 = rng(99);
for (const m of MODES) {
  for (let q = 0; q < 3; q++) {
    const c = 0.02 + r2() * 2;
    const z = 0.3 + r2() * 2.5;
    custom.push([`scaled-${m}-${q}`, m, q === 2 ? 20 : 64, scaleRadii(scaleCounts(B(m), c), z) as Record<string, number>]);
  }
}
// fractional counts — not reachable through the presets (scaleCounts rounds),
// but typeable by a caller of the engine
const FRACT: Array<[string, string, Record<string, number>]> = [
  ['frac-orbits-ghostN', 'orbits', { ...B('orbits'), ghostN: 40.5 }],
  ['frac-orbits-particles', 'orbits', { ...B('orbits'), particles: 2.5 }],
  ['frac-web-nodeN', 'web', { ...B('web'), nodeN: 22.5 }],
  ['frac-web-signals', 'web', { ...B('web'), signals: 2.5 }],
  ['frac-ribbon-segs', 'ribbon', { ...B('ribbon'), segs: 60.5 }],
  ['frac-globe-latRings', 'globe', { ...B('globe'), latRings: 7.5 }],
  ['frac-braid-strandN', 'braid', { ...B('braid'), strandN: 20.5 }],
  ['frac-wave-rings', 'wave', { ...B('wave'), rings: 6.5 }]
];
for (const [n, m, o] of FRACT) custom.push([n, m, 64, o]);

for (const [name, mode, size, opts] of custom) {
  cases.push({ name, mode, size, opts, ts: timestamps(1, !name.startsWith('frac-')) });
}

// --- scale machinery tests ---------------------------------------------------
const scaleTests: Array<{ mode: string; scale: number; counts: Record<string, number>; radii: Record<string, number> }> = [];
const r3 = rng(4242);
const scaleList = [
  0.028, 0.051, 0.088, 0.105, 0.1125, 0.238, 0.25, 0.341, 0.35, 0.42, 0.5, 0.53, 0.702, 1, 1.35, 1 / 3, 2 / 3, 0.001, 4, 9
];
for (let i = 0; i < 300; i++) scaleList.push(0.005 + r3() * 3);
for (const m of MODES) {
  for (const sc of scaleList) {
    scaleTests.push({
      mode: m,
      scale: sc,
      counts: scaleCounts(B(m), sc) as Record<string, number>,
      radii: scaleRadii(B(m), sc) as Record<string, number>
    });
  }
}

const resolved: Record<string, { mode: string; speed: number; opts: Record<string, number> }> = {};
for (const state of STATES) for (const size of SIZES) resolved[`${state}-${size}`] = resolvePreset(state, size) as never;

writeFileSync(
  specPath,
  JSON.stringify({ cases, scaleTests, resolved, stateToMode: STATE_TO_MODE, presets: PRESETS, base: BASE_PROFILES })
);
let totalFrames = 0;
for (const c of cases) totalFrames += c.ts.length;
console.error(`spec: ${cases.length} cases, ${totalFrames} frames, ${scaleTests.length} scale tests`);
if (flag === '--spec-only') process.exit(0);

// --- stream JS frames --------------------------------------------------------
const fd = openSync(fifoPath, 'w');
const CHUNK = 1 << 20;
let buf = new Float64Array(CHUNK / 8);
let n = 0;
function flush() {
  if (n === 0) return;
  const bytes = new Uint8Array(buf.buffer, 0, n * 8);
  let off = 0;
  while (off < bytes.length) off += writeSync(fd, bytes, off, bytes.length - off);
  n = 0;
}
function push(v: number) {
  if (n === buf.length) flush();
  buf[n++] = v;
}
for (const c of cases) {
  const fn = MODE_FRAMES[c.mode as keyof typeof MODE_FRAMES];
  for (const t of c.ts) {
    let f;
    try {
      f = fn(c.size, t, { ...c.opts });
    } catch {
      push(-1);
      push(0);
      continue;
    }
    push(f.dots.length);
    push(f.lines.length);
    for (const d of f.dots) {
      push(d.x);
      push(d.y);
      push(d.z);
      push(d.r);
      push(d.white);
      push(d.a ?? 1);
    }
    for (const l of f.lines) {
      push(l.x1);
      push(l.y1);
      push(l.x2);
      push(l.y2);
      push(l.white);
      push(l.a ?? 1);
      push(l.w);
    }
  }
}
flush();
closeSync(fd);
