{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ups;

  prometheus-nut-exporter = pkgs.rustPlatform.buildRustPackage rec {
    pname = "prometheus-nut-exporter";
    version = "1.1.1";

    src = pkgs.fetchFromGitHub {
      owner = "HON95";
      repo = pname;
      rev = "v${version}";
      sha256 = "153kk9725d3r7177mwcyl8nl0f1dsgn82m728hfybs7d39qa4yqm";
    };
    cargoSha256 = "066s2wp5pqfcqi4hry8xc5a07g42f88vpl2vvgj20dkk6an8in54";
  };
in {
  options.services.ups = {
    listenAddrs = mkOption {
      type = types.listOf types.str;
    };
  };

  config = {
    power.ups = {
      enable = true;
      ups.powerwalker = {
        driver = "usbhid-ups";
        port = "auto";
        description = "Power Walker 3000";
      };
    };
    environment.etc."nut/upsd.conf".text = let
      listen = addr: "LISTEN ${addr}";
    in ''
      ${builtins.concatStringsSep "\n" (map listen cfg.listenAddrs)}
    '';
    environment.etc."nut/upsd.users".text = ''
      [upsmon]
        password = password
        actions = SET
        instcmds = ALL
    '';
    environment.etc."nut/upsmon.conf".text = ''
      MONITOR powerwalker@localhost 1 upsmon password primary
    '';

    users.users.nut = {
      isSystemUser = true;
      createHome = true;
      home = "/var/lib/nut";
      group = "nut";
    };
    users.groups.nut.name = "nut";

    networking.firewall.interfaces.br0.allowedTCPPorts = [ 3493 ];

    systemd.services.prometheus-nut-exporter = {
      enable = true;
      description = "Prometheus NUT exporter";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 1;
        DynamicUser = true;
        ExecStart = "${prometheus-nut-exporter}/bin/prometheus-nut-exporter";
      };
    };
    services.vmagent.scrapeConfigs.localhostNut = ''
      - job_name: nut
        scrape_interval: 15s
        metrics_path: /nut
        static_configs:
        - targets: ["localhost:3493"]
        relabel_configs:
        - source_labels: [__address__]
          target_label: __param_target
        - source_labels: [__param_target]
          target_label: instance
        - target_label: __address__
          replacement: localhost:9995
    '';
    services.vmagent.relabelConfigs.localhostNut = ''
      - source_labels: [__name__]
        regex: "network_ups_tools_(.+)"
        target_label: __name__
        replacement: "nut_$1"
    '';
  };
}
