{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.smart-home;
  home_assistant_version = "2022.5.5";
in {
  options.services.smart-home = {
    iotLocalAddr = mkOption {
      type = types.str;
      description = "Local address for IoT";
    };
    vhost = mkOption {
      type = types.str;
      description = "Virtual host domain";
    };
  };

  config = {
    virtualisation.oci-containers.containers.home-assistant = let
      configuration = pkgs.writeText "home-assistant-configuration.yaml" ''
        # Loads default set of integrations. Do not remove.
        default_config:

        http:
          #server_host: "127.0.0.1"
          use_x_forwarded_for: true
          trusted_proxies:
          - "127.0.0.1"
          - "10.88.0.1"

        # Text to speech
        tts:
        - platform: google_translate

        automation: !include automations.yaml
        #script: !include scripts.yaml
        #scene: !include scenes.yaml
      '';
      #sonoff_lan_plugin = fetchTarball {
      #  url = "https://github.com/AlexxIT/SonoffLAN/archive/refs/tags/v3.0.5.tar.gz";
      #  sha256 = "146a197znmwgph3s404939wqjk2sbcmnzxifhll9xr76xn3xmjsv";
      #};
    in {
      image = "ghcr.io/home-assistant/home-assistant:${home_assistant_version}";
      environment = {
        TZ = config.time.timeZone;
      };
      volumes = [
        "home-assistant:/config"
        "${configuration}:/config/configuration.yaml"
        #"${sonoff_lan_plugin}/custom_components/sonoff:/config/custom_components/sonoff"
      ];
      ports = [
        "127.0.0.1:8123:8123"
      ];
      #extraOptions = [ "--network=host" ];
    };
    services.nginx.virtualHosts.${cfg.vhost} = {
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };

    services.mosquitto = {
      enable = true;
      logType = [
        "error" "warning" "notice" "information"
        # Uncomment to debug
        #"debug" "subscribe" "unsubscribe"
      ];
      listeners = [
        {
          address = cfg.iotLocalAddr;
          acl = [ "topic readwrite #" ];
          users = {
            iot_device = {
              hashedPassword = "$6$hX3XfO97Bl8V9aAd$gwwmY1TGuAhi4WZeSb1xFjRxuddMGJPbfildASeIneHOy+m/X58N27komjnwwzjC1dsvG1EJ9HAGXBOXOipbRw==";
              acl = [
                "write tasmota/discovery/#"
                "write homeassistant/#"
                # There is no way to add pattern: https://github.com/NixOS/nixpkgs/issues/174971
                #"pattern read cmnd/tasmota/%c/#"
                #"pattern write stat/tasmota/%c/#"
                #"pattern write tele/tasmota/%c/#"
                "readwrite cmnd/tasmota/#"
                "write stat/tasmota/#"
                "write tele/tasmota/#"
              ];
            };
            home = {
              hashedPassword = "$6$pmDdm+fqr72Dx/T+$RpJa+8rGhilp3w/41kYNslRJMDUjakS3EMJlcU72a2+1KzbpvuVrI7DJzqyD8ruWfgXvC+UW7oLiO1+1WNJVrA==";
              acl = [
                "read tasmota/discovery/#"
                "readwrite homeassistant/#"
                "write cmnd/tasmota/#"
                "read stat/tasmota/#"
                "read tele/tasmota/#"
              ];
            };
          };
        }
      ];
    };
  };
}
