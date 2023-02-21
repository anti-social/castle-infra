{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.dns-proxy;

  update_hosts_script = pkgs.writeShellScript "update-hosts.sh" ''
    set -eu

    echo "Updating blacklisted hosts"
    cd /var/lib/hosts
    TMP_HOSTS=$(mktemp .XXXXXX)
    echo '# https://v.firebog.net/hosts/AdguardDNS.txt' >> $TMP_HOSTS
    ${pkgs.curl}/bin/curl -sfL 'https://v.firebog.net/hosts/AdguardDNS.txt' | sed 's/^/0.0.0.0 /g' >> $TMP_HOSTS
    echo
    echo '# https://adaway.org/hosts.txt' >> $TMP_HOSTS
    ${pkgs.curl}/bin/curl -sfL 'https://adaway.org/hosts.txt' | sed 's/^127.0.0.1 /0.0.0.0 /g' >> $TMP_HOSTS
    mv $TMP_HOSTS hosts.blacklist
    chmod go+r hosts.blacklist
  '';
in {
  options.services.dns-proxy = {
    interfaces = mkOption {
      type = types.listOf types.str;
      description = "Interfaces to allow in firewall";
    };

    bindAddr = mkOption {
      type = types.str;
      default = "";
      description = "Address to listen on";
    };

    lan = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "LAN configuration";
    };
  };

  config = let
    lan = cfg.lan;
  in {
    networking.firewall.interfaces = lib.mkMerge (map (iface: {
      ${iface}.allowedUDPPorts = [ 53 ];
    }) cfg.interfaces);

    services.coredns = let
      renderStaticHost = { host, ip, aliases ? [], additionalDomain ? null, ... }:
        let
          record_values = [ip] ++ [(lan.mkFQDN host)]
                          ++ (map lan.mkFQDN aliases)
                          ++ (lib.optionals (additionalDomain != null) (map (a: "${a}.${additionalDomain}") aliases));
        in
          "${builtins.concatStringsSep " " record_values}";
    in {
      enable = true;
      config = ''
        . {
          bind 127.0.0.1 ${cfg.bindAddr}

          prometheus localhost:9153

          hosts /var/lib/hosts/hosts.blacklist {
            ${builtins.concatStringsSep "\n    " (map renderStaticHost lan.hosts)}

            reload 1h
            fallthrough
          }

          forward . tls://1.1.1.2 tls://1.0.0.2 {
            tls_servername cloudflare-dns.com
          }

          cache
          errors
        }
      '';
    };

    # services.vmagent.scrapeConfigs.localhostCoredns = ''
    #   - job_name: coredns
    #     scrape_interval: 15s
    #     static_configs:
    #     - targets: [ "localhost:9153" ]
    # '';

    users.users.dns-proxy = {
      isSystemUser = true;
      group = "dns-proxy";
    };
    users.groups.dns-proxy = {};
    systemd.services.hosts-blacklist = {
      description = "Update blacklisted hosts";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = "dns-proxy";
        Group = "dns-proxy";
        StateDirectory = "hosts";
        ExecStart = "${update_hosts_script}";
      };
    };
    systemd.timers.hosts-blacklist = {
      enable = true;
      description = "Update blacklisted hosts timer";
      wantedBy = [ "timers.target" ];
      partOf = [ "hosts-blacklist.service" ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
      };
    };
  };
}
