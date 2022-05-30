{ config, lib, pkgs, ... }:

with lib;

let
    nut-exporter = pkgs.buildGoModule rec {
      name = "nut_exporter";
      version = "2.3.5";

      src = pkgs.fetchFromGitHub {
        owner = "DRuggeri";
        repo = "nut_exporter";
        rev = "v${version}";
        sha256 = "0ynzgkq1z8d1mk38574mz0hnyq1d7h8bmhl2bph9liccibdhwfx8";
      };
     vendorSha256 = "0w98nngzcjb1gkizglyrbkhp8ncvvknfnwnyj9dg11028sa0jbwf";
    };
in {
  config = {
    power.ups = {
      enable = true;
      ups.powerwalker = {
        driver = "usbhid-ups";
        port = "auto";
        description = "Power Walker 3000";
      };
    };
    environment.etc."nut/upsd.conf".text = ''
      LISTEN 127.0.0.1 3493
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
    systemd.services.nut-exporter = {
      enable = true;
      description = "NUT exporter";
      wantedBy = [ "multi-user.target" ];
      environment = {
        NUT_EXPORTER_PASSWORD = "password";
      };
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 1;
        DynamicUser = true;
        ExecStart = ''${nut-exporter}/bin/nut_exporter --nut.username=upsmon'';
      };
    };
    services.vmagent.scrapeConfigs.localhostNut = ''
      - job_name: nut
        scrape_interval: 15s
        metrics_path: /ups_metrics
        static_configs:
        - targets: [ "localhost:9199" ]
          labels:
            ups: powerwalker
    '';
    services.vmagent.relabelConfigs.localhostNut = ''
      - source_labels: [__name__]
        regex: "network_ups_tools_(.+)"
        target_label: __name__
        replacement: "nut_$1"
    '';
  };
}
