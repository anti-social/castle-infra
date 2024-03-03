{
  inputs = {
    nixpkgs-23-05.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
    home-manager-23-11 = {
      url = "github:nix-community/home-manager/release-23.11";
      # Use system packages list where available
      inputs.nixpkgs.follows = "nixpkgs-23-11";
    };
  };

  outputs = { self, nixpkgs-23-05, nixpkgs-23-11, home-manager-23-11 }: let
    nodes = {
      gw = nixpkgs-23-11;
      pc = nixpkgs-23-11;
      minipc = nixpkgs-23-05;
      dell-laptop = nixpkgs-23-11;
      nanopc = nixpkgs-23-11;
    };
  in {
    colmena = rec {
      meta = {
        nixpkgs = import nixpkgs-23-05 {
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
          gw.nixpkgs = nodes.gw;
          pc = {
            nixpkgs = nodes.pc;
            home-manager = home-manager-23-11;
          };
          minipc.nixpkgs = nodes.minipc;
          dell-laptop = {
            nixpkgs = nodes.dell-laptop;
            home-manager = home-manager-23-11;
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
      # dell-laptop = (import ./dell-laptop.nix) { home-manager = home-manager-23-11; };
      # do = import ./do.nix;
    };
  };
}
