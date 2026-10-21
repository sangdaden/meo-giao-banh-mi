// Tự kiểm tra bản mới cho bản web (GitHub Pages).
// GitHub Actions thay __BUILD_VERSION__ bằng mã commit và ghi version.json cạnh index.html.
// Mỗi phút trang hỏi version.json (không dùng bộ nhớ đệm). Thấy khác bản đang chạy thì:
// tải trước các file mới vào bộ nhớ đệm, hiện thông báo và tự tải lại sau 10 giây.
(function () {
  var CURRENT = "__BUILD_VERSION__";
  if (CURRENT.indexOf("__") === 0) return; // chạy thử ngoài GitHub Actions: bỏ qua
  var FILES = ["index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js", "update-check.js"];
  var shown = false;
  var KEY = "meo-reload-for";

  // Nhớ bản đã tải lại để tới. Nếu tải lại rồi mà máy chủ vẫn trả file cũ
  // (bộ nhớ đệm của GitHub Pages chưa kịp đổi) thì không tự tải lại lần nữa, tránh lặp vô hạn.
  function remember(v) { try { sessionStorage.setItem(KEY, v); } catch (e) {} }
  function triedBefore(v) { try { return sessionStorage.getItem(KEY) === v; } catch (e) { return false; } }

  function refreshCache() {
    return Promise.all(FILES.map(function (f) {
      return fetch(f, { cache: "reload" }).catch(function () {});
    }));
  }

  function showBanner(version, auto) {
    if (shown) return;
    shown = true;
    var left = 10;
    var bar = document.createElement("div");
    bar.setAttribute("role", "status");
    bar.style.cssText = "position:fixed;left:50%;top:16px;transform:translateX(-50%);z-index:9999;" +
      "background:#1F2A2A;color:#FFF8EA;font:600 16px system-ui,sans-serif;padding:10px 14px 10px 18px;" +
      "border-radius:999px;box-shadow:0 4px 16px rgba(0,0,0,.3);display:flex;gap:12px;align-items:center";
    var text = document.createElement("span");
    var now = document.createElement("button");
    now.textContent = "Tải lại ngay";
    now.style.cssText = "font:600 15px system-ui,sans-serif;background:#D98E2B;color:#2A1A05;border:0;border-radius:999px;padding:6px 14px;cursor:pointer";
    var later = document.createElement("button");
    later.textContent = "Để sau";
    later.style.cssText = "font:600 15px system-ui,sans-serif;background:transparent;color:#FFF8EA;border:1px solid #5E6F6C;border-radius:999px;padding:6px 12px;cursor:pointer";
    bar.appendChild(text); bar.appendChild(now); bar.appendChild(later);
    document.body.appendChild(bar);
    function reload() { remember(version); location.reload(); }
    function render() { text.textContent = "Có bản mới! Tự tải lại sau " + left + " giây"; }
    var timer = null;
    if (auto) {
      render();
      timer = setInterval(function () {
        left -= 1;
        if (left <= 0) { clearInterval(timer); reload(); } else { render(); }
      }, 1000);
    } else {
      text.textContent = "Có bản mới! Nhấn tải lại để chơi bản mới";
    }
    now.onclick = function () { clearInterval(timer); reload(); };
    later.onclick = function () { clearInterval(timer); text.textContent = "Có bản mới, tải lại trang khi chơi xong nhé"; later.remove(); };
  }

  function check() {
    fetch("version.json?t=" + Date.now(), { cache: "no-store" })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (v) {
        if (v && v.version && v.version !== CURRENT) {
          var auto = !triedBefore(v.version);
          refreshCache().then(function () { showBanner(v.version, auto); });
        }
      })
      .catch(function () {});
  }

  window.addEventListener("load", function () { setTimeout(check, 3000); });
  setInterval(check, 60000);
  document.addEventListener("visibilitychange", function () { if (!document.hidden) check(); });
})();
