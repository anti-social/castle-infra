{ config, lib, ... }:

with lib;

let
  cfg = config.modules.node-exporter;
in {
  options.modules.node-exporter = {
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
    modules.vmagent.relabelConfigs.localhostNode = ''
      - source_labels: [instance]
        regex: "localhost(:.+)?"
        target_label: instance
        replacement: "${cfg.hostname}"
    '';
  };
}
