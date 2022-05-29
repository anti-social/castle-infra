{
  nixie = { modulesPath, lib, name, pkgs, ... }: let
    wan_if = "ens3";
    vpn_if = "wg0";
    vpn_listen_port = 51820;
    vpn_addr_prefix = "192.168.102";
    vpn_network = "${vpn_addr_prefix}.0/24";
  in {
    imports = lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
      (modulesPath + "/virtualisation/digital-ocean-config.nix")
      ./modules/secrets.nix
    ];

    deployment = {
      targetHost = "164.92.183.176";
      targetUser = "root";
    };

    networking.hostName = name;

    
    networking.nat = {
      enable = true;
      externalInterface = wan_if;
      internalInterfaces = [ vpn_if ];
    };
    networking.firewall = {
      enable = true;
      allowedUDPPorts = [ vpn_listen_port ];
    };

    networking.wireguard.interfaces.${vpn_if} = let
      route_to_home_network = "192.168.2.0/24 via 192.168.102.2";
      nat_rule = "POSTROUTING -t nat -i ${vpn_if} -s ${vpn_network} -o ${wan_if} -j MASQUERADE";
    in{
      ips = [ "${vpn_addr_prefix}.1/24" ];

      listenPort = vpn_listen_port;

      postSetup = ''
        ${pkgs.iproute2}/bin/ip route add ${route_to_home_network}
      '';
      postShutdown = ''
        ${pkgs.iproute2}/bin/ip route del ${route_to_home_network}
      '';
      #postSetup = ''
      #  ${pkgs.iptables}/bin/iptables -A ${nat_rule}
      #'';
      #postShutdown = ''
      #  ${pkgs.iptables}/bin/iptables -D ${nat_rule}
      #'';

      privateKeyFile = "/etc/wireguard/wg0.privkey";

      peers = [
        {
          publicKey = "0iQM5AOTf1yPFYK8TbI+BsT4F9mD8O2gNaIsebwpgEk=";
          allowedIPs = [ "192.168.102.2" "192.168.2.0/24" ];
        }
        {
          publicKey = "SsYeKjZ7oqvGTDiZoBgB3kluRjmMUWzsOYZggdhAn30=";
          allowedIPs = [ "192.168.102.12" ];
        }
        {
          publicKey = "knO4Q8MDL3wbRa0cHiqGcEbq68UKsxW4wbqhYyfeFDo=";
          allowedIPs = [ "192.168.102.21" ];
        }
      ];
    };
    services.secrets.wg0-privkey = {
      src = "secrets/do-wireguard-privkey.aes-256-cbc.base64";
      dest = "/etc/wireguard/wg0.privkey";
      beforeService = "wireguard-wg0.service";
    };

    environment.systemPackages = with pkgs; [
      inetutils
      iptables
      tmux
    ];
  };
}
