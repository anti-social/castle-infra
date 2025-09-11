{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.smart-home;
  home_assistant_version = "2025.2.0";
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

        climate:
        - platform: generic_thermostat
          unique_id: climate.home_heater
          name: Home Heater
          heater: switch.thermostat
          target_sensor: sensor.0x00124b00254dcaf8_temperature
          target_temp: 21
          min_temp: 16
          max_temp: 25
          min_cycle_duration: "00:30:00"

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
              hashedPassword = "$7$101$pFdvWTU2Pdo2Yoc9$Jh+LYkyObNEgnngs1NIAH98WlqgOoNiZ/DY8jPH5DjiZuSTpH3+LGt8qs5H8u6Ek12K1LRlzxzVynqlIdApD/w==";
              acl = [
                "write homeassistant/#"
                "readwrite octoPrint/#"
              ];
            };
          };
        }
      ];
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="zigbee-bridge"

      SUBSYSTEM=="tty", ATTRS{idVendor}=="067b", ATTRS{idProduct}=="23a3", SYMLINK+="bms"
    '';
    services.zigbee2mqtt = {
      enable = true;
      settings = {
        homeassistant = true;
        permit_join = true;
        serial = {
          port = "/dev/zigbee-bridge";
        };
        mqtt = {
          server = "mqtt://${cfg.iotLocalAddr}:${toString mqtt_port}";
          user = "zigbee2mqtt";
          password = "jFmxSg3gLP";
          include_device_information = true;
        };
      };
    };

    services.secrets.templates."inverter2mqtt.yaml" = {
      template = ./inverter2mqtt/powmr.yaml;
      secretsEnvFile = ../secrets/mosquitto-passwd.env;
      beforeService = "inverter2mqtt";
    };
    systemd.services.inverter2mqtt = let
      inverter2mqtt = pkgs.rustPlatform.buildRustPackage {
        pname = "inverter2mqtt";
        version = "0.0.0";
        src = pkgs.fetchFromGitHub {
          owner = "anti-social";
          repo = "inverter2mqtt";
          rev = "6b5c33969190574243cdefc4c2a58a63ced4c8e6";
          # hash = lib.fakeHash;
          hash = "sha256-MuTZbBohpgP8jEiY8KgokJ+RRFRRLEbSird7MPpeO2Q=";
        };
        # cargoHash = lib.fakeHash;
        cargoHash = "sha256-ibly/Vd08nPQSTGm1KMawh0iWAQq+J1JLajBMGMvUwc=";
        nativeBuildInputs = [
          pkgs.cmake
          pkgs.perl
        ];
        doCheck = false;
        meta = {
          description = "Stream inverter data to mqtt";
          homepage = "https://github.com/anti-social/inverter2mqtt";
          license = lib.licenses.gpl3;
          maintainers = [];
        };
      };
    in {
      description = "Stream inverter data to home assistant";
      serviceConfig = {
        Type = "simple";
        Environment = "RUST_LOG=info,paho_mqtt_c=warn";
        ExecStart = "${inverter2mqtt}/bin/inverter2mqtt ${config.secretsDestinations.templates."inverter2mqtt.yaml"}";
        Restart = "on-failure";
        RestartSec = "30";
      };
      wantedBy = [ "multi-user.target" ];
      after = [ "mosquitto.service" ];
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
