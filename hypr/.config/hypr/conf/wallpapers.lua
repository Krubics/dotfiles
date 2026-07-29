-- Wallpaper transition config.
--
-- Edit `transitions` to set the yin transition used when a given wallpaper
-- (matched by filename, e.g. "gojo.mp4") is applied. Anything not listed
-- here falls back to `default_transition`.
--
-- Valid transition names (see `yinctl --list-trans`):
--   zoom  bookflip  bounce  chessboard  mosaic  static  box
--
-- Unlike awww/swww, yin plays video wallpapers natively -- these
-- transitions apply to video picks too, not just images.
--
-- Consumed by scripts/set-wallpaper.lua.

return {
    default_transition = "static",

    transitions = {
        ["gojo-eye.mp4"]       = "zoom",
        ["gojo.mp4"]           = "bookflip",
        ["latios-latias.png"]  = "static",
    },
}
