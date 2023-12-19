{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.smart-home;
  home_assistant_version = "2023.11.3";
  mqtt_port = 1883;
  upsd_port = 3493;
in {
  options.modules.smart-home = {
    iotInterface = mkOption {
      type = types.str;
      description = "IoT network interface";
    };
    iotLocalAddr = mkOption {
      type = types.str;
      description = "Local address for IoT";
    };
    lanHost = mkOption {
      type = types.str;
      description = "Virtual host domain for LAN";
    };
    extHost = mkOption {
      type = types.str;
      description = "External virtual host domain";
    };
  };

  config = {
    networking.firewall.interfaces = {
      podman0.allowedTCPPorts = [ mqtt_port upsd_port ];
      ${cfg.iotInterface}.allowedTCPPorts = [ mqtt_port ];
    };

    services.secrets.templates."home-assistant.yaml" = {
      source = ''
        # Loads default set of integrations. Do not remove.
        default_config:

        http:
          #server_host: "127.0.0.1"
          use_x_forwarded_for: true
          trusted_proxies:
          - "127.0.0.1"
          - "10.88.0.1"

        shell_command:
          shutdown_ups: touch /config/commands/shutdown_ups

        telegram_bot:
        - platform: polling
          api_key: "''${castle_alert_telegram_bot_token}"
          allowed_chat_ids:
          - -732670381
          - -1001597296737

        # - platform: polling
        #   api_key: "''${novooskolska_power_telegram_bot_token}"
        #   allowed_chat_ids:
        #   - -1001597296737

        notify:
        - platform: telegram
          name: castle_alerts_notifier
          chat_id: -732670381

        - platform: telegram
          name: power_status_notifier
          chat_id: -1001597296737

        # Text to speech
        tts:
        - platform: google_translate

        prometheus:

        automation: !include automations.yaml
        script: !include scripts.yaml
        #scene: !include scenes.yaml
      '';
      secretsEnvFile = ../secrets/home-assistant.env;
      beforeService = "podman-home-assistant.service";
    };
    virtualisation.oci-containers.containers.home-assistant = {
      image = "ghcr.io/home-assistant/home-assistant:${home_assistant_version}";
      environment = {
        TZ = config.time.timeZone;
      };
      volumes = [
        "home-assistant:/config"
        "${config.secretsDestinations.templates."home-assistant.yaml"}:/config/configuration.yaml"
      ];

      ports = [
        "127.0.0.1:8123:8123"
      ];
      #extraOptions = [ "--network=host" ];
      #extraOptions = [ "--device=/dev/ttyUSB0" ];
    };
    services.nginx.virtualHosts.${cfg.lanHost} = {
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };
    services.nginx.virtualHosts.${cfg.extHost} = {
      addSSL = true;
      enableACME = true;
      # onlySSL = true;
      # sslCertificate = "/var/lib/acme/castle.mk/cert.pem";
      # sslCertificateKey = "/var/lib/acme/castle.mk/key.pem";
      extraConfig = ''
        proxy_buffering off;
      '';
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true;
      };
    };
    modules.vmagent.scrapeConfigs.homeAssistant = ''
      - job_name: home-assistant
        scrape_interval: 30s
        metrics_path: /api/prometheus
        bearer_token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJmNzU1ZmVjZDBjZTA0MTc4YmNhMDBjMjc4ZjRmYjI3YiIsImlhdCI6MTY1NDI4NzQxMCwiZXhwIjoxOTY5NjQ3NDEwfQ.NG92aobj0_f5A_eNHArw_1dxOHQPdU1-SUW-KhtVXAs"
        static_configs:
        - targets: [ "localhost:8123" ]
    '';

    # Also store mosquitto passwords in plain text
    services.secrets.templates."mosquitto.passwd" = {
      source = ''
        home:''${mqtt_home_password}
        iot_devide:''${mqtt_iot_device_password}
        zigbee2mqtt:''${mqtt_zigbee2mqtt_password}
        octoprint:''${mqtt_octoprint_password}
      '';
      secretsEnvFile = ../secrets/mosquitto-passwd.env;
      beforeService = "mosquitto";
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
          port = mqtt_port;
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
                "readwrite zigbee2mqtt/#"
                "readwrite octoPrint/#"
              ];
            };
            zigbee2mqtt = {
              hashedPassword = "$6$ksg1Ct4qDxuQUURN$EGnHeZ7CaBXLSC3QCcTqLm4B37+9YkBpsKqFI1Took2MT89wbnPrCAY/+9WxkxyA3QV9qfbeXqV40B76XK3O7w==";
              acl = [
                "readwrite #"
              ];
            };
            octoprint = {
              hashedPassword = "$7$101$uJeIzKlE4TcLcn8k$vV1OscD6qkSsaiWMAfckdKwxmL+a1GNjRGJu8t3HPejSsdCo/UjySWyMH4KyNf8aQxJNr8z3mA1Lr/WvPUm4Fg==";
              acl = [
                "write homeassistant/#"
                "readwrite octoPrint/#"
              ];
            };
          };
        }
      ];
    };

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = true;
        permit_join = true;
        serial = {
          port = "/dev/ttyUSB1";
        };
        mqtt = {
          server = "mqtt://${cfg.iotLocalAddr}:${toString mqtt_port}";
          user = "zigbee2mqtt";
          password = "jFmxSg3gLP";
          include_device_information = true;
        };
      };
    };

    # OTA server for Sonoff devices
    # TODO: Find out an endpoint which device accesses to after downloading a firmware
    services.nginx.virtualHosts."dl.itead.cn" = {
      locations."=/tasmota-lite.bin" = let
        tasmota_lite = pkgs.fetchurl {
          url = "http://ota.tasmota.com/tasmota/release-11.1.0/tasmota-lite.bin";
          sha256 = "a421f9080117861b2c0dd30228779466d127269acfab34de0e2cf4fa1ed0e61b";
        };
      in {
        alias = tasmota_lite;
      };
    };
  };
}
