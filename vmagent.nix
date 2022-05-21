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

      writeUrl = mkOption {
        type = types.str;
	default = "http://${config.services.victoriametrics.listenAddress}/api/v1/write";
        description = "Endpoint to send metrics";
      };

      extraOptions = mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Extra options to pass to VictoriaMetrics agent.
          See available options at
          <link xlink:href="https://docs.victoriametrics.com/vmagent.html#advanced-usage"/>
          or run <command>vmagent -help</command>
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.vmagent = {
      enable = true;
      description = "Victoria metrics agent";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 1;
        DynamicUser = true;
        StateDirectory = "vmagent";
        ExecStart = ''
          ${config.services.victoriametrics.package}/bin/vmagent \
            -promscrape.config=${vmagentConfig} \
            -remoteWrite.url=${cfg.writeUrl} \
            -remoteWrite.tmpDataPath=/var/lib/vmagent \
            ${lib.escapeShellArgs cfg.extraOptions}
        '';
      };
    };
  };
}
