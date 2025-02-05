{ stdenv, config, lib, pkgs, ... }:

let
  overlays = {
    "24.05" = [
      (self: super: {
        nwjs = super.nwjs.overrideAttrs rec {
          # version = "0.84.0";
          vesion = "${config.system.nixos.release}";
          src = super.fetchurl {
            url = "https://dl.nwjs.io/v0.84.0/nwjs-v0.84.0-linux-x64.tar.gz";
            hash = "sha256-VIygMzCPTKzLr47bG1DYy/zj0OxsjGcms0G1BkI/TEI=";
          };
        };

        vscodium = super.vscodium.overrideAttrs (old:
          let
            plat = "linux-x64";
            archive_fmt = "tar.gz";
            # inherit (stdenv.hostPlatform) system;
            # plat = {
            #   x86_64-linux = "linux-x64";
            #   x86_64-darwin = "darwin-x64";
            #   aarch64-linux = "linux-arm64";
            #   aarch64-darwin = "darwin-arm64";
            #   armv7l-linux = "linux-armhf";
            # }.${system} or throw "Unsupported system";
            # archive_fmt = if stdenv.isDarwin then "zip" else "tar.gz";
          in rec {
            version = "1.95.3.24321";
            src = pkgs.fetchurl {
              url = "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-${plat}-${version}.${archive_fmt}";
              sha256 = "sha256-vujqWlzNOM6A/xUqqUpWPdwmlqGZqeT2SkBlCe2SiCQ=";
            };
          }
        );

        inav-configurator = super.inav-configurator.overrideAttrs (old:
          rec {
            version = "7.1.2";
            src = pkgs.fetchurl {
              url = "https://github.com/iNavFlight/inav-configurator/releases/download/${version}/INAV-Configurator_linux64_${version}.tar.gz";
              sha256 = "sha256-+RY8nIy7czEIFhO90IWY0qPOuey3595WelQWJvXk+eY=";
            };

            installPhase = ''
              runHook preInstall

              mkdir -p $out/bin \
                       $out/opt/${old.pname}

              cp -r . $out/opt/${old.pname}/
              install -m 444 -D $icon $out/share/icons/hicolor/128x128/apps/${old.pname}.png

              chmod +x $out/opt/inav-configurator/inav-configurator
              makeWrapper ${pkgs.nwjs}/bin/nw $out/bin/${old.pname} --add-flags $out/opt/${old.pname}

              runHook postInstall
            '';
          }
        );

        signal-desktop = super.signal-desktop.overrideAttrs (old:
          rec {
            version = "7.26.0";
            src = pkgs.fetchurl {
              url = "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_${version}_amd64.deb";
              hash = "sha256-FO9tkSW43qx3zzc+qUpCllsHxIKInE3gu1hMgXK7sxQ=";
            };
          }
        );

        ktlint = super.ktlint.overrideAttrs (
          old: rec {
            version = "1.0.0";
            src = pkgs.fetchurl {
              url = "https://github.com/pinterest/ktlint/releases/download/${version}/ktlint";
              sha256 = "Kz9vZ0qUTSW7jSg8NTmUe76GB0eTASkJpV3kt3H3S8w=";
            };
          }
        );

        ghidra = super.ghidra.overrideAttrs (
          old: rec {
            version = "11.1.1";
            versiondate = "20240614";
            rc = pkgs.fetchzip {
              url = "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${version}_build/ghidra_${version}_PUBLIC_${versiondate}.zip";
              hash = "sha256-VwbAqpq6fpPGE+5q+idOxpBAqwXR8oKwHJkJFm1J6ok=";
            };
          }
        );

        turbovnc = super.turbovnc.overrideAttrs (old:
          rec {
            version = "3.1.1";
            src = pkgs.fetchFromGitHub {
              owner = "TurboVNC";
              repo = "turbovnc";
              rev = version;
              sha256 = "sha256-7dft5Wp9LvRy3FM/cZ5F6qUIesu7mzd/Ww8P3xsSvyI=";
            };

            nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
          }
        );
      })
    ];
    "24.11" = [];
  };
in {
  config = {
    nixpkgs.overlays = overlays."${config.system.nixos.release}";
  };
}
