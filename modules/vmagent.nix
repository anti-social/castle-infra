{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.vmagent;

  vmagentConfig = pkgs.writeText "vmagent.yaml" ''
    scrape_configs:
    ${concatStringsSep "\n" (builtins.attrValues cfg.scrapeConfigs)}
  '';

  relabelConfig = pkgs.writeText "vmagent-relabel.yaml" ''
    ${concatStringsSep "\n" (builtins.attrValues cfg.relabelConfigs)}
  '';
in {
  options = {
    modules.vmagent = {
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

      relabelConfigs = mkOption {
        type = types.attrsOf types.lines;
        default = {};
        description = "Relabel configs";
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
            -remoteWrite.relabelConfig=${relabelConfig} \
            ${lib.escapeShellArgs cfg.extraOptions}
        '';
      };
    };
  };
}
