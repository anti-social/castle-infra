{ config, lib, pkgs, ... }: let
  wan_if = "enp2s0";
  wan_mac = "40:21:08:80:03:da";

  lan_if = "br0";
  lan_br_ifs = [ "enp3s0" "enp4s0" "enp5s0" "enp6s0" "enp7s0" ];

  guest_if = "guest";
  guest_addr_prefix = "192.168.3";
  guest_addr = "${guest_addr_prefix}.1";
  guest_network_length = 24;
  guest_network = "${guest_addr_prefix}.0/${toString guest_network_length}";

  lan_zone = [ lan_if guest_if ];
  wan_zone = [ wan_if ];

  lan = import ./lan.nix;
  hostname = "gw";
  hostname_aliases = lan.hosts.gw.aliases;
  local_addr = lan.mkAddr 1;

  vpn_if = "wg0";
  vpn_listen_port = 51820;
  vpn_addr_prefix = "192.168.102";
  vpn_network = "${vpn_addr_prefix}.0/24";

  firefly_vpn_listen_port = 24801;

  container_if = "podman0";

  iperf_ports = [ 5201 5202 ];

  cockpitModule = { config, ... }: {
    config = {
      services.cockpit = {
        enable = true;
      };
      networking.firewall.interfaces.${lan_if}.allowedTCPPorts = [ 9090 ];
    };
  };

  webModule = { config, ... }: {
    config = {
      networking.firewall.interfaces.${lan_if}.allowedTCPPorts = [ 80 443 ];
      networking.firewall.interfaces.${wan_if}.allowedTCPPorts = [ 80 443 ];

      users.users.nginx.extraGroups = [ "acme" ];

      services.nginx = {
        enable = true;
        #recommendedProxySettings = true;
      };
      services.nginx.virtualHosts."\"\"" = {
        # addSSL = true;
        # sslCertificate = "/var/lib/acme/castle.mk/cert.pem";
        # sslCertificateKey = "/var/lib/acme/castle.mk/key.pem";
        extraConfig = ''
          return 444;
        '';
      };
      security.acme = {
        acceptTerms = true;
        defaults.email = "kovalidis@gmail.com";
      };

      services.nginx.virtualHosts."olx.castle.mk" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          return = ''
            200 '
            <body style="display: table; width: 100%; height: 100%; margin: 0; padding: 0;">
              <h1 style="display: table-cell; text-align: center; vertical-align: middle">
                <i>Пішов на хуй, довбойоб!</i>
              </h1>
            </body>'
          '';
          extraConfig = ''
            default_type text/html;
            charset utf-8;
          '';
        };
      };

      services.nginx.virtualHosts."photos.castle.mk" = {
        forceSSL = true;
        enableACME = true;
        extraConfig = ''
          client_max_body_size 4g;
          proxy_buffering off;
        '';
        locations."/" = {
          proxyPass = "http://pc.castle:2342";
          proxyWebsockets = true;
        };
      };

      services.nginx.virtualHosts."drive.castle.mk" = {
        forceSSL = true;
        enableACME = true;
        extraConfig = ''
          client_max_body_size 100m;
          proxy_buffering off;
        '';
        locations."/" = {
          proxyPass = "http://pc.castle:80/drive/";
        };
      };

      systemd.services.nginx.after = [ "coredns.service" ];
    };
  };
