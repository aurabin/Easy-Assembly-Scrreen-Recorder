# Easy Screen Recorder – einfache deutsche Anleitung

Mit diesem Programm kannst du den Bildschirm aufnehmen. Die Windows-Version erstellt ein **MP4-Video ohne Ton**. Sie ist für Windows 10 ab Version 1703 und Windows 11 mit 64 Bit gedacht.

## Downloads

| System | Datei |
|---|---|
| Windows 64 Bit | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_Windows-x64.zip) |
| AmigaOS 3.9 mit 68040 | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AmigaOS39-040.zip) |
| AmigaOS 3.9 mit 68060 | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AmigaOS39-060.zip) |
| Apollo Vampire mit 68080 | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_Apollo-Vampire-080.zip) |
| AROS/m68k mit 68080 | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-m68k-080.zip) |
| AROS x86-64, C-Version | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-x86_64-c.zip) |
| AROS x86-64, C++-Version | [ZIP herunterladen](https://github.com/aurabin/Easy-Assembly-Scrreen-Recorder/raw/refs/heads/main/downloads/Easy_Screen_Recorder_AROS-x86_64-cpp.zip) |

Die ZIP-Pakete sollen jeweils das passende Programm, den Quellcode und eine Anleitung enthalten. Ob jedes Paket auf echter Hardware funktioniert, muss getrennt getestet werden.

## Windows: Bildschirm aufnehmen

1. Entpacke die ZIP-Datei und öffne `ScreenRecorder.exe`.
2. Klicke auf **Record** und wähle einen Speicherort für die MP4-Datei.
3. Nach 15 Sekunden wird das Programmfenster verkleinert.
4. Mit **Strg + Umschalt + F10** beendest und speicherst du die Aufnahme. Du kannst auch das Fenster wieder öffnen und auf **Stop** klicken.

Wenn das Programmfenster aktiv ist, startet **Enter** die Aufnahme. **Leertaste** stoppt sie. Wenn das Fenster verkleinert ist, musst du es für die Leertaste zuerst wieder öffnen.

Du kannst die Sprache **Deutsch**, **Englisch** oder **Portugiesisch** auswählen. Wenn die Windows-Sprache nicht unterstützt wird, verwendet das Programm Englisch.

## Bildschirmfoto

Wenn gerade keine Aufnahme läuft, klicke auf **Screenshot and save…**. Du kannst ein Bild als BMP, PNG oder JPEG speichern.

## Technische Grenzen

- Die Aufnahme soll mit bis zu 30 Bildern pro Sekunde laufen. Die tatsächliche Geschwindigkeit hängt vom Computer ab.
- Die Hauptanzeige darf höchstens 4096 Pixel breit und 4096 Pixel hoch sein.
- Das Programm verwendet Windows Media Foundation für H.264 und MP4. Fehlen diese Windows-Medienfunktionen, kann die Aufnahme scheitern.
- Die Aufnahme stoppt automatisch bei 85 Prozent der geschätzten möglichen Aufnahmezeit. So bleibt Platz, um die Datei fertigzustellen.
- Die Windows-Aufnahme enthält **keinen Ton**.

## Quellcode selbst bauen

Du brauchst GNU Binutils auf einem 64-Bit-Linux-System oder unter WSL. Der Linker muss `i386pep` unterstützen. Im Projektordner:

```sh
as --64 -o screen_mp4.o screen_mp4.s
ld -mi386pep --image-base 0x400000 --subsystem windows --nxcompat \
  --dynamicbase --no-insert-timestamp -e entry \
  -o ScreenRecorder.exe screen_mp4.o
```

Das Programm nutzt Win32 GDI für die Bildschirmaufnahme und Windows Media Foundation für das MP4-Video. Der Aufbau der EXE-Datei, die Bildumwandlung und die Zeitangaben wurden unter Linux geprüft. **Ein vollständiger Windows-Test der Aufnahme und des Speicherns steht noch aus.**

## Unterstützung und Lizenz

Die Aufnahme und das Speichern sind kostenlos. Freiwillige Unterstützung ist über [bunq.me](https://bunq.me/JMLealRuivo) möglich. Die Höhe möglicher Zahlungen hängt vom Zahlungsdienst ab.

Der Quellcode steht unter der [MIT-Lizenz](LICENSE).
