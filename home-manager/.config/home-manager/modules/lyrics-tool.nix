# lyrics-tool — terminal lyrics visualizer + LRC/WLRC toolkit.
# Pure-Python setuptools app (pyproject.toml, src/ layout).
# Wrapped so `playerctl` and `ffprobe` are on PATH at runtime.
#
# Ref: https://github.com/hamza-abdelmoumene/lyrics-tool
{
  lib,
  python3Packages,
  playerctl,
  ffmpeg,
  fetchFromGitHub,
}:

python3Packages.buildPythonApplication {
  pname = "lyrics-tool";
  version = "0.2.2";
  format = "pyproject"; # has [build-system] = setuptools>=61

  src = fetchFromGitHub {
    owner = "hamza-abdelmoumene";
    repo = "lyrics-tool";
    rev = "v0.2.2";
    hash = "sha256-MAGlCtVqBU4M32Xv5EuPtMyQBH7mIXO2gr0ho31pp1E=";
  };

  postPatch = ''
    substituteInPlace src/lyrics_tool/visualizer_main.py \
      --replace-fail \
      $'    return idx\n\n\n# Tracks' \
      $'    return idx\n\n\ndef _stabilize_line_index(candidate: int, previous: Optional[int], allow_backward: bool) -> int:\n    """Keep normal clock corrections from replaying a prior lyric line.\n\n    Position samples can arrive slightly behind the free-running clock. While\n    playing normally, that must not move the display back across a phrase\n    boundary. Explicit re-anchors remain free to select an earlier line.\n    """\n    if not allow_backward and previous is not None and candidate < previous:\n        return previous\n    return candidate\n\n\n# Tracks'

    substituteInPlace src/lyrics_tool/visualizer_main.py \
      --replace-fail \
      $'                # Big events (track change / pause / seek) flagged by the monitor\n                # → jump the clock straight onto a fresh sample.\n                if sync_data.should_resync:\n                    sync_data.should_resync = False' \
      $'                # Big events (track change / pause / seek) flagged by the monitor\n                # → jump the clock straight onto a fresh sample.\n                allow_backward = False\n                if sync_data.should_resync:\n                    sync_data.should_resync = False\n                    allow_backward = True'

    substituteInPlace src/lyrics_tool/visualizer_main.py \
      --replace-fail \
      '                        clock.correct(snap.position, snap.sampled_at)' \
      $'                        allow_backward = (\n                            clock.correct(snap.position, snap.sampled_at))'

    substituteInPlace src/lyrics_tool/visualizer_main.py \
      --replace-fail \
      $'                # Pick the line for now — recomputed each frame so a gentle\n                # correction that nudges us back across a boundary is honoured,\n                # not just forward motion.\n                idx = _index_for(lines, line_pos)' \
      $'                # Pick the line for now. Normal clock corrections can advance\n                # a phrase immediately, but cannot replay a previous phrase.\n                idx = _stabilize_line_index(\n                    _index_for(lines, line_pos), last_idx, allow_backward)'
  '';

  # PEP 517 build backend — the sandbox can't fetch build-system.requires,
  # so provide setuptools explicitly.
  nativeBuildInputs = [ python3Packages.setuptools ];

  # Runtime Python deps (from [project].dependencies).
  propagatedBuildInputs = with python3Packages; [
    syncedlyrics
    mutagen
    pyyaml
    pillow
  ];

  # The tool shells out to `playerctl` (live MPRIS sync) and `ffprobe`
  # (audio durations). Wrap the entry-point scripts so they find them
  # without polluting the user's PATH.
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      playerctl
      ffmpeg
    ])
  ];

  # Optional: per-word onset detection (real timing vs. even spacing).
  # Uncomment to pull in librosa + numpy (~heavy):
  # propagatedBuildInputs = with python3Packages; [
  #   syncedlyrics mutagen pyyaml pillow librosa numpy
  # ];

  meta = {
    description = "Terminal lyrics visualizer and LRC/WLRC processing suite";
    homepage = "https://github.com/hamza-abdelmoumene/lyrics-tool";
    license = lib.licenses.mit;
    mainProgram = "lyricsooo";
  };
}
