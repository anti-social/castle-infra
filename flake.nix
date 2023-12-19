{
  inputs = {
    nixpkgs-23-05.url = "github:NixOS/nixpkgs/nixos-23.05";
    nixpkgs-23-11.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { nixpkgs-23-05, nixpkgs-23-11, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs-23-05 {
          system = "x86_64-linux";
          overlays = [];
        };

        nodeNixpkgs = {
          gw = import nixpkgs-23-05 {
            system = "x86_64-linux";
            overlays = [];
          };
          pc = import nixpkgs-23-11 {
            system = "x86_64-linux";
            overlays = [];
          };
          minipc = import nixpkgs-23-05 {
            system = "x86_64-linux";
            overlays = [];
          };
          oldpc = import nixpkgs-23-05 {
            system = "x86_64-linux";
            overlays = [];
          };
          dell-laptop = import nixpkgs-23-11 {
            system = "x86_64-linux";
            overlays = [];
          };
        };
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
