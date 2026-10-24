{ pkgs, inputs, ... }:

let
  no-mistakes = pkgs.callPackage ./modules/no-mistakes.nix { };
  lyrics-tool = pkgs.callPackage ./modules/lyrics-tool.nix { };
  hyprsession = pkgs.callPackage ./modules/hyprsession.nix { };
  yin = pkgs.callPackage ./modules/yin.nix {
    src = inputs.yin-src;
  };
in
{
  imports = [ ./modules/skills-manager.nix ];
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "krubics";
  home.homeDirectory = "/home/krubics";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "26.05"; # Please read the comment before changing.

  nixpkgs.config.allowUnfree = true;

  targets.genericLinux.nixGL = {
    packages = nixgl.packages;
    defaultWrapper = "mesa";
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  # home.nix

  targets.genericLinux.enable = true;

  programs.gh.enable = true;

  home.packages = [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    # pkgs.hello

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')

    # Desktop Tools
    pkgs.hyprland
    pkgs.quickshell
    pkgs.waybar
    pkgs.hyprshutdown
    hyprsession
    inputs.matugen.packages.${pkgs.system}.default
    inputs.hyprmod.packages.${pkgs.system}.default
    yin
    pkgs.xremap

    # Build Tools
    pkgs.meson
    pkgs.ninja

    # Terminal    
    ## System Tools
    pkgs.btop

    ## Shell
    pkgs.zsh
    pkgs.oh-my-zsh

    ## Zsh Plugins
    pkgs.starship
    pkgs.zoxide
    pkgs.eza
    pkgs.zsh-syntax-highlighting

    ## Tools
    pkgs.p7zip
    pkgs.neovim
    pkgs.stow
    pkgs.trash-cli
    ## TUIs
    pkgs.git
    pkgs.herdr
    pkgs.yazi

    # Applications
    inputs.zen-browser.packages.${pkgs.system}.default
    pkgs.obsidian
    pkgs.ghostty
    pkgs.gtk4-layer-shell
    pkgs.cava
    no-mistakes
    lyrics-tool
    inputs.iris.packages.${pkgs.system}.iris
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/krubics/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
