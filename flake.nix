{
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:NixOS/nixpkgs/7076110064c09f0b3942f609f2134c1358ef2e50";
  };

  outputs = { nixpkgs, ... }: {
    colmena = {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [];
        };

        # nodeNixpkgs = {
        #   rpi3 = {
        #     url = "github:NixOS/nixpkgs/nixos-22.11.2500.8866a38d4d2";
        #   };
        # };
      };

      gw = import ./gw.nix;
      minipc = import ./minipc.nix;
      rpi3 = import ./rpi3.nix;
      dell-laptop = import ./dell-laptop.nix;
      # do = import ./do.nix;
    };
  };
}
