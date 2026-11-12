// Đếm lượt chơi bản web bằng Umami (Vũ Trụ Mark K1, 26/10/2026): không cookie, không gửi tên hay chữ người chơi gõ.
// Dùng chung mã website với markhocai.com (theo-doi.js), gắn thẻ "meo-giao-banh-mi" để lọc riêng trong Umami.
// Lượt xem trang có sẵn địa chỉ đầy đủ, nên link từ markhocai.com có ?utm_source=... là biết người từ đâu sang.
// Game gửi thêm sự kiện qua window.meoDo(ten, du_lieu) (scripts/trang_web.gd: TrangWeb.dem):
//   meo-vao-ngay {ngay, che_do}   bắt đầu một ngày hoặc một màn tập
//   meo-ket-ngay {ngay}            tới bảng kết quả cuối ca / cuối ngày / kết tuần
//   meo-sang-kenh {cho}            bấm nút sang kênh Mark học AI (scripts/ke_mark.gd)
// Phễu người chơi (Vũ Trụ Mark P1, 30/10/2026): mọi sự kiện có thêm "may" (dien-thoai | may-tinh, theo màn cảm ứng).
//   meo-tai-xong {giay}            màn hình chính hiện lần đầu: số giây từ lúc mở trang (gồm tải 65 MB)
//   meo-ket-ngay {ngay, phut}      phut = số phút từ lúc vào ngày đó (trang tự tính)
//   meo-sao-ngay {ngay, sao, sao_max}  bảng kết quả giao bánh
//   meo-bo-ngang {ngay, don, phut} đóng trang khi đang chơi dở một ngày (trang tự gửi lúc pagehide)
//   meo-phim {phim, ket}           phim mở đầu / kết tuần: ket = xem-het | bo-qua
//   meo-luu-anh-tuan {}            bấm "Lưu ảnh tuần" ở màn hết tuần (B1)
// Thử trên máy: thêm ?do=thu vào địa chỉ, sự kiện in ra console và lưu ở window.__do, không gửi đi đâu.
(function () {
  var MA_WEB = "675f1509-0d09-44bb-98de-9d4c51aaadd9"; // Website ID Umami của markhocai.com
  // Tên miền riêng meo.markhocai.com (Sang chọn 27/10/2026) đi qua GitHub Pages; link github.io cũ tự chuyển sang
  var TEN_MIEN = ["sangdaden.github.io", "meo.markhocai.com"];
  var thu = /[?&]do=thu(&|$)/.test(location.search);
  var bat = !!MA_WEB && TEN_MIEN.indexOf(location.hostname) >= 0 && navigator.doNotTrack !== "1";
  // Link gốc là bản ổn định, /moi-nhat/ là bản main (docs/ban-web.md)
  var ban = /\/moi-nhat\//.test(location.pathname) ? "moi-nhat" : "on-dinh";
  var hang = [];
  var may = window.matchMedia && matchMedia("(pointer: coarse)").matches ? "dien-thoai" : "may-tinh";
  var dang = null; // ngày đang chơi: {ngay, don, t}, để tính phút và báo bỏ ngang

  window.meoDon = function (i) {
    if (dang) dang.don = i + 1;
  };

  window.meoDo = function (ten, du_lieu) {
    var d = { ban: ban, lang: (window.meoGame && window.meoGame.lang) || "vi", may: may };
    for (var k in du_lieu || {}) d[k] = String(du_lieu[k]);
    if (ten === "meo-tai-xong") d.giay = String(Math.round(performance.now() / 1000));
    if (ten === "meo-vao-ngay") dang = { ngay: d.ngay, don: 0, t: Date.now() };
    if (ten === "meo-ket-ngay" && dang) {
      d.phut = String(Math.round((Date.now() - dang.t) / 60000));
      dang = null;
    }
    if (thu) {
      (window.__do = window.__do || []).push([ten, d]);
      console.log("[đo]", ten, d);
      return;
    }
    if (!bat) return;
    if (window.umami && typeof window.umami.track === "function") window.umami.track(ten, d);
    else if (hang.length < 50) hang.push([ten, d]);
  };

  // Đóng tab hay rời trang khi đang dở một ngày: báo một lần (Umami gửi bằng fetch keepalive)
  addEventListener("pagehide", function () {
    if (!dang) return;
    var x = dang;
    dang = null;
    window.meoDo("meo-bo-ngang", { ngay: x.ngay, don: x.don, phut: Math.round((Date.now() - x.t) / 60000) });
  });

  if (!bat || thu) return;
  var s = document.createElement("script");
  s.defer = true;
  s.src = "https://cloud.umami.is/script.js";
  s.setAttribute("data-website-id", MA_WEB);
  s.setAttribute("data-domains", TEN_MIEN.join(","));
  s.setAttribute("data-tag", "meo-giao-banh-mi");
  s.setAttribute("data-do-not-track", "true");
  s.onload = function () {
    var h = hang;
    hang = [];
    h.forEach(function (x) { window.umami.track(x[0], x[1]); });
  };
  document.head.appendChild(s);
})();
