{ config, lib, ... }:

with lib;

let
  cfg = config.services.dhcp-server;
in {
  options.services.dhcp-server = {
    interfaces = mkOption {
      type = types.listOf types.str;
    };
    lan = mkOption {
      type = types.attrsOf types.anything;
    };
    guest = mkOption {
      type = types.attrsOf types.anything;
    };
  };

  config = {
    networking.firewall.interfaces = lib.mkMerge (map (iface: {
      ${iface}.allowedUDPPorts = [ 67 68 ];
    }) cfg.interfaces);

    services.kea.dhcp4 = let
      lan = cfg.lan;
      gw_host = lan.hosts.gw;
      static_hosts = lib.attrsets.filterAttrs (k: v: k != "gw") lan.hosts;
      guest = cfg.guest;
    in {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = cfg.interfaces;
        };
        lease-database = {
          name = "/var/lib/kea/dhcp4.leases";
          persist = true;
          type = "memfile";
        };
        client-classes = [
          {
            name = "UEFI";
            test = "option[93].hex == 0x0007 and not option[175].exists";
            option-data = [
              {
                name = "tftp-server-name";
                data = gw_host.ip;
              }
              {
                name = "boot-file-name";
                data = "netboot.xyz.efi";
              }
            ];
          }
        ];
        subnet4 = [
          {
            subnet = guest.network;
            id = 3;
            option-data = [
              {
                name = "broadcast-address";
                data = guest.broadcast_addr;
              }
              {
                name = "routers";
                data = guest.gw;
              }
              {
                name = "domain-name-servers";
                data = guest.gw;
              }
            ];
            pools = [
              {
                pool = guest.range;
              }
            ];
          }
          {
            subnet = lan.network;
            id = 2;
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
