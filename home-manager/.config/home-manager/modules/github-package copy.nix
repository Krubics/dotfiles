# github-package.nix
#
# Template Home Manager module: fetch a GitHub repo, build it into a
# package, and install it into your user profile.
#
# USAGE
#   1. Save this file somewhere your home-manager config can see it,
#      e.g. ~/.config/home-manager/modules/github-package.nix
#   2. Import it from your home.nix:
#
#        { ... }: {
#          imports = [ ./modules/github-package.nix ];
#        }
#
#   3. Fill in the `src` fetcher below with the real owner/repo/rev/hash,
#      and pick the `mkDerivation`/`buildXPackage` block that matches
#      how the project is actually built (Go, Rust, npm, or "just copy
#      a script/binary"). Delete the ones you don't use.
#
# This file is a *template*: the parts marked "<-- FILL IN -->" are
# what you edit per-project. Everything else is plumbing you can leave
# alone while you're still learning.

{ config, lib, pkgs, ... }:

let
  # ---------------------------------------------------------------
  # 1. Fetch the repo source
  # ---------------------------------------------------------------
  # pkgs.fetchFromGitHub is the standard way to grab a specific commit
  # or tag from GitHub reproducibly. Nix needs the exact content hash
  # up front (that's what makes builds pure/reproducible) — you get
  # this the first time by setting hash = lib.fakeHash, letting the
  # build fail, and copying the "got: sha256-..." value it reports.
  src = pkgs.fetchFromGitHub {
    owner = "OWNER";        # <-- FILL IN --  e.g. "kunchenguid"
    repo  = "REPO_NAME";    # <-- FILL IN --  e.g. "gnhf"
    rev   = "v1.0.0";       # <-- FILL IN --  a tag, branch, or commit sha
    hash  = lib.fakeHash;   # <-- FILL IN --  replace after first build attempt
    # Older nixpkgs channels use `sha256 = lib.fakeSha256;` instead of `hash`.
  };

  # ---------------------------------------------------------------
  # 2. Turn the source into a package (pick ONE block below)
  # ---------------------------------------------------------------

  # --- Option A: generic build via a Makefile / build.sh -----------
  myPackage = pkgs.stdenv.mkDerivation {
    pname = "REPO_NAME";     # <-- FILL IN
    version = "1.0.0";       # <-- FILL IN
    inherit src;

    # Tools needed only at build time (compilers, codegen, etc.)
    nativeBuildInputs = [ pkgs.makeWrapper ];

    # Libraries the built binary links/runs against
    buildInputs = [ ];

    # If the repo has its own `make` / `make install`, this is often
    # enough. Otherwise replace with the project's real build steps.
    installPhase = ''
      mkdir -p $out/bin
      cp -r ./* $out/bin/   # <-- FILL IN -- copy the actual built artifact(s)
    '';
  };

  # --- Option B: Node/npm project (uncomment to use instead of A) --
  # myPackage = pkgs.buildNpmPackage {
  #   pname = "REPO_NAME";
  #   version = "1.0.0";
  #   inherit src;
  #   npmDepsHash = lib.fakeHash; # same "run once, copy the real hash" trick
  #   # dontNpmBuild = true; # if there's no build step, just deps + run
  # };

  # --- Option C: Go project (uncomment to use instead of A) --------
  # myPackage = pkgs.buildGoModule {
  #   pname = "REPO_NAME";
  #   version = "1.0.0";
  #   inherit src;
  #   vendorHash = lib.fakeHash;
  # };

  # --- Option D: Rust/Cargo project (uncomment to use instead of A) -
  # myPackage = pkgs.rustPlatform.buildRustPackage {
  #   pname = "REPO_NAME";
  #   version = "1.0.0";
  #   inherit src;
  #   cargoHash = lib.fakeHash;
  # };

  # --- Option E: it's just a prebuilt script/binary in the repo ----
  # (no real "build" step — just make it executable and wrap it)
  # myPackage = pkgs.runCommand "REPO_NAME" { } ''
  #   mkdir -p $out/bin
  #   install -Dm755 ${src}/bin/some-script $out/bin/REPO_NAME
  # '';

in
myPackage