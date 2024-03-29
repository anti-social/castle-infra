{ config, lib, ... }:

with lib;

let
  cfg = config.modules.unifi-controller;
in {
  options.modules.unifi-controller = {
    localAddr = mkOption {
      type = types.str;
      description = "Local address to listen on";
    };
  };

  config = {
    virtualisation.oci-containers.containers.unifi = {
      image = "docker.io/linuxserver/unifi-controller:7.3.83";
      environment = {
        PUID = "1000";
        PGID = "1000";
        MEM_LIMIT = "1024";
        MEM_STARTUP = "256";
      };
      volumes = [
        "unifi-config:/config"
      ];
      ports = flatten (forEach [
        "8080:8080"
        "8443:8443"
        "3478:3478/udp"
        "10001:10001/udp"
      ] (portForward: [ "127.0.0.1:${portForward}" "${cfg.localAddr}:${portForward}" ]));
    };
  };
}
