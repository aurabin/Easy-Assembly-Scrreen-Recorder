# Easy Screen Recorder

[![Download for Windows (ZIP)](https://img.shields.io/badge/Download_for_Windows-ZIP-0078D4?style=for-the-badge)](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/Easy_Screen_Recorder_for_Windows.zip)

A small x86-64 assembly screen recorder for 64-bit Windows 10 (version 1703 or later) and Windows 11. It captures the entire primary display and targets 30 frames per second. Windows Media Foundation encodes H.264 video into an MP4 file. Recordings are silent.

## Downloads

| Platform | Download |
|---|---|
| Windows x64 | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_Windows-x64.zip) |
| AmigaOS 3.9 · 68040 | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AmigaOS39-040.zip) |
| AmigaOS 3.9 · 68060 | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AmigaOS39-060.zip) |
| Apollo Vampire · 68080 | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_Apollo-Vampire-080.zip) |
| AROS/m68k · 68080 | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-m68k-080.zip) |
| AROS x86-64 · C | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-x86_64-c.zip) |
| AROS x86-64 · C++ | [Download ZIP](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-x86_64-cpp.zip) |

Each ZIP includes the executable for that platform, source code, and documentation. The Amiga and AROS packages include Shell usage and build instructions.

## Record (Windows)

Choose **English**, **Deutsch**, or **Português** in the drop-down. The app starts in the Windows display language when it is supported and uses English otherwise.

1. Run **ScreenRecorder.exe**.
2. Click **Record** and choose an MP4 destination.
3. The window minimizes when the 15-second countdown ends.
4. Press **Ctrl+Shift+F10** to finish and save. You can also restore the recorder and click **Stop**.

The capture code supports primary display dimensions up to 4096 pixels per side. Actual capture rate depends on the display, system load, and encoder. Windows editions without Media Foundation need the relevant Windows media components.

When the recorder window has focus, **Enter** starts recording and **Space** stops it. Restore the window to use Space if it is minimized.

MP4 recording stops automatically at 85% of the estimated time available on the selected drive. The estimate uses the configured video bitrate and reserves space for file finalization.

## Take a screenshot

While the recorder is idle, click **Screenshot and save…**. The app hides its window, captures the primary display, and opens a save dialog for BMP, PNG, or JPEG.

## Support

Recording and saving are free. You can support the project on the developer’s [bunq.me page](https://bunq.me/JMLealRuivo). Any contribution is optional, and available payment amounts depend on bunq and the payment method.

## Build

Use GNU Binutils on x86-64 Linux or WSL. The linker must support the `i386pep` emulation. Run these commands from the project directory.

```sh
as --64 -o screen_mp4.o screen_mp4.s
ld -mi386pep --image-base 0x400000 --subsystem windows --nxcompat \
  --dynamicbase --no-insert-timestamp -e entry \
  -o ScreenRecorder.exe screen_mp4.o
```

The recorder uses Win32 GDI for capture and Media Foundation for encoding. The executable's structure, assembly frame conversion, and sample timestamps were checked on Linux. Live capture and MP4 finalization still need a Windows test.

The project source is available under the [MIT License](LICENSE).
