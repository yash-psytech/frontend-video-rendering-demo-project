# Real-Device Video Rendering: Issues & Fixes

When rendering videos on client-side devices (Android/iOS) using FFmpeg, several real-world challenges arise that aren't visible in high-spec development environments.

## 1. Performance & Hardware Constraints

### The Issue: CPU Thermal Throttling
FFmpeg is extremely CPU-hungry. During long exports (2+ minutes), the device generates significant heat.
*   **Result**: The mobile OS automatically slows down the CPU (throttling) to cool it, causing the export to slow down drastically or the app to become laggy.
*   **Fix**: 
    1.  **Use Hardware Acceleration**: Use `-codec:v h264_mediacodec` (Android) or `-codec:v h264_videotoolbox` (iOS) if supported by the package.
    2.  **Preset Optimization**: Use `-preset superfast` or `-preset ultrafast`. It increases file size slightly but significantly reduces CPU time.

### The Issue: Memory (RAM) Overhead
Processing 4K overlays on a device with 3GB RAM can cause `Out Of Memory (OOM)` crashes.
*   **Fix**: 
    1.  **Scale Inputs Early**: Scale your image overlays to the exact required size *before* passing them to the complex filter.
    2.  **Downscale for Export**: If the source is 4K but the user only needs "Social Media" quality, downscale to 1080p during export using `scale=1080:-1`.

## 2. Platform & Compatibility Issues

### The Issue: Codec Licensing (GPL/LGPL)
Certain codecs (like `libx264`) require GPL licensing. Some app stores have strict policies or the binary size grows too large.
*   **Fix**: Use the `min` or `lts` versions of FFmpegKit which use system-native encoders when possible, reducing the APK size from 80MB to ~15MB.

### The Issue: Android Scoped Storage
Android 11+ restricts file access. FFmpeg might fail to read the video if it's in a restricted folder.
*   **Fix**: Always copy input files to the `ApplicationDocumentsDirectory` or a temporary cache folder before processing. FFmpeg has the best performance when reading from local app storage.

## 3. App Lifecycle & Backgrounding

### The Issue: OS Task Killing
If a user switches to WhatsApp/Instagram while the video is 50% rendered, Android/iOS will likely kill the app to save battery.
*   **Fix**: 
    1.  **Foreground Service (Android)**: Use a package like `flutter_foreground_task` to keep the process alive with a persistent notification.
    2.  **Background Tasks (iOS)**: Use `BGTaskScheduler`, though it's limited. The best UX is to warn the user: "Keep app open during export."

## 4. UI/UX Synchronization

### The Issue: Preview vs. Export Drift
A "1.5s fade" in Flutter's `Curves.easeOut` might look different than a linear FFmpeg fade.
*   **Fix**: 
    1.  **Match Math**: Use FFmpeg's `lerp` or `eval` functions to replicate standard easing curves (EaseIn, EaseOut) instead of simple linear fades.
    2.  **Frame Rate Locking**: Always specify `-r 30` in export to ensure the timing of overlays matches the preview exactly.

## 5. Storage Space (The `INSTALL_FAILED` Error)

### The Issue: Huge Binaries
Standard FFmpeg builds include hundreds of unused codecs, leading to huge APKs that fail to install on mid-range devices.
*   **Fix**: 
    1.  **ABIs Filtering**: In `build.gradle`, filter for only `arm64-v8a` and `armeabi-v7a` to cut binary size in half.
    2.  **Minimal Builds**: Use a "Main" or "Min" build variant of FFmpegKit that only includes the necessary encoders (H264, AAC).

---

## Production Checklist for "Taza"
- [ ] Implement **Background Service** for exports.
- [ ] Use **Resolution-Aware Scaling** (Already implemented in our code).
- [ ] Use **Fast Presets** (`-preset fast`).
- [ ] Implement **Low-Memory mode** for devices with <4GB RAM.
- [ ] Add a **Wake Lock** to prevent the screen from turning off during render.
