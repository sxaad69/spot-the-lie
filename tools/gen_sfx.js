#!/usr/bin/env node
/* SPOT THE LIE — jsfxr SFX generator (5 files) + ambient loop.
 * Renders 16-bit WAV at 22050 Hz mono from jsfxr params, then ffmpeg -> OGG.
 * All sounds generated-original (jsfxr procedural) — zero license risk.
 * Reuse: node tools/gen_sfx.js   (needs tools/node_modules — npm i jsfxr)
 */
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const jsfxr = require("jsfxr");

const W = jsfxr.waveforms;
const OUT_DIR = path.join(__dirname, "..", "assets", "audio");
fs.mkdirSync(OUT_DIR, { recursive: true });
const SAMPLE_RATE = 22050;

function render(p) {
  const se = new jsfxr.SoundEffect(p);
  const raw = se.getRawBuffer();
  const buf = raw.normalized;
  const n = buf.length;
  const bytes = Buffer.alloc(n * 2);
  for (let i = 0; i < n; i++) {
    let v = Math.max(-1, Math.min(1, buf[i]));
    bytes.writeInt16LE(Math.round(v * 32767), i * 2);
  }
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + bytes.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(SAMPLE_RATE, 24);
  header.writeUInt32LE(SAMPLE_RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(bytes.length, 40);
  return Buffer.concat([header, bytes]);
}

function base() {
  const p = new jsfxr.Params();
  p.sample_rate = SAMPLE_RATE;
  p.sample_size = 16;
  p.sound_vol = 0.5;
  return p;
}

const sounds = {};

// 1. spot-ding: bright rising sine ping with a little sparkle
{
  const p = base();
  p.wave_type = W.SINE;
  p.p_env_attack = 0.005;
  p.p_env_sustain = 0.12;
  p.p_env_decay = 0.4;
  p.p_env_punch = 0.4;
  p.p_base_freq = 0.72;
  p.p_freq_ramp = 0.25;
  sounds.spot = p;
}
// 2. error-buzz: low square buzz, short
{
  const p = base();
  p.wave_type = W.SQUARE;
  p.p_env_attack = 0.002;
  p.p_env_sustain = 0.09;
  p.p_env_decay = 0.28;
  p.p_base_freq = 0.14;
  p.p_freq_ramp = -0.2;
  p.p_lpf_freq = 0.4;
  sounds.error = p;
}
// 3. streak-chime: two-note rising chime (fast repeat trill)
{
  const p = base();
  p.wave_type = W.SINE;
  p.p_env_attack = 0.004;
  p.p_env_sustain = 0.18;
  p.p_env_decay = 0.45;
  p.p_base_freq = 0.82;
  p.p_freq_ramp = 0.35;
  p.p_repeat_speed = 1.4;
  p.p_vib_strength = 0.2;
  p.p_vib_speed = 0.5;
  sounds.streak = p;
}
// 4. clear-sting: cheerful rising arpeggio square, ~0.9s
{
  const p = base();
  p.wave_type = W.SQUARE;
  p.p_env_attack = 0.01;
  p.p_env_sustain = 0.55;
  p.p_env_decay = 0.4;
  p.p_base_freq = 0.6;
  p.p_freq_ramp = 0.3;
  p.p_repeat_speed = 0.55; // arpeggio feel
  p.p_lpf_freq = 0.7;
  sounds.clear = p;
}
// 5. reveal: soft magical shimmer (high sine sweep)
{
  const p = base();
  p.wave_type = W.SINE;
  p.p_env_attack = 0.05;
  p.p_env_sustain = 0.3;
  p.p_env_decay = 0.6;
  p.p_base_freq = 0.88;
  p.p_freq_ramp = -0.1;
  p.p_vib_strength = 0.5;
  p.p_vib_speed = 0.8;
  sounds.reveal = p;
}

// 6. ambient loop: slow dark pad — filtered noise + low sine drone,
// rendered as one long pass then looped by the engine (set loop in import).
{
  const p = base();
  p.wave_type = W.NOISE;
  p.p_env_attack = 1.2;
  p.p_env_sustain = 2.8;
  p.p_env_decay = 1.2;
  p.p_base_freq = 0.08;
  p.p_freq_ramp = 0.01;
  p.p_lpf_freq = 0.12;
  p.p_lpf_ramp = 0.05;
  p.p_hpf_freq = 0.02;
  sounds.ambient = p;
}

for (const [name, p] of Object.entries(sounds)) {
  const wav = render(p);
  const wavPath = path.join(OUT_DIR, name + ".wav");
  fs.writeFileSync(wavPath, wav);
  execSync(`ffmpeg -y -loglevel error -i ${wavPath} -ac 1 -ar 22050 ${path.join(OUT_DIR, name + ".ogg")}`);
  fs.unlinkSync(wavPath);
}
console.log("wrote", Object.keys(sounds).length, "ogg files to", OUT_DIR);
