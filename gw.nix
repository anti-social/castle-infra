{
  meta = {
    nixpkgs = ./gw-nixpkgs;
  };
  
  gw = { modulesPath, config, lib, name, pkgs, stdenv, ... }: let
    lan1_if = "enp1s0";
    lan2_if = "enp2s0";
    wlan_if = "wlp3s0b1";

    lan_br_if = "br0";
    lan_br_ifs = [ lan2_if ];

    wan_if = lan1_if;
    # wan_if = "enp0s21f0u2";

    lan_zone = [ lan_br_if ];
    wan_zone = [ wan_if ];

    lan = import ./lan.nix;
    hostname = (builtins.head lan.hosts).host;
    hostname_aliases = (builtins.head lan.hosts).aliases;
    local_addr = lan.mkAddr(1);
  in {
    imports =
      [ # Include the results of the hardware scan.
        ./gw-hardware-configuration.nix

        ./modules/secrets.nix
        ./modules/dhcp-server.nix
        ./modules/dns-proxy.nix
        ./modules/vmagent.nix
        ./modules/smart-home.nix
        ./modules/ups.nix
      ];

    deployment = {
      targetHost = "gw.castle";
      targetUser = "root";
      # buildOnTarget = true;
    };

    # Use the systemd-boot EFI boot loader.
    # boot.loader.systemd-boot.enable = true;
    # boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.grub = {
      device = "/dev/sda";
      gfxmodeEfi = "1920x1080";
    };

    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = true;
    };

    # Set your time zone.
    time.timeZone = "Europe/Kiev";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };

    boot.kernelParams = [ "systemd.debug-shell=1" ];
    systemd.additionalUpstreamSystemUnits = [
      "debug-shell.service"
    ];
    #systemd.services.debug-shell.enable = true;

    # TODO: find out why it does not work
    # services.udev.extraRules = ''
    #   SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="62:b6:6e:8a:2f:11", NAME="wan_huawei"
    # '';

    services.udev.extraRules = ''
      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="12d1", ATTR{idProduct}=="1f01", \
        RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch --huawei-new-mode -v 12d1 -p 1f01 -V 12d1 -P 14db"
    '';

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking = {
      hostName = hostname;
      useDHCP = false;
      
      bridges = {
        ${lan_br_if} = {
          interfaces = lan_br_ifs;
        };
      };

      interfaces = {
        ${lan2_if}.useDHCP = false;
        ${lan_br_if} = {
          useDHCP = false;
          ipv4.addresses = [
            { address = local_addr; prefixLength = 24; }
          ];
        };
        ${wan_if}.useDHCP = true;
        ${wlan_if}.useDHCP = false;
      };

      resolvconf = {
        useLocalResolver = true;
        extraConfig = ''
          search_domains="${lan.domain}"
        '';
      };

      firewall.enable = true;

      nat = {
        enable = true;
        internalInterfaces = lan_zone;
        externalInterface = wan_if;
      };

      wireless = {
        enable = false;
        networks.Castle = {
          pskRaw = "fd4c201d618d6cd19f43d3f17f757f19505c6011d3fa3fc069761acc7d391356";
        };
      };
    };

    networking.wireguard.interfaces.wg0 = {
      ips = [ "192.168.102.2/24" ];
      privateKeyFile = "/etc/wireguard/wg0.privkey";

      peers = [
        {
          endpoint = "164.92.183.176:51820";
          publicKey = "GfOnceuK9kKySxreK46KikpvLL09aFa2PY9j4+O67XE=";
          allowedIPs = [ "192.168.102.0/24" ];
          persistentKeepalive = 25;
        }
      ];
    };
    services.secrets.wg0-privkey = {
      src = "secrets/gw-wireguard-privkey.aes-256-cbc.base64";
      dest = "/etc/wireguard/wg0.privkey";
      beforeService = "wireguard-wg0.service";
    };

    # Define a user account. Don't forget to set a password with ‘passwd’.
    # users.mutableUsers = false;
    users.users.nixos = {
      uid = 999;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
    users.users.alexk = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7H4F04bIi5au15Wo/IX8Cn1X49OR024MdOo735ew4h kovalidis@gmail.com"
      ];
    };

    nixpkgs.config.allowUnfree = true;

    # List packages installed in system profile. To search, run:
    # $ nix search wget
    environment.systemPackages = with pkgs; [
      bat
      bridge-utils
      dnsutils
      ethtool
      git
      htop
      pciutils
      mc
      nftables
      nmap
      ripgrep
      tcpdump
      telnet
      tmux
      unzip
      usb-modeswitch
      usb-modeswitch-data
      usbutils
      wget
      zsh
    ];

    ### List services that you want to enable:

    services.openssh = {
      enable = true;
    };

    services.dhcp-server = {
      interface = lan_br_if;
      lan = lan;
    };

    services.dns-proxy = let
      fqdn = host: "${host}.${lan.domain}";
      renderStaticHost = { host, ip, aliases ? [], ... }:
        let
          record_values = [ip] ++ [(fqdn host)] ++ (map fqdn aliases);
        in
          "${builtins.concatStringsSep " " record_values}";
    in {
      enable = true;
      interfaces = [ lan_br_if ];
      bindAddr = local_addr;
      staticHosts = map renderStaticHost lan.hosts;
    };

    services.victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
    };
      
    services.prometheus = {
      exporters = {
        node = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9100;
          enabledCollectors = [ "systemd" ];
        };
      };
    };
    services.vmagent.scrapeConfigs.localhostNode = ''
      - job_name: node
        scrape_interval: 15s
        static_configs:
        - targets: [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]
    '';
    services.vmagent.relabelConfigs.localhostNode = ''
      - source_labels: [instance]
        regex: "localhost(:.+)?"
        target_label: instance
        replacement: "${lan.mkFQDN(hostname)}"
    '';

    services.grafana = rec {
      enable = true;
      domain = "grafana.castle";
      port = 5000;
      addr = "127.0.0.1";
      rootUrl = "http://${domain}";
    };
    services.nginx.virtualHosts.${config.services.grafana.domain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        # proxyWebsockets = true;
      };
    };

    services.vmagent = {
      enable = true;
    };
    services.vmagent.relabelConfigs.pcNode = ''
      - source_labels: [instance]
        regex: "(.*):.+"
        target_label: instance
        replacement: "$1"
    '';
    services.vmagent.scrapeConfigs.pcNode = ''
      - job_name: node
        scrape_interval: 15s
        static_configs:
        - targets: [ "pc.castle:9100" ]
    '';

    networking.firewall.interfaces = {
      ${lan_br_if}.allowedTCPPorts = [ 80 ];
    };
    services.nginx = {
      enable = true;
      #recommendedProxySettings = true;
    };

    ### Containers:

    virtualisation = {
      podman = {
        enable = true;
      };

      oci-containers = {
        backend = "podman";

        containers = {
          unifi = {
            image = "docker.io/linuxserver/unifi-controller:7.1.65";
            environment = {
              PUID = "1000";
              PGID = "1000";
              MEM_LIMIT = "1024";
              MEM_STARTUP = "256";
            };
            volumes = [
              "unifi-config:/config"
            ];
            ports = lib.flatten (lib.forEach [
              "8080:8080"
              "8443:8443"
              "3478:3478/udp"
              "10001:10001/udp"
            ] (portForward: [ "127.0.0.1:${portForward}" "${local_addr}:${portForward}" ]));
          };
        };
      };
    };

    services.smart-home = {
      iotLocalAddr = local_addr;
      iotInterface = lan_br_if;
      vhost = lan.mkFQDN("home");
    };

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "21.11"; # Did you read the comment?

  };
}
