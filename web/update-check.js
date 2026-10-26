// Người gác: bản web hay "đứng đen màn" khi trình duyệt mất phần đồ họa (WebGL context lost), khi game lỗi
// (wasm abort) hoặc treo. Thay vì để màn đen, hiện bảng có nút Tải lại và một dòng mã lỗi để chụp gửi lại.
// Game gửi nhịp mỗi giây qua window.meoNhip(cảnh) (scripts/trang_web.gd); im quá IM_LAU giây lúc tab đang mở là treo.
(function () {
  var IM_LAU = 25;
  var TEXT = {
    vi: { lost: "Trình duyệt vừa tắt phần đồ họa của game nên màn hình bị đen.", crash: "Game vừa gặp lỗi và dừng lại.",
          hang: "Game không phản hồi đã %s giây.", reload: "Tải lại trang", wait: "Chờ thêm",
          hint: "Chụp màn hình bảng này gửi cho người làm game giúp nhé." },
    en: { lost: "The browser switched off the game's graphics, so the screen went black.", crash: "The game hit an error and stopped.",
          hang: "The game has not responded for %s seconds.", reload: "Reload page", wait: "Keep waiting",
          hint: "Please send a screenshot of this box to the developer." }
  };
  var start = Date.now();
  var lastBeat = 0, scene = "", hiddenAt = 0, box = null, waiting = 0;

  function lang() { var g = window.meoGame || {}; return g.lang === "en" ? "en" : "vi"; }
  function gpu() {
    try {
      var c = document.createElement("canvas").getContext("webgl2") || document.createElement("canvas").getContext("webgl");
      var e = c && c.getExtension("WEBGL_debug_renderer_info");
      return e ? c.getParameter(e.UNMASKED_RENDERER_WEBGL) : "?";
    } catch (err) { return "?"; }
  }
  function code(reason) {
    var g = window.meoGame || {};
    return [reason, "cảnh " + (scene || "?"), g.trang_thai || "?", Math.round((Date.now() - start) / 1000) + "s",
      screen.width + "x" + screen.height + "@" + (window.devicePixelRatio || 1), gpu(), navigator.userAgent].join(" · ");
  }
  function show(reason, msg, canWait) {
    var info = code(reason);
    try { localStorage.setItem("meo-loi-cuoi", new Date().toISOString() + " · " + info); } catch (e) {}
    console.error("[meo] " + info);
    if (box) box.remove();
    var t = TEXT[lang()];
    box = document.createElement("div");
    box.setAttribute("role", "alertdialog");
    box.style.cssText = "position:fixed;inset:0;z-index:10000;display:flex;align-items:center;justify-content:center;" +
      "background:rgba(31,42,42,.85);font:16px system-ui,sans-serif;color:#1F2A2A;padding:16px";
    var card = document.createElement("div");
    card.style.cssText = "background:#FFF8EA;border:3px solid #1F2A2A;border-radius:18px;max-width:560px;padding:22px 24px;box-shadow:0 6px 0 #1F2A2A";
    var h = document.createElement("div");
    h.style.cssText = "font-weight:700;font-size:20px;margin-bottom:14px";
    h.textContent = msg;
    var row = document.createElement("div");
    row.style.cssText = "display:flex;gap:10px;flex-wrap:wrap;margin-bottom:14px";
    var re = document.createElement("button");
    re.textContent = t.reload;
    re.style.cssText = "font:600 16px system-ui,sans-serif;background:#D98E2B;color:#2A1A05;border:2px solid #1F2A2A;border-radius:999px;padding:8px 18px;cursor:pointer";
    re.onclick = function () { location.reload(); };
    row.appendChild(re);
    if (canWait) {
      var w = document.createElement("button");
      w.textContent = t.wait;
      w.style.cssText = "font:600 16px system-ui,sans-serif;background:transparent;border:2px solid #1F2A2A;border-radius:999px;padding:8px 16px;cursor:pointer";
      w.onclick = function () { waiting = Date.now(); hide(); };
      row.appendChild(w);
    }
    var small = document.createElement("div");
    small.style.cssText = "font-size:12px;color:#5E6F6C;word-break:break-word";
    small.textContent = t.hint + " " + info;
    card.appendChild(h); card.appendChild(row); card.appendChild(small);
    box.appendChild(card);
    document.body.appendChild(box);
  }
  function hide() { if (box) { box.remove(); box = null; } }

  window.meoNhip = function (s) {
    lastBeat = Date.now();
    if (s) scene = s;
    if (box && box.getAttribute("data-hang")) hide();  // game chạy lại sau lúc treo
  };
  window.addEventListener("load", function () {
    var c = document.querySelector("canvas");
    if (c) c.addEventListener("webglcontextlost", function () { show("webgl-lost", TEXT[lang()].lost, false); }, false);
  });
  window.addEventListener("error", function (e) {
    var m = String((e && (e.message || (e.error && e.error.message))) || "");
    if (/RuntimeError|unreachable|out of bounds|Aborted|OOM|memory/i.test(m)) show("wasm: " + m.slice(0, 80), TEXT[lang()].crash, false);
  });
  window.addEventListener("unhandledrejection", function (e) {
    var m = String((e && e.reason && (e.reason.message || e.reason)) || "");
    if (/RuntimeError|unreachable|out of bounds|Aborted|OOM/i.test(m)) show("wasm: " + m.slice(0, 80), TEXT[lang()].crash, false);
  });
  // Tab ẩn thì trình duyệt ngừng vẽ, game cũng ngừng gửi nhịp: không tính khoảng đó là treo.
  document.addEventListener("visibilitychange", function () {
    if (document.hidden) hiddenAt = Date.now();
    else if (lastBeat) lastBeat = Math.max(lastBeat, Date.now());
  });
  setInterval(function () {
    if (!lastBeat || document.hidden || (box && !box.getAttribute("data-hang"))) return;
    var since = Math.max(lastBeat, waiting);
    var s = Math.round((Date.now() - since) / 1000);
    if (s >= IM_LAU && !box) {
      show("hang", TEXT[lang()].hang.replace("%s", s), true);
      box.setAttribute("data-hang", "1");
    }
  }, 1000);
})();

