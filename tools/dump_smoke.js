#!/usr/bin/env node
// dump_smoke.js — dump.js 单元冒烟 + 端到端校验器联测
// 断言：
//   A. 四片段写入后，dump 文件含 4 个块，manifest 的 counts 与块数一致
//   B. 空载荷 → 记 INJECT-INCOMPLETE（绝不静默）
//   C. 未启用（无路径）→ record 返回 false，不创建任何文件
//   D. check_dump.js 对这份 dump 判 OK，且 armor 源真值比对通过
//   E. finalize() 在缺片段时报 missing
import { mkdtempSync, readFileSync, existsSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { makeDumper, sha12 } from "../../po-gen/versions/po-gen-4-v0.4.7/dump.js";

const HERE = dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1"));
let bad = 0;
const ck = (label, ok, extra = "") => {
  console.log(`  ${ok ? "[OK]" : "[X] "} ${label}${extra ? "  " + extra : ""}`);
  if (!ok) bad += 1;
};

const dir = mkdtempSync(join(tmpdir(), "v047dump-"));
const dumpPath = join(dir, "inject.log");

// --- C: 未启用 ---
const off = makeDumper("");
ck("C1 未启用时 enabled=false", off.enabled === false);
ck("C2 未启用时 record 返回 false", off.record("armor", "x") === false);
ck("C3 未启用时不创建文件", !existsSync(join(dir, "x")));

// --- A/B: 启用 ---
const d = makeDumper(dumpPath);
ck("A1 enabled=true", d.enabled === true);
const armorText = readFileSync(resolve(HERE, "../../po-gen/versions/po-gen-4-v0.4.7/prompts/variants/b37-coldstart.md"), "utf8");
ck("A2 armor 记录成功", d.record("armor", armorText, { variant: "b37-coldstart" }) === true);
ck("A3 preheat 记录成功", d.record("preheat", "预热任务卡\n---\n预热结果", { mode: "history" }) === true);
ck("A4 align 记录成功", d.record("align", "口径对齐任务\n口径对齐结果", { cls: "third-party" }) === true);
ck("A5 reanchor 记录成功", d.record("reanchor", "框架重申正文") === true);
ck("B1 空载荷被拒（返回 false）", d.record("align", "   ") === false);
ck("B2 空载荷写了 INJECT-INCOMPLETE", readFileSync(dumpPath, "utf8").includes("INJECT-INCOMPLETE kind=align reason=empty"));

const manifest = JSON.parse(readFileSync(dumpPath + ".manifest", "utf8"));
ck("A6 manifest counts 正确", manifest.kinds.armor.count === 1 && manifest.kinds.preheat.count === 1 && manifest.kinds.align.count === 1 && manifest.kinds.reanchor.count === 1);
ck("A7 manifest incomplete 记了 1 条", manifest.incomplete.length === 1);
ck("A8 manifest armor sha 与源一致", manifest.kinds.armor.last.sha12 === sha12(armorText), `${manifest.kinds.armor.last.sha12} vs ${sha12(armorText)}`);

// --- D: 外部校验器 ---
const checker = resolve(HERE, "check_dump.js");
const armorFile = resolve(HERE, "../../po-gen/versions/po-gen-4-v0.4.7/prompts/variants/b37-coldstart.md");
const r = spawnSync(process.execPath, [checker, dumpPath, "--armor-file", armorFile], { encoding: "utf8" });
const out = (r.stdout || "") + (r.stderr || "");
ck("D1 check_dump 判 OK", r.status === 0 && out.includes("DUMP-CHECK-OK"), out.trim().split("\n")[0]);
ck("D2 输出含 armor=src 比对", out.includes("armor=src:"));

// --- D3: 篡改检测（把 armor 块正文改一个字，校验器必须失败）---
const tampered = join(dir, "tampered.log");
const head20 = armorText.slice(0, 20);
const raw = readFileSync(dumpPath, "utf8");
if (!raw.includes(head20)) { ck("D3 前置：dump 里能找到 armor 正文首段", false); }
writeFileSync(tampered, raw.replace(head20, "TAMPERED-BODY-START-XX"), "utf8");
const r2 = spawnSync(process.execPath, [checker, tampered, "--armor-file", armorFile], { encoding: "utf8" });
const out2 = (r2.stdout || "") + (r2.stderr || "");
ck("D3 篡改后校验器报 FAIL", r2.status !== 0 && out2.includes("DUMP-CHECK-FAIL"), out2.trim().split("\n")[0]);

// --- E: finalize ---
const d2 = makeDumper(join(dir, "partial.log"));
d2.record("armor", "只有甲");
const fin = d2.finalize();
ck("E1 finalize 报缺 3 个片段", fin.ok === false && fin.missing.length === 3, JSON.stringify(fin.missing));
ck("E2 finalize 写了 never-recorded", readFileSync(join(dir, "partial.log"), "utf8").includes("reason=never-recorded"));

console.log();
console.log(bad === 0 ? `V047-DUMP-SMOKE-OK` : `V047-DUMP-SMOKE-FAIL bad=${bad}`);
process.exit(bad === 0 ? 0 : 1);