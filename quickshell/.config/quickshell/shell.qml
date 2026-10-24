import QtQuick
import Quickshell
import Quickshell.Io
import "./modules"

ShellRoot {
    LazyLoader {
        id: wallpaperPickerLoader
        active: false

        WallpaperPicker {}
    }
    IpcHandler {
        target: "wallpaperPicker"

        function toggle(): void {
            wallpaperPickerLoader.active = !wallpaperPickerLoader.active;
        }
    }
}
