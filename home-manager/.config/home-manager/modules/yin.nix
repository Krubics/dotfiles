{
  stdenv,
  meson,
  ninja,
  pkg-config,
  python3,
  wayland,
  wayland-scanner,
  wayland-protocols,
  ffmpeg,
  libva,
  libglvnd,
  src,
}:

stdenv.mkDerivation {
  pname = "yin";
  version = "git";

  inherit src;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    python3
    wayland-scanner
  ];

  buildInputs = [
    wayland
    wayland-protocols
    ffmpeg
    libva
    libglvnd
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp yin $out/bin/yin
    cp yinctl $out/bin/yinctl
  '';
}
