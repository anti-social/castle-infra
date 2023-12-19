{ config, lib, pkgs, specialArgs, ... }:

{
  config = {
    environment.etc.nixpkgs.source = specialArgs.nixpkgs;
    nix.nixPath = ["nixpkgs=/etc/nixpkgs"];
  };
}
