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
