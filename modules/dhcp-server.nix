{ config, lib, ... }:

with lib;

let
  cfg = config.services.dhcp-server;
in {
  options.services.dhcp-server = {
    interface = mkOption {
      type = types.str;
    };
    lan = mkOption {
      type = types.attrsOf types.anything;
    };
  };

  config = {
    networking.firewall.interfaces.${cfg.interface}.allowedUDPPorts = [ 67 68 ];

    services.kea.dhcp4 = let
      lan = cfg.lan;
      gw_host = lan.hosts.gw;
      static_hosts = lib.attrsets.filterAttrs (k: v: k != "gw") lan.hosts;
    in {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = [ cfg.interface ];
        };
        lease-database = {
          name = "/var/lib/kea/dhcp4.leases";
          persist = true;
          type = "memfile";
        };
        subnet4 = [
          {
            subnet = lan.network;
                option-data = [
                  {
                    name = "broadcast-address";
                    data = lan.broadcast_addr;
                  }
                  {
                    name = "routers";
                    data = gw_host.ip;
                  }
                  {
                    name = "domain-name-servers";
                    data = gw_host.ip;
                  }
                  {
                    name = "domain-name";
                    data = lan.domain;
                  }
                ];
            pools = [
              {
                pool = "${lan.mkAddr 100} - ${lan.mkAddr 200}";
              }
            ];
            reservations = lib.attrsets.mapAttrsToList (host: { mac, ip, ... }: {
              hw-address = mac;
              ip-address = ip;
              hostname = host;
            }) static_hosts;
          }
        ];
        rebind-timer = 1800;
        renew-timer = 600;
        valid-lifetime = 3600;
      };
    };
  };
}
