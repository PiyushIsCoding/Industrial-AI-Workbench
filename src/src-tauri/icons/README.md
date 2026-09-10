Icons go here. Tauri generates every required size from one square PNG:

    cargo tauri icon path/to/icon.png

That writes 32x32.png, 128x128.png, 128x128@2x.png, icon.icns and icon.ico
into this directory. The build will not bundle without them.
