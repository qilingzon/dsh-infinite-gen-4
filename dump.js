// dump.js — 注入可视性（v0.4.7, 2026-09-21）
//
// 为什么需要它：VPS 上出现过「插件树加载成功 + 徽标在场 + 注入动作发生，但模型仍拒」的形态，
// 当时**无法回答**一个基本问题：甲的正文到底有没有被送进 system prompt？
// 没有这个读数，一切"甲失效"的判断都是猜。本模块把每次请求最终注入的片段
// 带长度与 sha256 落盘，让"甲进没进 payload"变成磁盘事实。
//
// 用法：GEN4_DUMP_PROMPT=/root/gen4-inject.log
//   → 主日志 append-only，每条片段一个块（含 len + sha12）
//   → 同目录 <path>.manifest 是每次写入都刷新的小 JSON（counts / hashes / incomplete）
// 片段种类：armor（甲正文）· preheat（冷启动预热）· align（口径对齐）· reanchor（框架重申）
//
// 设计约束：
//   · 永不抛异常 —— 观测模块不许拖垮宿主主循环（全部 try/catch 吞掉）。
//   · 未启用时零开销（enabled=false 时 record 直接 return）。
//   · 空载荷 = 故障，必须显式记 INJECT-INCOMPLETE（这是"绝不静默失败"的落点）。
import { appendFileSync, mkdirSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname } from "node:path";

export const FRAGMENT_KINDS = ["armor", "preheat", "align", "reanchor"];

export function sha12(text) {
  try {
    return createHash("sha256").update(String(text ?? ""), "utf8").digest("hex").slice(0, 12);
  } catch {
    return "000000000000";
  }
}

function sanitizeMeta(meta) {
  if (!meta || typeof meta !== "object") return "";
  const parts = [];
  for (const [k, v] of Object.entries(meta)) {
    if (v === undefined || v === null || v === "") continue;
    parts.push(`${k}=${String(v).replace(/[\s=]+/g, "_").slice(0, 40)}`);
  }
  return parts.length ? " " + parts.join(" ") : "";
}

export function makeDumper(path) {
  const enabled = typeof path === "string" && path.length > 0;
  const manifestPath = enabled ? `${path}.manifest` : "";
  const counts = new Map(FRAGMENT_KINDS.map((k) => [k, 0]));
  const last = new Map();
  const incomplete = [];
  const startedAt = new Date().toISOString();
  let blockIndex = 0;

  function flushManifest() {
    if (!enabled) return;
    try {
      writeFileSync(
        manifestPath,
        JSON.stringify(
          {
            plugin: "dsh-infinite-gen-4",
            schema: 1,
            startedAt,
            updatedAt: new Date().toISOString(),
            dumpPath: path,
            kinds: Object.fromEntries(
              FRAGMENT_KINDS.map((k) => [
                k,
                { count: counts.get(k) || 0, last: last.get(k) || null },
              ]),
            ),
            incomplete: incomplete.slice(-50),
          },
          null,
          2,
        ) + "\n",
        "utf8",
      );
    } catch {
      // 忽略
    }
  }

  function append(line) {
    try {
      appendFileSync(path, line, "utf8");
    } catch {
      // 目录可能不存在：补一次
      try {
        mkdirSync(dirname(path), { recursive: true });
        appendFileSync(path, line, "utf8");
      } catch {
        // 仍然失败就放弃（观测不许影响主流程）
      }
    }
  }

  function noteIncomplete(kind, reason) {
    const entry = { at: new Date().toISOString(), kind, reason };
    incomplete.push(entry);
    append(`\n!! INJECT-INCOMPLETE kind=${kind} reason=${reason} at=${entry.at}\n`);
    try {
      console.error(`dsh-infinite-gen-4: INJECT-INCOMPLETE kind=${kind} reason=${reason}`);
    } catch {
      // 忽略
    }
    flushManifest();
  }

  return {
    enabled,
    path,
    manifestPath,

    /** 记录一个注入片段。返回 true 表示记录成功。 */
    record(kind, text, meta) {
      if (!enabled) return false;
      try {
        const s = typeof text === "string" ? text : text == null ? "" : String(text);
        if (!s.trim()) {
          noteIncomplete(kind, "empty");
          return false;
        }
        const h = sha12(s);
        blockIndex += 1;
        counts.set(kind, (counts.get(kind) || 0) + 1);
        last.set(kind, { len: s.length, sha12: h });
        append(
          `\n===== FRAGMENT #${blockIndex} kind=${kind} len=${s.length} sha12=${h}` +
            `${sanitizeMeta(meta)} at=${new Date().toISOString()} =====\n${s}\n===== END #${blockIndex} =====\n`,
        );
        flushManifest();
        return true;
      } catch {
        return false;
      }
    },

    /** 收尾自检：四种片段只要有一种一次都没记录过，就显式记 INJECT-INCOMPLETE。 */
    finalize() {
      if (!enabled) return { ok: true, missing: [] };
      try {
        const missing = FRAGMENT_KINDS.filter((k) => (counts.get(k) || 0) === 0);
        for (const k of missing) noteIncomplete(k, "never-recorded");
        flushManifest();
        return { ok: missing.length === 0, missing };
      } catch {
        return { ok: false, missing: FRAGMENT_KINDS.slice() };
      }
    },

    stats() {
      return {
        enabled,
        path,
        counts: Object.fromEntries(counts),
        incomplete: incomplete.length,
      };
    },
  };
}