{
  description = "Home Manager configuration of Jane Doe";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    nixpkgs.url = "github:NixOS/nixpkgs/7076110064c09f0b3942f609f2134c1358ef2e50";
    home-manager = {
      url = "github:nix-community/home-manager/release-22.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-doom-emacs.url = "github:nix-community/nix-doom-emacs";
  };

  outputs = { self, nixpkgs, home-manager, nix-doom-emacs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations.alexk = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          ./alexk.nix
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };

      #nixosConfigurations.minipc = nixpkgs.lib.nixosSystem {
      #  system = "x86_64-linux";
      #  modules = [
      #    home-manager.nixosModules.home-manager
      #    {
      #      home-manager.users.alexk = { ... }: {
      #        imports = [ nix-doom-emacs.hmModule ];
      #        programs.doom-emacs = {
      #          enable = true;
      #          doomPrivateDir = ./doom.d; # Directory containing your config.el, init.el
      #                                      # and packages.el files
      #        };
      #      };  
      #    }
      #  ];
      #};
    };
}
