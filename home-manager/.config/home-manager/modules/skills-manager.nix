# skills-manager.nix
#
# Installs the Skills Manager desktop app (Tauri/Electron-style AppImage
# built upstream by the project's release CI) into the user profile.
#
# We don't build from source — the upstream GitHub release ships a
# self-contained AppImage for x86_64-linux, so we just fetch it, patch
# the interpreter so it runs under Nixpkgs' dynamic linker, and drop it
# on PATH as `skills-manager`.
#
# Update: bump `version`, then re-fetch the new AppImage hash with:
#   nix-prefetch-url --type sha256 <url> | xargs nix hash to-sri --type sha256

{ pkgs, ... }:

let
  version = "1.28.3";

  appimage = pkgs.fetchurl {
    url = "https://github.com/xingkongliang/skills-manager/releases/download/v${version}/skills-manager_${version}_amd64.AppImage";
    hash = "sha256-AJOHVaK0SDwF7MkMm54Tejlj4g2S+L8NmPiMAom0JyU=";
  };
in
{
  home.packages = [
    (pkgs.runCommand "skills-manager-${version}"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta = {
          description = "Manage, sync, and organize AI agent skills across coding tools";
          homepage = "https://github.com/xingkongliang/skills-manager";
          license = pkgs.lib.licenses.mit;
          mainProgram = "skills-manager";
          platforms = [ "x86_64-linux" ];
        };
      }
      ''
        mkdir -p $out/bin
        install -Dm755 ${appimage} $out/bin/skills-manager
      '')
  ];
}
