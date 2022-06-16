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

    services.dhcpd4 = let
      lan = cfg.lan;
      gw_host = builtins.head lan.hosts;
      static_hosts = builtins.tail lan.hosts;
      renderHost = { host, mac, ip, ... }: ''
        host ${host} {
          hardware ethernet ${mac};
          fixed-address ${ip};
        }
      '';
    in {
      enable = true;
      interfaces = [ cfg.interface ];
      extraConfig = ''
        option domain-name-servers ${gw_host.ip};
        option domain-name ${lan.domain};
        option subnet-mask ${lan.net_mask};
        
        subnet ${lan.net_addr} netmask ${lan.net_mask} {
          option broadcast-address ${lan.broadcast_addr};
          option routers ${gw_host.ip};
          interface ${cfg.interface};
          range ${lan.mkAddr 100} ${lan.mkAddr 200};
        }

        ${builtins.concatStringsSep "\n" (map renderHost static_hosts)}
      '';
    };
  };
}
