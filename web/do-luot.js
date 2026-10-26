// Đếm lượt chơi bản web bằng Umami (Vũ Trụ Mark K1, 26/10/2026): không cookie, không gửi tên hay chữ người chơi gõ.
// Dùng chung mã website với markhocai.com (theo-doi.js), gắn thẻ "meo-giao-banh-mi" để lọc riêng trong Umami.
// Lượt xem trang có sẵn địa chỉ đầy đủ, nên link từ markhocai.com có ?utm_source=... là biết người từ đâu sang.
// Game gửi thêm sự kiện qua window.meoDo(ten, du_lieu) (scripts/trang_web.gd: TrangWeb.dem):
//   meo-vao-ngay {ngay, che_do}   bắt đầu một ngày hoặc một màn tập
//   meo-ket-ngay {ngay}            tới bảng kết quả cuối ca / cuối ngày / kết tuần
//   meo-sang-kenh {cho}            bấm nút sang kênh Mark học AI (scripts/ke_mark.gd)
// Thử trên máy: thêm ?do=thu vào địa chỉ, sự kiện in ra console và lưu ở window.__do, không gửi đi đâu.
(function () {
  var MA_WEB = "675f1509-0d09-44bb-98de-9d4c51aaadd9"; // Website ID Umami của markhocai.com
  var TEN_MIEN = "sangdaden.github.io";
  var thu = /[?&]do=thu(&|$)/.test(location.search);
  var bat = !!MA_WEB && location.hostname === TEN_MIEN && navigator.doNotTrack !== "1";
  // Link gốc là bản ổn định, /moi-nhat/ là bản main (docs/ban-web.md)
  var ban = /\/moi-nhat\//.test(location.pathname) ? "moi-nhat" : "on-dinh";
  var hang = [];

  window.meoDo = function (ten, du_lieu) {
    var d = { ban: ban, lang: (window.meoGame && window.meoGame.lang) || "vi" };
    for (var k in du_lieu || {}) d[k] = String(du_lieu[k]);
    if (thu) {
      (window.__do = window.__do || []).push([ten, d]);
      console.log("[đo]", ten, d);
      return;
    }
    if (!bat) return;
    if (window.umami && typeof window.umami.track === "function") window.umami.track(ten, d);
    else if (hang.length < 50) hang.push([ten, d]);
  };

  if (!bat || thu) return;
  var s = document.createElement("script");
  s.defer = true;
  s.src = "https://cloud.umami.is/script.js";
  s.setAttribute("data-website-id", MA_WEB);
  s.setAttribute("data-domains", TEN_MIEN);
  s.setAttribute("data-tag", "meo-giao-banh-mi");
  s.setAttribute("data-do-not-track", "true");
  s.onload = function () {
    var h = hang;
    hang = [];
    h.forEach(function (x) { window.umami.track(x[0], x[1]); });
  };
  document.head.appendChild(s);
})();
