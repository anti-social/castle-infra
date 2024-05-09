{ pkgs }: [
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
          version = "3.0.91";
          src = pkgs.fetchFromGitHub {
            owner = "TurboVNC";
            repo = "turbovnc";
            rev = version;
            sha256 = "sha256-akkkbDb5ZHTG5GEEeDm1ns60GedQ+DnFXgVMZumRQHc=";
          };

          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkg-config ];
        }
      );
    })
]