in {
  imports =
    [
      ./another-nix-secrets
      ./modules/common.nix
      ./modules/dhcp-server.nix
      ./modules/dns-proxy.nix
      ./modules/metrics.nix
      ./modules/node-exporter.nix
      ./modules/vmagent.nix
      ./modules/smart-home.nix
      ./modules/unifi-controller.nix
      cockpitModule
      webModule
    ];

  deployment = {
    targetHost = "192.168.2.1";
    targetUser = "root";
    # buildOnTarget = true;
    allowLocalDeployment = true;
  };

  services.secrets = {
    passwordFile = "/root/secrets.password";
  };

  ### Hardware configuration ###

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [];

  fileSystems = let
    mountOptions = [ "compress=zstd" "discard=async" "autodefrag" "noatime" ];
  in {
    "/" = {
      device = "/dev/disk/by-uuid/59acc38c-f035-4222-a195-d1750ce97b2b";
      fsType = "btrfs";
      options = [ "subvol=root" ] ++ mountOptions;
    };
    "/nix" = {
      device = "/dev/disk/by-uuid/59acc38c-f035-4222-a195-d1750ce97b2b";
      fsType = "btrfs";
      options = [ "subvol=nix" ] ++ mountOptions;
    };
    "/home" = {
      device = "/dev/disk/by-uuid/59acc38c-f035-4222-a195-d1750ce97b2b";
      fsType = "btrfs";
      options = [ "subvol=home" ] ++ mountOptions;
    };
    "/var" = {
      device = "/dev/disk/by-uuid/59acc38c-f035-4222-a195-d1750ce97b2b";
      fsType = "btrfs";
      options = [ "subvol=var" ] ++ mountOptions;
    };
  };
  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  ### End of hardware configuration ###


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # services.udev.extraRules = ''
  #   1SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="12d1", ATTR{idProduct}=="1f01", \
  #     RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch --huawei-new-mode -v 12d1 -p 1f01 -V 12d1 -P 14db"

  #   SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", \
  #     SYMLINK+="zigbee-bridge", MODE="0666"
  # '';

  systemd.network = {
    netdevs = {
      "20-br0" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
        };
        bridgeConfig = {
        #   DefaultPVID = "1";
        #   VLANFiltering = true;
        };
      };

      "20-${guest_if}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = guest_if;
        };
        vlanConfig = {
          Id = 3;
        };
      };
    };

    networks = let
      bridge_lan_networks = builtins.listToAttrs (map (ifname:
        {
          name = "30-${ifname}";
          value = {
            matchConfig.Name = ifname;
            networkConfig.Bridge = lan_if;
          };
        }
      ) lan_br_ifs);
    in bridge_lan_networks // {
      "30-${wan_if}" = {
        matchConfig.Name = wan_if;
        linkConfig.MACAddress = wan_mac;
        networkConfig.DHCP = "yes";
      };

      "40-${lan_if}" = {
        matchConfig.Name = lan_if;
        linkConfig = {
          # ActivationPolicy = "always-up";
          RequiredForOnline = "degraded";
        };
        networkConfig = {
          DHCP = "no";
          IPv6PrivacyExtensions = "kernel";
        };
        address = [
          "${local_addr}/${toString lan.prefix_length}"
        ];
        vlan = [ guest_if ];
      };

      "40-${guest_if}" = {
        matchConfig.Name = guest_if;
        address = [
          "${guest_addr}/${toString guest_network_length}"
        ];
      };
    };
  };

  networking = {
    hostName = "gw";
    useNetworkd = true;
    useDHCP = false;

    nameservers = [ "127.0.0.1" ];
    # resolvconf = {
    #   useLocalResolver = true;
    #   extraConfig = ''
    #     search_domains="${lan.domain}"
    #   '';
    # };

    nftables = {
      enable = true;
      tables = {
        guest-fw = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority filter + 10;

              iifname "${guest_if}" ip daddr 192.168.2.1 tcp dport 22 accept
              iifname "${guest_if}" ip daddr 192.168.3.1 udp dport 53 accept

              iifname "${guest_if}" ip daddr 192.168.0.0/16 drop
              iifname "${guest_if}" ip daddr 172.16.0.0/12 drop
              iifname "${guest_if}" ip daddr 10.0.0.0/8 drop
            }
          '';
        };
      };
    };
    firewall = {
      enable = true;
      trustedInterfaces = [ container_if ];
      interfaces = {
        ${lan_if} = {
          allowedTCPPorts = iperf_ports;
          allowedUDPPorts = [
            69 # tfpt
            firefly_vpn_listen_port
          ];
        };
        firefly = {
          allowedTCPPorts = iperf_ports;
        };
        ${wan_if} = {
          allowedUDPPorts = [
            vpn_listen_port
            firefly_vpn_listen_port
          ];
        };
      };
      filterForward = true;
      extraForwardRules = ''
        iifname "${vpn_if}" oifname "${lan_if}" accept

        iifname "${container_if}" accept

        iifname firefly oifname firefly accept
      '';
    };

    nat = {
      enable = true;
      internalInterfaces = lan_zone;
      externalInterface = wan_if;
    };
  };

  # Ignore lan interfaces to be online
  # systemd.services.systemd-networkd-wait-online.serviceConfig.ExecStart = [
  #   "" # clear old command
  #   "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online --timeout 30 --ignore enp3s0 --ignore enp4s0 --ignore enp5s0 --ignore enp6s0 --ignore enp7s0"
  # ];

  services.fail2ban = {
    enable = true;
    ignoreIP = [
      lan.network
      guest_network
      vpn_network
    ];
    bantime-increment = {
      enable = true;
    };
    banaction = "iptables-ipset-proto6-allports";
    extraPackages = [
      pkgs.ipset
    ];
  };

  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal = {
      relayHosts = [ "rustdesk.castle.mk" "192.168.2.1" ];
    };
  };

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.castle.mk";
      listen-http = "localhost:10080";
      auth-default-access = "deny-all";
      auth-file = "/var/lib/ntfy-sh/auth.db";
      cache-file = "/var/lib/ntfy-sh/cache.db";
      attachment-cache-dir = "/var/lib/ntfy-sh/attachemnts";
    };
  };
  services.nginx.virtualHosts."ntfy.castle.mk" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      client_max_body_size 10m;
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://localhost:10080";
      proxyWebsockets = true;
    };
  };

  networking.wireguard.interfaces.${vpn_if} = {
    ips = [ "${vpn_addr_prefix}.1/24" ];
    listenPort = vpn_listen_port;
    privateKeyFile = "/etc/wireguard/${vpn_if}.privkey";

    peers = [
      {
        # Alla's macbook
        publicKey = "SR6YONkjoS5guGF/2vv8aR4GqI2UWRvkq28BSVVumVc=";
        allowedIPs = [ "192.168.102.3/32" ];
        persistentKeepalive = 25;
      }
      {
        # My work laptop
        publicKey = "c8UHeWjMELB1/+ehjPICvtjBaYkZhRuZw7YZJvLUgEg=";
        allowedIPs = [ "192.168.102.4/32" ];
        persistentKeepalive = 25;
      }
      {
        # My phone (Samsung Note)
        publicKey = "5fbeSwMP1b1QK3DHxiR0jbGNOvHXEcohC7TV+hnQCDo=";
        allowedIPs = [ "192.168.102.11/32" ];
        persistentKeepalive = 25;
      }
      {
        # privKey = "SK1T/YxJKGHzecxUsiNCvTkrS8YBlTMfFNQbe2bqjH8=";
        publicKey = "St1qLCN7EtsWiiTQxNRPGtTpwa95fLcguwiZWUJU2S8=";
        allowedIPs = [ "192.168.102.14/32" ];
        persistentKeepalive = 25;
      }
    ];
  };
  services.secrets.files."${vpn_if}-privkey" = {
    file = ./secrets/gw-wireguard-privkey.aes-256-cbc.base64;
    dest = "/etc/wireguard/${vpn_if}.privkey";
    beforeService = "wireguard-${vpn_if}.service";
  };

  networking.wireguard.interfaces.firefly = {
    ips = [ "10.248.0.1/16" ];
    listenPort = 24801;
    privateKeyFile = "/etc/wireguard/firefly.privkey";

    peers = [
      {
        # Vitaliy
        publicKey = "W+TDj4Y+qar6PP6croyMJfsppkSI3S0qz3LCNuFbJAU=";
        allowedIPs = [ "10.248.0.3/32" ];
      }
      {
        # Flipmoon
        publicKey = "yFCigCMi9gBtXzULTQ2hohM18U5fR5J5ojLEQ8UvYWs=";
        allowedIPs = [ "10.248.0.4/32" ];
      }
      {
        # Work laptop
        publicKey = "kMatf39glhcZUjqaFMVDnqkUaOPJy6Q1Afj64ME9fkw=";
        allowedIPs = [ "10.248.0.2/32" ];
      }
      # Grounds
      {
        publicKey = "5M1KmGuRt83Coe7zmWJR0H6sdSh9mu3ppoTapth0xyU=";
        allowedIPs = [ "10.248.1.0/24" ];
      }
    ];
  };
  services.secrets.files."firefly-privkey" = {
    file = ./secrets/firefly-wireguard-privkey.aes-256-cbc.base64;
    dest = "/etc/wireguard/firefly.privkey";
    beforeService = "wireguard-firefly.service";
  };

  services.dhcp-server = {
    interfaces = [ lan_if guest_if ];
    lan = lan;
    guest = {
      network = guest_network;
      broadcast_addr = "${guest_addr_prefix}.255";
      gw = guest_addr;
      range = "${guest_addr_prefix}.100 - ${guest_addr_prefix}.200";
    };
  };

  services.atftpd = {
    enable = true;
    extraOptions = [ "--bind-address=${local_addr}" ];
    root = "/var/lib/tftpboot";
  };

  services.dns-proxy = {
    interfaces = [ lan_if guest_if vpn_if ];
    bindAddr = local_addr;
    lan = lan;
    guestBindAddr = guest_addr;
  };

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
    # useXkbConfig = true; # use xkbOptions in tty.
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7H4F04bIi5au15Wo/IX8Cn1X49OR024MdOo735ew4h kovalidis@gmail.com" # pc
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjh0wyd1lNSvdEKWb1GkFmf5F61i5fWeCm7ENr/W0Vt kovalidis@gmail.com" # work laptop
    ];
  };
  users.users.alexk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7H4F04bIi5au15Wo/IX8Cn1X49OR024MdOo735ew4h kovalidis@gmail.com" # pc
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjh0wyd1lNSvdEKWb1GkFmf5F61i5fWeCm7ENr/W0Vt kovalidis@gmail.com" # work laptop
    ];
  };

  services.openssh = {
    enable = true;
  };

  services.tmate-ssh-server = {
    enable = true;
    host = "tmate.castle.mk";
    openFirewall = true;
  };
  # TODO: generate client config after server is started
  services.nginx.virtualHosts."tmate.castle.mk" = let
    tmateClientConfig = lib.concatStringsSep ''\n'' [
      ''set -g tmate-server-host "tmate.castle.mk"''
      ''set -g tmate-server-port "2222"''
      ''set -g tmate-server-rsa-fingerprint "SHA256:mFK4HoEmxHoWYrvN0keywG9NIcFLmK8cdURpJcdEb3Q"''
      ''set -g tmate-server-ed25519-fingerprint "SHA256:npoNVFEx3g+T1qRmgI1SkQ3HD/TYx/1pYpsHnA+Zh4w"''
    ];
  in {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      return = "200 '${tmateClientConfig}'";
      extraConfig = ''
        add_header Content-type text/plain;
      '';
    };
  };

  services.nginx.virtualHosts."mono.castle.mk" = {
    forceSSL = true;
    enableACME = true;
    extraConfig = ''
      proxy_set_header X-Real-IP $remote_addr;
      proxy_buffering off;
    '';

    locations."/" = {
      proxyPass = "http://localhost:10081";
      # return = "200";
      # extraConfig = ''
      #   add_header Content-type text/plain;
      # '';
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; let
    system-utils = [
      bat
      colmena
      git
      htop
      iperf
      mc
      pciutils
      ripgrep
      tmux
      unzip
      usbutils
      usb-modeswitch
      usb-modeswitch-data
      usbutils
      wget
      zsh
    ];
    network-utils = [
      bridge-utils
      dnsutils
      ethtool
      inetutils
      iperf
      nmap
      tcpdump
      tmate
    ];
  in system-utils ++ network-utils;

  modules.vmagent = {
    enable = true;
  };
  modules.vmagent.relabelConfigs.pcNode = ''
    - source_labels: [instance]
      regex: "(.*):.+"
      target_label: instance
      replacement: "$1"
  '';
  modules.vmagent.scrapeConfigs.pcNode = ''
    - job_name: node
      scrape_interval: 15s
      static_configs:
      - targets:
        - "localhost:${toString config.services.prometheus.exporters.node.port}"
        - "pc.castle:9100"
        - "oldpc.castle:9182"
        - "newpc.castle:9182"
  '';

  modules.node-exporter = {
    hostname = lan.mkFQDN(hostname);
  };

  modules.unifi-controller = {
    localAddr = local_addr;
  };

  modules.smart-home = {
    iotLocalAddr = local_addr;
    iotInterface = lan_if;
    lanHost = lan.mkFQDN "home";
    extHost = "home.castle.mk";
  };

  ### Containers:

  virtualisation = {
    podman.enable = true;
    oci-containers.backend = "podman";
  };

  # boot.kernelParams = [ "systemd.debug-shell=1" ];
  # systemd.additionalUpstreamSystemUnits = [
  #   "debug-shell.service"
  # ];
  # #systemd.services.debug-shell.enable = true;

  # services.udev.extraRules = ''
  #   SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="12d1", ATTR{idProduct}=="1f01", \
  #     RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch --huawei-new-mode -v 12d1 -p 1f01 -V 12d1 -P 14db"

  #   SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", \
  #     SYMLINK+="zigbee-bridge", MODE="0666"
  # '';

  #   firewall = {
  #     enable = true;

  #     extraCommands = let
  #       inetForwardChain = "inet-forward";
  #       localToUtcTime = time: "$(date -u -d @$(date '+%s' -d '${time}') '+%H:%M')";
  #       limitedInetHosts = builtins.filter (h: builtins.hasAttr "inetActiveTime" h) lan.hosts;
  #       limitInetHostRule = h: "ip46tables -A ${inetForwardChain} --match mac --mac-source ${h.mac} --match time --timestart ${localToUtcTime (lib.last h.inetActiveTime)} --timestop ${localToUtcTime (builtins.head h.inetActiveTime)} -j REJECT";
  #     in ''
  #       ip46tables -F ${inetForwardChain} 2>/dev/null || true
  #       ip46tables -X ${inetForwardChain} 2>/dev/null || true
  #       ip46tables -N ${inetForwardChain} 2>/dev/null || true
  #       ip46tables -A FORWARD -j ${inetForwardChain}
  #       ${lib.concatStringsSep "\n" (map limitInetHostRule limitedInetHosts)}
  #     '';
  #   };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?
}
