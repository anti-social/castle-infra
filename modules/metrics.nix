{ config, lib, ... }:

with lib;

{
  config = {
    services.victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
    };

    services.grafana = rec {
      enable = true;
      domain = "grafana.castle";
      port = 5000;
      addr = "127.0.0.1";
      rootUrl = "http://${domain}";
    };
    services.nginx.virtualHosts.${config.services.grafana.domain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        # proxyWebsockets = true;
      };
    };
  };
}
