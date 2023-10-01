{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/7076110064c09f0b3942f609f2134c1358ef2e50";
    nixpkgs-23-05.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-23-05-new.url = "github:NixOS/nixpkgs/nixos-23.05";
  };

  outputs = { nixpkgs, nixpkgs-23-05, nixpkgs-23-05-new, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };

      };

      meta.nodeNixpkgs.gw = import nixpkgs-23-05 {
        system = "x86_64-linux";
        overlays = [];
      };
      meta.nodeNixpkgs.pc = import nixpkgs-23-05-new {
        system = "x86_64-linux";
        overlays = [];
      };
      meta.nodeNixpkgs.minipc = import nixpkgs-23-05 {
        system = "x86_64-linux";
        overlays = [];
      };
      meta.nodeNixpkgs.oldpc = import nixpkgs-23-05 {
        system = "x86_64-linux";
        overlays = [];
      };
      meta.nodeNixpkgs.dell-laptop = import nixpkgs-23-05 {
        system = "x86_64-linux";
        overlays = [];
      };

      gw = import ./gw.nix;
      pc = import ./pc.nix;
      oldpc = import ./oldpc.nix;
      minipc = import ./minipc.nix;
      rpi3 = import ./rpi3.nix;
      dell-laptop = import ./dell-laptop.nix;
      # do = import ./do.nix;
    };
  };
}
