{ config, lib, ... }:

with lib;

let
  cfg = config.services.node-exporter;
in {
  options.services.node-exporter = {
    hostname = mkOption {
      type = types.str;
      description = "Node hostname";
    };
  };

  config = {
    services.prometheus = {
      exporters = {
        node = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9100;
          enabledCollectors = [ "systemd" ];
        };
      };
    };
    services.vmagent.relabelConfigs.localhostNode = ''
      - source_labels: [instance]
        regex: "localhost(:.+)?"
        target_label: instance
        replacement: "${cfg.hostname}"
    '';
  };
}