// Tự kiểm tra bản mới cho bản web (GitHub Pages, itch.io).
// GitHub Actions thay __BUILD_VERSION__ bằng mã commit và ghi version.json cạnh index.html.
// Mỗi phút trang hỏi version.json (không dùng bộ nhớ đệm). Thấy khác bản đang chạy thì chờ lúc an toàn
// rồi mới hiện dải báo (PH1): game báo chỗ đang đứng qua window.meoGame (scripts/trang_web.gd),
// chỉ báo ở màn hình chính ("menu") hoặc bảng kết quả ("ket_ngay"). Đang chơi thì không báo,
// không tự tải lại và không tải trước file mới; chỉ tải khi người chơi bấm nút.
(function () {
  var CURRENT = "__BUILD_VERSION__";
  if (CURRENT.indexOf("__") === 0) return; // chạy thử ngoài GitHub Actions: bỏ qua
  var FILES = ["index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js", "update-check.js"];
  var KEY = "meo-reload-for";
  var TEXT = {
    vi: { msg: "Có bản mới của game!", now: "Tải bản mới", later: "Để sau", loading: "Đang tải bản mới…" },
    en: { msg: "A new version is out!", now: "Update now", later: "Later", loading: "Downloading the new version…" }
  };
  var pending = null;   // mã bản mới đang chờ báo
  var dismissed = null; // bản người chơi đã bấm "Để sau"
  var bar = null;

  // Nhớ bản đã tải lại để tới. Nếu tải lại rồi mà máy chủ vẫn trả file cũ
  // (bộ nhớ đệm của GitHub Pages chưa kịp đổi) thì không báo lại bản đó trong phiên này, tránh lặp.
  function remember(v) { try { sessionStorage.setItem(KEY, v); } catch (e) {} }
  function triedBefore(v) { try { return sessionStorage.getItem(KEY) === v; } catch (e) { return false; } }

  function game() { return window.meoGame || {}; }
  function safeNow() { var s = game().trang_thai; return s === "menu" || s === "ket_ngay"; }
  function lang() {
    var l = game().lang;
    if (!l) l = (navigator.language || "vi").toLowerCase().indexOf("vi") === 0 ? "vi" : "en";
    return TEXT[l] ? l : "vi";
  }

  function button(label, primary) {
    var b = document.createElement("button");
    b.textContent = label;
    b.style.cssText = "font:600 15px system-ui,sans-serif;border-radius:999px;cursor:pointer;" + (primary
      ? "background:#D98E2B;color:#2A1A05;border:0;padding:6px 14px"
      : "background:transparent;color:#FFF8EA;border:1px solid #5E6F6C;padding:6px 12px");
    return b;
  }

  function hide() { if (bar) { bar.remove(); bar = null; } }

  function show() {
    var t = TEXT[lang()];
    if (bar && bar.getAttribute("data-lang") === lang()) return;
    hide();
    bar = document.createElement("div");
    bar.setAttribute("role", "status");
    bar.setAttribute("data-lang", lang());
    bar.style.cssText = "position:fixed;left:50%;top:16px;transform:translateX(-50%);z-index:9999;max-width:calc(100% - 32px);" +
      "background:#1F2A2A;color:#FFF8EA;font:600 16px system-ui,sans-serif;padding:10px 14px 10px 18px;flex-wrap:wrap;" +
      "border-radius:999px;box-shadow:0 4px 16px rgba(0,0,0,.3);display:flex;gap:12px;align-items:center";
    var text = document.createElement("span");
    text.textContent = t.msg;
    var now = button(t.now, true);
    var later = button(t.later, false);
    bar.appendChild(text); bar.appendChild(now); bar.appendChild(later);
    document.body.appendChild(bar);
    var version = pending;
    now.onclick = function () {
      text.textContent = t.loading;
      now.remove(); later.remove();
      // Tải file mới vào bộ nhớ đệm của trình duyệt rồi mới tải lại trang, để không chạy lại bản cũ.
      Promise.all(FILES.map(function (f) {
        return fetch(f, { cache: "reload" }).catch(function () {});
      })).then(function () { remember(version); location.reload(); });
    };
    later.onclick = function () { dismissed = version; hide(); };
  }

  // Gọi khi có bản mới hoặc khi game đổi chỗ (scripts/trang_web.gd gọi window.meoGameDoi).
  function update() {
    if (pending && pending !== dismissed && safeNow()) show();
    else if (bar && !safeNow() && bar.querySelector("button")) hide();
  }
  window.meoGameDoi = update;

  function check() {
    fetch("version.json?t=" + Date.now(), { cache: "no-store" })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (v) {
        if (v && v.version && v.version !== CURRENT && !triedBefore(v.version)) {
          pending = v.version;
          update();
        }
      })
      .catch(function () {});
  }

  window.addEventListener("load", function () { setTimeout(check, 3000); });
  setInterval(check, 60000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) check(); });
})();
