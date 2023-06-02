{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:NixOS/nixpkgs/7076110064c09f0b3942f609f2134c1358ef2e50";
    nixpkgs-23-05.url = "github:NixOS/nixpkgs/551a52bfdd02e7b75be5faf9b42f864112d88654";
  };

  outputs = { nixpkgs, nixpkgs-23-05, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };

      };

      # meta.nodeNixpkgs.pc = ./nixpkgs;
      meta.nodeNixpkgs.pc = import nixpkgs-23-05 {
        system = "x86_64-linux"; # Set your desired system here
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
