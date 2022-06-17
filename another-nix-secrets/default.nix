{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.secrets;

  commonFileOptions = {
    dest = mkOption {
      type = types.nullOr types.str;
      description = "Path to a destination decrypted file";
      default = null;
    };

    owner = mkOption {
      type = types.str;
      description = "Owner of a destination file";
      default = "root";
    };

    group = mkOption {
      type = types.str;
      description = "Group of a destination file";
      default = "root";
    };

    mode = mkOption {
      type = types.str;
      description = "Destination file permissions";
      default = "0600";
    };

    beforeService = mkOption {
      type = types.str;
      description = "Decrypt secret before starting a service";
    };
  };
in {
  options.secretsDestinations = {
    files = mkOption {
      type = types.attrsOf types.str;
      description = "Destination paths of decrypted secret files";
      default = {};
    };

    templates = mkOption {
      type = types.attrsOf types.str;
      description = "Destination paths of rendered secret templates";
      default = {};
    };
  };

  # TODO: Option to preserve last N secrets
  options.services.secrets = {
    passwordFile = mkOption {
      type = types.str;
      description = "Path to an encryption password file";
    };

    files = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          file = mkOption {
            type = types.path;
            description = "Path to a local encrypted file";
          };
        } // commonFileOptions;
      });
      description = "Encrypted files";
      default = {};
    };

    templates = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          template = mkOption {
            type = types.nullOr types.path;
            description = "Path to a local template file";
            default = null;
          };

          source = mkOption {
            type = types.nullOr types.str;
            description = "Template source";
            default = null;
          };

          # TODO: Make a list
          secretsEnvFile = mkOption {
            type = types.path;
            description = "Path to a local secrets file to use with templates";
          };
        } // commonFileOptions;
      });
      description = "Templates with secrets";
      default = {};
    };
  };

  config = let
    opensslDecrypt = "${pkgs.openssl}/bin/openssl aes-256-cbc -d -pbkdf2 -base64 -kfile ${cfg.passwordFile}";

    exportSecrets = pkgs.writeShellScript "export-secrets.sh" ''
      set -euo pipefail

      SECRETS_ENV_FILE=$1

      while IFS= read -r line; do
        if [ -z $line ]; then
          continue
        fi
        echo $line | \
          ${pkgs.gawk}/bin/awk '{ sub("="," "); } 1' | \
          ${pkgs.findutils}/bin/xargs ${pkgs.bash}/bin/bash -c \
            'echo export $0="$(echo $1 | ${opensslDecrypt})"'
      done <$SECRETS_ENV_FILE
    '';

    decodeSecret = pkgs.writeShellScript "decode-secret-file.sh" ''
      set -euo pipefail

      NAME=$1
      SRC=$2
      DEST=$3
      DEST_DIR=$(dirname $DEST)
      OWNER_GROUP=$4
      MODE=$5

      echo "Decoding $NAME secret"
      mkdir -p $DEST_DIR
      TMP=$(mktemp $DEST_DIR/.XXXXXX)
      chown $OWNER_GROUP $TMP
      chmod $MODE $TMP
      ${opensslDecrypt} -in $SRC -out $TMP
      mv $TMP $DEST
    '';

    renderTemplate = pkgs.writeShellScript "render-template-with-secrets.sh" ''
      set -euo pipefail

      NAME=$1
      TEMPLATE=$2
      SECRETS_ENV_FILE=$3
      DEST=$4
      DEST_DIR=$(dirname $DEST)
      OWNER_GROUP=$5
      MODE=$6

      . <(${exportSecrets} $SECRETS_ENV_FILE)

      echo "Rendering $NAME secret"
      mkdir -p $DEST_DIR
      TMP=$(mktemp $DEST_DIR/.XXXXXX)
      chown $OWNER_GROUP $TMP
      chmod $MODE $TMP
      cat $TEMPLATE | ${pkgs.envsubst}/bin/envsubst > $TMP
      mv $TMP $DEST
    '';

    secretFileServices = mapAttrs (name: secret: (
      let
        hash = builtins.hashString "sha256" secret.file;
        dest = if (secret.dest != null) then secret.dest else "/run/secrets/${hash}-${name}";
      in {
        service = {
          enable = true;
          description = "Decrypt ${name} secret";
          wantedBy = [ "multi-user.target" ];
          unitConfig = {
            Before = secret.beforeService;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${decodeSecret} ${name} ${secret.file} ${secret.dest} ${secret.owner}:${secret.group} ${secret.mode}";
          };
        };
        destination = dest;
      }
    )) cfg.files;

    secretTemplateServices = mapAttrs (name: secret: (
      let
        secretsEnv = pkgs.writeText (toString secret.secretsEnvFile) (builtins.readFile secret.secretsEnvFile);
        tmpl = pkgs.writeText (toString name) (if secret.source == null then (builtins.readFile secret.template) else secret.source);
        hash = builtins.hashString "sha256" "${tmpl}:${secretsEnv}";
        dest = if (secret.dest != null) then secret.dest else "/run/secrets/${hash}-${name}";
      in {
        service = {
          enable = true;
          description = "Render ${name} config";
          wantedBy = [ "multi-user.target" ];
          unitConfig = {
            Before = secret.beforeService;
          };
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${renderTemplate} ${name} ${tmpl} ${secretsEnv} ${dest} ${secret.owner}:${secret.group} ${secret.mode}";
          };
        };
        destination = dest;
      }
    )) cfg.templates;
  in {
    systemd.services = (mapAttrs' (name: value: nameValuePair "secrets-file-${name}" value.service) secretFileServices) //
                       (mapAttrs' (name: value: nameValuePair "secrets-template-${name}" value.service) secretTemplateServices);
    secretsDestinations.files = mapAttrs (name: value: value.destination) secretFileServices;
    secretsDestinations.templates = mapAttrs (name: value: value.destination) secretTemplateServices;
  };
}
