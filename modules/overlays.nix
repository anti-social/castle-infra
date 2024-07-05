{ stdenv, config, lib, pkgs, ... }:

{
  config = {
    nixpkgs.overlays = [
      (self: super: {
        betaflight-configurator = super.betaflight-configurator.overrideAttrs (old:
          rec {
            version = "10.10.0";
            src = pkgs.fetchurl {
              url = "https://github.com/betaflight/${old.pname}/releases/download/${version}/${old.pname}_${version}_linux64-portable.zip";
              sha256 = "sha256-UB5Vr5wyCUZbOaQNckJQ1tAXwh8VSLNI1IgTiJzxV08=";
            };
          }
        );

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
            version = "1.88.1.24104";
            src = pkgs.fetchurl {
              url = "https://github.com/VSCodium/vscodium/releases/download/${version}/VSCodium-${plat}-${version}.${archive_fmt}";
              sha256 = "sha256-dOVCh7ksdaYlinYImrSCxybNyUnSJfc5x6JFrURYb9g=";
            };
          }
        );

        inav-configurator = super.inav-configurator.overrideAttrs (old:
          rec {
            version = "7.0.1";
            src = pkgs.fetchurl {
              url = "https://github.com/iNavFlight/inav-configurator/releases/download/${version}/INAV-Configurator_linux64_${version}.tar.gz";
              sha256 = "sha256-ryd2ojkfoHS62+8Br1DMMFCu0K5pBRCVn8rcAbIF+og=";
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
            version = "7.14.0";
            src = pkgs.fetchurl {
              url = "https://updates.signal.org/desktop/apt/pool/s/signal-desktop/signal-desktop_${version}_amd64.deb";
              hash = "sha256-nRvGpAKRIPgXStrVu4qSMoW01SACV/wW/c05lLncCW8=";
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
  };
}
