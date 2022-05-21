{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.vmagent;

  vmagentConfig = pkgs.writeText "vmagent.yaml" ''
    scrape_configs:
    ${concatStringsSep "\n" (builtins.attrValues cfg.scrapeConfigs)}
  '';
in {
  options = {
    services.vmagent = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable vmagent service";
      };

      scrapeConfigs = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        description = "Scrape endpoints";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.vmagent = {
      enable = true;
      description = "Victoria metrics agent";
      wantedBy = [ "multi-user.target" ];
      requires = [ "victoriametrics.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${config.services.victoriametrics.package}/bin/vmagent " +
          "-promscrape.config=${vmagentConfig} " +
          "-remoteWrite.url=http://${toString config.services.victoriametrics.listenAddress}/api/v1/write";
      };
    };
  };
}
