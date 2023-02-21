{ config, lib, ... }:

with lib;

let
  grafana_version = "9.3.1";
  grafana_port = 3000;
  grafana_domain = "grafana.castle";
in {
  config = {
    services.victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
      retentionPeriod = 24;
    };

    virtualisation.oci-containers.containers.grafana = {
      image = "docker.io/grafana/grafana-oss:${grafana_version}";
      environment = {
        TZ = config.time.timeZone;
        GF_SERVER_HTTP_ADDR = "127.0.0.1";
        GF_SERVER_DOMAIN = grafana_domain;
        GF_SERVER_ROOT_URL = "http://${grafana_domain}";
      };
      # user = "grafana:grafana";
      volumes = [
        "grafana:/var/lib/grafana"
      ];

      # ports = [
      #   "127.0.0.1:${toString grafana_port}:${toString grafana_port}"
      # ];
      extraOptions = [
        "--network=host"
      ];
    };
    services.nginx.virtualHosts.${grafana_domain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString grafana_port}";
        extraConfig = ''
          proxy_set_header Host $host;
        '';
        # proxyWebsockets = true;
      };
    };
  };
}
