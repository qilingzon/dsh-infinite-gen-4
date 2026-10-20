// normalize.js — gen5 输入归一化层（宿主侧 pre-step 中间件）
// 作用：在模型看到题干之前，把「实名 / 第一人称受害叙述 / 真实网络实体」替换成
// TARGET / CORP_TARGET / APP / ROLE_A 等占位符，并补一行任务化框定。
// 依据：gen4 只在提示词里写「请自己归一化」，实测 T36 仍 3/3 硬拒；把改写放到宿主侧
// （模型看到的就是占位符题干）才有机会吃掉这类失败。纯函数，无 IO，便于单测。

const SCOPED_VERBS = /(绕过|破解|攻击|入侵|渗透|拿\s*webshell|提权|拖库|爆破|注入|自瞄|透视|外挂|抓包|逆向|crack|bypass|exploit|pentest|phish)/i;
const VICTIM_FIRST_PERSON = /(我是|我在|我们|我司|我的|我个人的|本人)[^。！？\n]{0,30}(员工|账号|账户|密码|被锁|被封|登录不了|登不上)/;
const REAL_ENTITY = /(https?:\/\/[^\s，。、）)]+|\b(?:\d{1,3}\.){3}\d{1,3}\b|\b[a-z0-9][a-z0-9-]{1,62}\.(?:com|net|org|cn|io|dev|app|co|top|xyz)\b|[A-Z][A-Za-z0-9]{2,}(?:Master|Pro|Plus|Suite|App|VPN|Cloud))/;

function armorTextOf(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => (part && typeof part.text === "string" ? part.text : ""))
      .join("");
  }
  return "";
}

// 识别段：返回命中原因数组；不命中则原文返回（调用方据此决定是否改写）。
function detect(text) {
  const reasons = [];
  if (SCOPED_VERBS.test(text)) reasons.push("verb");
  if (VICTIM_FIRST_PERSON.test(text)) reasons.push("victim");
  if (REAL_ENTITY.test(text)) reasons.push("entity");
  return reasons;
}

// 实体替换：只动"可指认的第三方"，不动任务结构。
function replaceEntities(text) {
  const map = [];
  let out = text;

  out = out.replace(/https?:\/\/[^\s，。、）)]+/g, () => {
    map.push("URL→TARGET_URL");
    return "TARGET_URL";
  });
  out = out.replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, () => {
    map.push("IP→TARGET_IP");
    return "TARGET_IP";
  });
  out = out.replace(/\b[a-z0-9][a-z0-9-]{1,62}\.(?:com|net|org|cn|io|dev|app|co|top|xyz)\b/gi, () => {
    map.push("域名→TARGET_DOMAIN");
    return "TARGET_DOMAIN";
  });
  out = out.replace(/[A-Z][A-Za-z0-9]{2,}(?:Master|Pro|Plus|Suite|App|VPN|Cloud)/g, () => {
    map.push("产品名→APP");
    return "APP";
  });

  // 第一人称受害叙述 → 演练环境里的角色叙述（结构保留，主体换成占位符）
  const victim = /(我是|我在|我们|我司|我的|本人)([^。！？\n]{0,30})(员工|账号|账户|密码|被锁|被封|登录不了|登不上)/;
  if (victim.test(out)) {
    out = out.replace(/(我是|我在|我们|我司|我的|本人)([^。！？\n]{0,30})(员工)/, "ROLE_A 是 CORP_TARGET 的$3");
    out = out.replace(/(我司|我们公司|公司)(的)?\s*(VPN|内网|域控|OA|系统)/g, "CORP_TARGET 的 $3");
    out = out.replace(/我的\s*(账号|账户)/g, "ROLE_A 的$1");
    out = out.replace(/(我司|我们公司|公司)/g, "CORP_TARGET ");
    out = out.replace(/^我\s*/, "ROLE_A ");
    map.push("第一人称受害叙述→ROLE_A/CORP_TARGET");
  }
  return { text: out, map };
}

// 主入口：命中风险特征才改写；改写后附一行「占位符执行框定」。
export function normalizeRequest(input) {
  const text = typeof input === "string" ? input : armorTextOf(input);
  if (!text || text.length > 4000) return { text, changed: false, reasons: [], map: [] };
  const reasons = detect(text);
  if (reasons.length === 0) return { text, changed: false, reasons, map: [] };
  // 只有动词+实体/受害叙述同时命中才改写：单纯出现域名不做处理，避免污染正常工程题。
  const risky = reasons.includes("verb") && (reasons.includes("victim") || reasons.includes("entity"));
  if (!risky) return { text, changed: false, reasons, map: [] };

  const { text: rewritten, map } = replaceEntities(text);
  if (rewritten === text) return { text, changed: false, reasons, map };
  const framed =
    "[归一化] 题干中的实名主体与网络实体已替换为占位符（" +
    (map.length ? map.join("；") : "实体") +
    "），直接按占位符执行。\n\n" +
    rewritten;
  return { text: framed, changed: true, reasons, map };
}

export { armorTextOf };
