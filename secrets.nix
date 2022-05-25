{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.secrets;
in {
  options.services.secrets = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        src = mkOption {
          type = types.str;
          description = "Path to a local encrypted file";
        };

        dest = mkOption {
          type = types.str;
          description = "Path to a destination decrypted file";
        };
        beforeService = mkOption {
          type = types.str;
          description = "Decrypt secret before starting a service";
        };
      };
    });
    default = {};
    description = "Secrets";
  };

  config = let
    secret_file = name: pkgs.writeText name (builtins.readFile (./. + builtins.toPath "/${name}"));
    decode_secret = pkgs.writeShellScript "decode-secret.sh" ''
      set -eu

      NAME=''${1}
      SRC=''${2}
      DEST=''${3}
      DEST_DIR=$(dirname $DEST)

      echo "Decoding $NAME secret"
      mkdir -p $DEST_DIR
      TMP=$(mktemp $DEST_DIR/.XXXXXX)
      chmod 0600 $TMP
      ${pkgs.openssl}/bin/openssl aes-256-cbc -d -base64 -pbkdf2 -kfile /root/secrets.password -in $SRC -out $TMP
      mv $TMP $DEST
    '';
  in {
    systemd.services = mapAttrs' (name: secret: nameValuePair "secrets-${name}" {
      enable = true;
      description = "Decrypt ${name} secret";
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        Before = secret.beforeService;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${decode_secret} ${name} ${secret_file secret.src} ${secret.dest}";
      };
    }) cfg;
  };
}
