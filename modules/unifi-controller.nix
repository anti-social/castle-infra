{ config, lib, pkgs, ... }:

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

  config = let
    unifi-init-db = pkgs.writeScriptBin "unifi-init-db.sh" ''
      #!/usr/bin/env bash

      mongo <<EOF
      use ''${MONGO_AUTHSOURCE}
      db.auth("''${MONGO_INITDB_ROOT_USERNAME}", "''${MONGO_INITDB_ROOT_PASSWORD}")
      db.createUser({
        user: "''${MONGO_USER}",
        pwd: "''${MONGO_PASS}",
        roles: [
          { db: "''${MONGO_DBNAME}", role: "dbOwner" },
          { db: "''${MONGO_DBNAME}_stat", role: "dbOwner" },
          { db: "''${MONGO_DBNAME}_audit", role: "dbOwner" }
        ]
      })
      EOF
    '';
  in {
    systemd.services.unifi-network = {
      description = "Create network for Unifi container to link with DB";
      before = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.podman}/bin/podman network ls | grep "unifi" || \
        ${pkgs.podman}/bin/podman network create unifi
      '';
    };
    virtualisation.oci-containers.containers.unifi-db = {
      # Mongo 5.x requires AVX instuctions so stay with 4.x
      image = "docker.io/library/mongo:4.4.29";
      environment = {
        MONGO_INITDB_ROOT_USERNAME = "root";
        MONGO_INITDB_ROOT_PASSWORD = "unifi";
        MONGO_USER = "unifi";
        MONGO_PASS = "unifi";
        MONGO_DBNAME = "unifi";
        MONGO_AUTHSOURCE = "admin";
      };
      extraOptions = [
        "--network=unifi"
      ];
      volumes = [
        "${unifi-init-db}/bin/unifi-init-db.sh:/docker-entrypoint-initdb.d/unifi-init-db.sh:ro"
        "unifi-db:/data/db"
      ];
    };
    virtualisation.oci-containers.containers.unifi = {
      image = "docker.io/linuxserver/unifi-network-application:9.3.45";
      environment = {
        PUID = "1000";
        PGID = "1000";
        MEM_LIMIT = "1024";
        MEM_STARTUP = "256";
        MONGO_HOST = "unifi-db";
        MONGO_PORT = "27017";
        MONGO_DBNAME = "unifi";
        MONGO_USER = "unifi";
        MONGO_PASS = "unifi";
        MONGO_AUTHSOURCE = "admin";
      };
      extraOptions = [
        "--network=unifi"
        "--stop-timeout=10"
      ];
      ports = flatten (forEach [
        "8080:8080"
        "8443:8443"
        "3478:3478/udp"
        "10001:10001/udp"
      ] (portForward: [ "127.0.0.1:${portForward}" "${cfg.localAddr}:${portForward}" ]));
      dependsOn = [ "unifi-db" ];
    };
  };
}
