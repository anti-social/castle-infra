{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mqtt;
in {
  options.services.mqtt = {
    enable = mkEnableOption "Enable MQTT server";

    bindAddr = mkOption {
      type = types.str;
      description = "Address to listen on";
    };
  };

  config = {
    services.mosquitto = {
      enable = true;
      logType = [
        "error" "warning" "notice" "information"
        # Uncomment to debug
        #"debug" "subscribe" "unsubscribe"
      ];
      listeners = [
        {
          address = cfg.bindAddr;
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
