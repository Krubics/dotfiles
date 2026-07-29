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
