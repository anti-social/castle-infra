{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-gw.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-pc.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager-pc = {
      url = "github:nix-community/home-manager/release-24.11";
      # Use system packages list where available
      inputs.nixpkgs.follows = "nixpkgs-pc";
    };
    nixpkgs-dell-laptop.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager-dell-laptop = {
      url = "github:nix-community/home-manager/release-24.11";
      # Use system packages list where available
      inputs.nixpkgs.follows = "nixpkgs-dell-laptop";
    };
    nixpkgs-minipc.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-nanopc.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-gw,
    nixpkgs-pc,
    home-manager-pc,
    nixpkgs-dell-laptop,
    home-manager-dell-laptop,
    nixpkgs-minipc,
    nixpkgs-nanopc
  }: let
    nodes = {
      gw = nixpkgs-gw;
      pc = nixpkgs-pc;
      minipc = nixpkgs-minipc;
      dell-laptop = nixpkgs-dell-laptop;
      nanopc = nixpkgs-nanopc;
    };
  in {
    colmena = rec {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };

        nodeNixpkgs = {
          gw = import nodes.gw {
            system = "x86_64-linux";
            overlays = [];
          };
          pc = import nodes.pc {
            system = "x86_64-linux";
            overlays = [];
          };
          minipc = import nodes.minipc {
            system = "x86_64-linux";
            overlays = [];
          };
          dell-laptop = import nodes.dell-laptop {
            system = "x86_64-linux";
            overlays = [];
          };
          nanopc = import nodes.nanopc {
            system = "aarch64-linux";
            overlays = [];
          };
        };

        nodeSpecialArgs = {
          gw = {
            nixpkgs = nodes.gw;
          };
          pc = {
            nixpkgs = nodes.pc;
            home-manager = home-manager-pc;
          };
          minipc.nixpkgs = nodes.minipc;
          dell-laptop = {
            nixpkgs = nodes.dell-laptop;
            home-manager = home-manager-dell-laptop;
          };
          nanopc.nixpkgs = nodes.nanopc;
        };
      };

      gw = import ./gw.nix;
      pc = import ./pc.nix;
      minipc = import ./minipc.nix;
      rpi3 = import ./rpi3.nix;
      dell-laptop = import ./dell-laptop.nix;
      nanopc = import ./nanopc.nix;
    };
  };
}
