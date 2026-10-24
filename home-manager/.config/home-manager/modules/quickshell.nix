{ pkgs, ... }:
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      # Mismatched system dependencies will lead to crashes
      inputs.nixpkgs.follows = "nixpkgs";

    };
  };
  
}