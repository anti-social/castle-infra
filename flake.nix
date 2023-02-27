{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
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
      do = import ./do.nix;
    };
  };
}
