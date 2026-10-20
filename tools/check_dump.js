#!/usr/bin/env node
// check_dump.js — 注入载荷外部校验器（v0.4.7 完成判据 ①）
//
// 读 GEN4_DUMP_PROMPT 产出的 dump 文件，回答一个问题：
//   「甲的正文 + preheat + align + reanchor 四个片段，是否都真的进了这次请求？」
// 判据（全部磁盘可验）：
//   1. 四个片段各出现 >= 1 次；
//   2. 每个块的 len 与 sha12 与块内正文**自洽**（说明 dump 没被截断/改写）；
//   3. armor 块的 sha12 等于插件 prompts/variants/<variant>.md 的 sha12（源真值）。
// 用法：
//   node check_dump.js <dumpPath> [--armor-file <path>] [--kinds armor,preheat,align,reanchor]
// 输出：DUMP-CHECK-OK blocks=N kinds=...  或  DUMP-CHECK-FAIL <原因>
import { existsSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve, dirname } from "node:path";

const argv = process.argv.slice(2);
const dumpPath = argv.find((a) => !a.startsWith("--"));
function opt(name, dflt) {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt;
}
const kindsWanted = opt("--kinds", "armor,preheat,align,reanchor").split(",").map((s) => s.trim()).filter(Boolean);
const armorFile = opt("--armor-file", "");

function sha12(text) {
  return createHash("sha256").update(String(text), "utf8").digest("hex").slice(0, 12);
}
function fail(msg) {
  console.log(`DUMP-CHECK-FAIL ${msg}`);
  process.exit(1);
}

if (!dumpPath) fail("用法：node check_dump.js <dumpPath> [--armor-file <path>]");
if (!existsSync(dumpPath)) fail(`dump 文件不存在：${dumpPath}`);

const lines = readFileSync(dumpPath, "utf8").split("\n");
const HEAD = /^===== FRAGMENT #(\d+) kind=(\w+) len=(\d+) sha12=([0-9a-f]{12})/;
const blocks = [];
for (let i = 0; i < lines.length; i++) {
  const m = HEAD.exec(lines[i]);
  if (!m) continue;
  const [, idx, kind, len, sha] = m;
  const endMarker = `===== END #${idx} =====`;
  const body = [];
  let j = i + 1;
  for (; j < lines.length; j++) {
    if (lines[j] === endMarker) break;
    body.push(lines[j]);
  }
  if (j >= lines.length) fail(`第 ${idx} 块缺少 END 标记（dump 被截断？）`);
  blocks.push({ idx: Number(idx), kind, len: Number(len), sha, text: body.join("\n") });
  i = j;
}

if (blocks.length === 0) fail(`dump 里没有任何 FRAGMENT 块：${dumpPath}`);

const problems = [];
const byKind = new Map();
for (const b of blocks) {
  byKind.set(b.kind, (byKind.get(b.kind) || 0) + 1);
  if (b.text.length !== b.len) problems.push(`#${b.idx} ${b.kind} len 不自洽：头部 ${b.len} vs 实际 ${b.text.length}`);
  const h = sha12(b.text);
  if (h !== b.sha) problems.push(`#${b.idx} ${b.kind} sha12 不自洽：头部 ${b.sha} vs 实算 ${h}`);
}

for (const k of kindsWanted) {
  if (!byKind.get(k)) problems.push(`片段缺失：${k}（一次都没记录）`);
}

// armor 源真值比对
let armorNote = "";
if (armorFile) {
  if (!existsSync(armorFile)) {
    problems.push(`armor 源文件不存在：${armorFile}`);
  } else {
    const want = sha12(readFileSync(armorFile, "utf8"));
    const got = blocks.filter((b) => b.kind === "armor").map((b) => b.sha);
    if (!got.includes(want)) {
      problems.push(`armor 片段与源文件不一致：源 ${want} vs dump ${got.join("/")}（甲被裁剪/替换？）`);
    } else {
      armorNote = ` armor=src:${want}`;
    }
  }
}

// INJECT-INCOMPLETE 出现即记录（不一定是失败：可能只是某种片段本会话未用到）
const incompletes = lines.filter((l) => l.includes("INJECT-INCOMPLETE")).length;

const summary =
  `blocks=${blocks.length} kinds=${[...byKind.entries()].map(([k, n]) => `${k}:${n}`).join(",")}` +
  `${armorNote} incomplete=${incompletes}`;

if (problems.length) fail(`${summary} —— ${problems.join(" | ")}`);
console.log(`DUMP-CHECK-OK ${summary}`);