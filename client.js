/* 无限四代 (dsh-infinite-gen-4) client half — realtime "破甲已开启" badge.
 * Reads the host "armor" session projection via useProjection:
 *   user message -> breathing pulse "思考中…"
 *   assistant message -> ✓ 通过 (green flash) | ◐ 未完交付 (yellow flash)
 *                        | ✗ <拒绝词> (red flash)
 * 0.5.2：徽标可点击，切换启用范围（局部=只有破甲模式 / 全局=所有模式）。
 *   范围状态走宿主 HTTP 路由 /gen4/scope（GET 读、POST 写），服务端热生效。
 */
window.__ModuleLoader__.load({
  id: "dsh-infinite-gen-4",
  factory: (require) => {
    var module = { exports: {} };
    var exports = module.exports;
    Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });

    var react = require("react");

    var inject = ["slots"];

    var ANIM_CSS = "@keyframes dshArmorPulse{0%,100%{box-shadow:0 0 2px rgba(34,197,94,.5);opacity:1}50%{box-shadow:0 0 12px rgba(34,197,94,1);opacity:.55}}@keyframes dshArmorFlash{0%{transform:scale(1)}30%{transform:scale(1.12)}100%{transform:scale(1)}}";

    var SCOPE_URL = "/gen4/scope";
    var POLL_MS = 4000;
    var WRAP_STYLE = {
      display: "flex",
      justifyContent: "center",
      width: "100%"
    };
    var BADGE_STYLE = {
      display: "inline-flex",
      alignItems: "center",
      gap: "5px",
      width: "fit-content",
      padding: "3px 10px",
      borderRadius: "6px",
      border: "1px solid rgba(34, 197, 94, 0.4)",
      background: "rgba(34, 197, 94, 0.1)",
      color: "inherit",
      fontSize: "11px",
      lineHeight: "16px",
      fontFamily: "inherit",
      userSelect: "none",
      whiteSpace: "nowrap",
      cursor: "pointer"
    };
    var DOT_STYLE = {
      width: "6px",
      height: "6px",
      borderRadius: "50%",
      background: "#22c55e",
      flex: "none"
    };
    var FLASH_MS = 2500;

    function readScope(done) {
      try {
        fetch(SCOPE_URL, { headers: { accept: "application/json" } })
          .then(function (res) { return res.json(); })
          .then(function (data) { done(data || null); })
          .catch(function () { done(null); });
      } catch {
        done(null);
      }
    }

    function writeScope(next, done) {
      try {
        fetch(SCOPE_URL, {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({ scope: next })
        })
          .then(function (res) { return res.json(); })
          .then(function (data) { done(data || null); })
          .catch(function () { done(null); });
      } catch {
        done(null);
      }
    }

    function ArmorDock(props) {
      var useProjection = props.useProjection;
      // 只有选中「破甲模式」预设的会话显示徽标；全局启用后所有预设都显示（可点回去）。
      var preset = typeof useProjection === "function"
        ? useProjection("agentPreset")
        : undefined;
      var armor = typeof useProjection === "function"
        ? useProjection("armor")
        : undefined;

      var scopePair = react.useState(null);
      var scope = scopePair[0];
      var setScope = scopePair[1];
      var busyPair = react.useState(false);
      var busy = busyPair[0];
      var setBusy = busyPair[1];
      var notePair = react.useState("");
      var note = notePair[0];
      var setNote = notePair[1];
      var lastVerdictRef = react.useRef(null);
      var flashUntilRef = react.useRef(0);
      var tickPair = react.useState(0);
      var setTick = tickPair[1];

      react.useEffect(function () {
        var styleEl = null;
        if (!document.getElementById("dsh-armor-css")) {
          styleEl = document.createElement("style");
          styleEl.id = "dsh-armor-css";
          styleEl.textContent = ANIM_CSS;
          document.head.appendChild(styleEl);
        }
        return function () { if (styleEl) styleEl.remove(); };
      }, []);

      // 范围轮询：徽标点击后、以及在别处（scope.ps1）改过设置时都能同步。
      react.useEffect(function () {
        var alive = true;
        var apply = function (data) {
          if (!alive || !data) return;
          if (typeof data.scope === "string") setScope(data.scope);
          if (data.envOverride) setNote("范围已被环境变量 GEN4_SCOPE 固定：" + data.envOverride);
        };
        readScope(apply);
        var timer = setInterval(function () { readScope(apply); }, POLL_MS);
        return function () { alive = false; clearInterval(timer); };
      }, []);

      // 投影值变化时：记录判定并开启 2.5s 展示窗口（纯前端计时）
      react.useEffect(function () {
        var v = armor && armor.verdict ? armor.verdict : null;
        if (v !== lastVerdictRef.current) {
          lastVerdictRef.current = v;
          if (v) flashUntilRef.current = Date.now() + FLASH_MS;
          setTick(Date.now());
        }
      }, [armor]);

      var global = scope === "global";
      var visible = preset === "armor" || global;
      if (!visible) return null;

      var running = !!(armor && armor.running);
      var words = armor && Array.isArray(armor.words) ? armor.words : [];
      var showVerdict = !running && lastVerdictRef.current !== null &&
        Date.now() < flashUntilRef.current;

      var text = global ? "破甲已开启 · 全部模式" : "破甲已开启 · 无限四代";
      var dotStyle = Object.assign({}, DOT_STYLE);
      var badgeStyle = Object.assign({}, BADGE_STYLE);

      if (running) {
        dotStyle.animation = "dshArmorPulse 1.2s ease-in-out infinite";
        text = "思考中…";
      } else if (showVerdict) {
        if (lastVerdictRef.current === "pass") {
          text = "✓ 通过";
          badgeStyle.animation = "dshArmorFlash 1.2s ease";
        } else if (lastVerdictRef.current === "partial") {
          text = "◐ 未完交付";
          badgeStyle.animation = "dshArmorFlash 1.4s ease";
          badgeStyle.borderColor = "rgba(245, 158, 11, 0.5)";
          badgeStyle.background = "rgba(245, 158, 11, 0.12)";
          dotStyle.background = "#f59e0b";
        } else {
          text = "✗ " + (words[0] || "拒绝话术");
          badgeStyle.animation = "dshArmorFlash 1.6s ease";
          badgeStyle.borderColor = "rgba(239, 68, 68, 0.5)";
          badgeStyle.background = "rgba(239, 68, 68, 0.12)";
          dotStyle.background = "#ef4444";
        }
      }

      if (note) text = note;
      if (busy) badgeStyle.opacity = "0.6";

      function onClick() {
        if (busy) return;
        var next = global ? "local" : "global";
        setBusy(true);
        writeScope(next, function (data) {
          setBusy(false);
          if (data && data.ok) {
            setScope(data.scope || next);
            setNote("");
            return;
          }
          if (data && data.error === "env-override") {
            setNote("已被环境变量 GEN4_SCOPE 固定，无法在界面切换");
            return;
          }
          setNote("切换失败，请重试");
          setTimeout(function () { setNote(""); }, 4000);
        });
      }

      var title = global
        ? "当前：全部模式都注入破甲框架（点击改为「只有破甲模式」）"
        : "当前：只有破甲模式的会话注入（点击改为「全部模式都启用」）";

      return react.createElement(
        "div",
        { style: WRAP_STYLE },
        react.createElement(
          "div",
          {
            style: badgeStyle,
            "data-armor": "gen4",
            "data-scope": scope || "unknown",
            role: "button",
            tabIndex: 0,
            title: title,
            onClick: onClick,
            onKeyDown: function (event) {
              if (event.key === "Enter" || event.key === " ") onClick();
            }
          },
          react.createElement("span", { style: dotStyle }),
          react.createElement("span", null, text)
        )
      );
    }

    function apply(ctx) {
      ctx.slots.inject("conversation.input.dock", () =>
        ctx.slots.register({
          name: "conversation.input.dock",
          id: "armor",
          order: 30
        }, ArmorDock)
      );
    }

    exports.name = "dsh-infinite-gen-4";
    exports.inject = inject;
    exports.apply = apply;
    return module.exports;
  }
});
