# Easy Screen Recorder

A small x86-64 assembly screen recorder for 64-bit Windows 10 (version 1703 or later) and Windows 11. It captures the entire primary display and targets 30 frames per second. Windows Media Foundation encodes H.264 video into an MP4 file. Recordings are silent.

## Record

1. Run **ScreenRecorder.exe**.
2. Click **Start recording…** and choose an MP4 destination.
3. The window minimizes when the 15-second countdown ends.
4. Press **Ctrl+Shift+F10** to finish and save. You can also restore the recorder and click **Stop and save**.

The capture code supports primary display dimensions up to 4096 pixels per side. Actual capture rate depends on the display, system load, and encoder. Windows editions without Media Foundation need the relevant Windows media components.

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
