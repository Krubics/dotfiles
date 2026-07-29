# hyprsession — session persistence for Hyprland.
# Periodically snapshots running clients (via `hyprctl clients`) into a
# Hyprland-config formatted file; sourcing/running it again on the next
# Hyprland start restores the workspace layout and running apps.
#
# Ref: https://github.com/joshurtree/hyprsession
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "hyprsession";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "joshurtree";
    repo = "hyprsession";
    rev = "73df7cb60ae512a97875c290422a6707b123f9f4";
    hash = "sha256-pO6eaYOt+GYaDWVUgVAjvxUJrfP7NHsVue0PaPz6vNA=";
  };

  # Cargo.lock ships in the repo and pins only crates.io dependencies, so
  # reuse it verbatim instead of re-resolving with cargoHash.
  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = {
    description = "Session persistence (save/restore running clients) for Hyprland";
    homepage = "https://github.com/joshurtree/hyprsession";
    license = lib.licenses.gpl3Only;
    mainProgram = "hyprsession";
  };
}
