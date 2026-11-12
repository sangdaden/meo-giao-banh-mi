# App Android (G3)

App riêng dùng chung code với bản web: nút cảm ứng `scripts/cam_ung.gd`, renderer Compatibility như web
(`rendering_method.mobile`), `GiuFps` tự hạ chất lượng, nút Quay lại của Android mở menu tạm dừng.

## Dựng APK

1. Godot 4.3 + export template Android (`android_release.apk`, `android_debug.apk` trong
   `Godot_v4.3-stable_export_templates.tpz`).
2. JDK 17+ và `apksigner` (Android SDK build-tools; trên Ubuntu `apt install apksigner zipalign` rồi trỏ
   `build-tools/34.0.0/apksigner` về `/usr/bin/apksigner`). Editor settings: `export/android/android_sdk_path`,
   `java_sdk_path`, `debug_keystore`.
3. Khóa ký: **không ở trong repo**. File `meo-giao-banh-mi.keystore` và mật khẩu nằm ở thư mục dùng chung
   `/mnt/project-files/app-android/khoa-ky/` (Sang giữ thêm một bản). Mất khóa là không cập nhật được app đã phát hành.
4. Xuất:

```
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=<keystore> GODOT_ANDROID_KEYSTORE_RELEASE_USER=meo \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<mật khẩu> \
godot --headless --path . --export-release "Android" build/MeoGiaoBanhMi.apk
```

Mỗi bản mới tăng `version/code` (và `version/name`) của preset Android trong `export_presets.cfg`.
File APK/AAB không đưa lên GitHub (luật G1, G7): để ở thư mục dùng chung hoặc Google Drive.
