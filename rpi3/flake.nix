{
  description = "Build raspberry pi image";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  outputs = { self, nixpkgs }: rec {
    nixosConfigurations.rpi = nixpkgs.lib.nixosSystem {
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-raspberrypi.nix"
        {
          nixpkgs.config.allowUnsupportedSystem = true;
          nixpkgs.hostPlatform.system = "aarch64-linux";
          nixpkgs.buildPlatform.system = "x86_64-linux"; #If you build on x86 other wise changes this.
          # ... extra configs as above
        }
      ];
    };
    images.rpi = nixosConfigurations.rpi.config.system.build.sdImage;
  };
}
