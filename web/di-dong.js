// G3 chơi trên điện thoại (nút cảm ứng ở scripts/cam_ung.gd). Phần của trang:
//  - điện thoại đang dựng đứng: hiện bảng "Xoay ngang điện thoại" (game vẽ cho màn ngang);
//  - chạm lần đầu: xin toàn màn hình và khóa màn ngang (Android Chrome; iPhone Safari không cho, bỏ qua);
//  - mở từ biểu tượng ngoài màn hình chính (web/manifest.json) thì đã toàn màn hình sẵn.
(function () {
  var TEXT = {
    vi: { title: "Xoay ngang điện thoại", sub: "Bơ cần màn hình nằm ngang để chạy giao bánh." },
    en: { title: "Turn your phone sideways", sub: "Bơ needs a landscape screen to run deliveries." }
  };
  var coarse = window.matchMedia && window.matchMedia("(pointer: coarse)").matches;
  if (!coarse) return;
  var standalone = (window.matchMedia && window.matchMedia("(display-mode: fullscreen), (display-mode: standalone)").matches) ||
    window.navigator.standalone === true;
  var box = null;

  function lang() { var g = window.meoGame || {}; return g.lang === "en" ? "en" : "vi"; }
  function portrait() { return window.innerHeight > window.innerWidth * 1.1; }

  function update() {
    if (!document.body) return;
    if (!portrait()) { if (box) box.style.display = "none"; return; }
    if (!box) {
      box = document.createElement("div");
      box.style.cssText = "position:fixed;inset:0;z-index:9000;display:flex;flex-direction:column;align-items:center;" +
        "justify-content:center;gap:14px;background:#1F2A2A;color:#FFF8EA;font:600 20px system-ui,sans-serif;" +
        "text-align:center;padding:24px";
      box.innerHTML = '<div style="font-size:64px;line-height:1;animation:meoXoay 2s ease-in-out infinite">📱</div>' +
        '<div class="t"></div><div class="s" style="font-weight:400;font-size:15px;opacity:.8;max-width:320px"></div>' +
        "<style>@keyframes meoXoay{0%,30%{transform:rotate(0)}60%,100%{transform:rotate(-90deg)}}</style>";
      document.body.appendChild(box);
    }
    var t = TEXT[lang()];
    box.querySelector(".t").textContent = t.title;
    box.querySelector(".s").textContent = t.sub;
    box.style.display = "flex";
  }

  function fullscreen() {
    var el = document.documentElement;
    if (standalone || document.fullscreenElement || !el.requestFullscreen) return;
    el.requestFullscreen({ navigationUI: "hide" }).then(function () {
      if (screen.orientation && screen.orientation.lock) screen.orientation.lock("landscape").catch(function () {});
    }).catch(function () {});
  }

  window.addEventListener("resize", update);
  window.addEventListener("orientationchange", update);
  document.addEventListener("DOMContentLoaded", update);
  // touchend mới được tính là cú chạm của người chơi để xin toàn màn hình
  document.addEventListener("touchend", fullscreen, { passive: true });
  var oldDoi = window.meoGameDoi;
  window.meoGameDoi = function () { if (oldDoi) oldDoi(); if (box) update(); };
})();
