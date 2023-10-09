{ config, lib, pkgs, ... }: let
  wan_if = "enp2s0";

  lan_if = "br0";
  lan_br_ifs = [ "enp3s0" "enp4s0" "enp5s0" "enp6s0" "enp7s0" ];

  lan_zone = [ lan_if ];
  wan_zone = [ wan_if ];

  lan = import ./lan.nix;
  hostname = (builtins.head lan.hosts).host;
  hostname_aliases = (builtins.head lan.hosts).aliases;
  local_addr = lan.mkAddr 1;

  vpn_if = "wg0";
  vpn_listen_port = 51820;
  vpn_addr_prefix = "192.168.102";
  vpn_network = "${vpn_addr_prefix}.0/24";

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
    };
  };
in {
  imports =
    [
      ./another-nix-secrets
      ./modules/dhcp-server.nix
      ./modules/dns-proxy.nix
      ./modules/metrics.nix
      ./modules/node-exporter.nix
      ./modules/vmagent.nix
      ./modules/smart-home.nix
      ./modules/ups.nix
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
  #   SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="12d1", ATTR{idProduct}=="1f01", \
  #     RUN+="${pkgs.usb-modeswitch}/bin/usb_modeswitch --huawei-new-mode -v 12d1 -p 1f01 -V 12d1 -P 14db"

  #   SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", \
  #     SYMLINK+="zigbee-bridge", MODE="0666"
  # '';

  networking = {
    hostName = "gw";
    useNetworkd = true;
    useDHCP = false;

    bridges = {
      ${lan_if} = {
        interfaces = lan_br_ifs;
      };
    };

    interfaces = {
      ${wan_if} = {
        useDHCP = true;
        macAddress = "40:21:08:80:03:da";
        
      };
      ${lan_if} = {
        ipv4.addresses = [
          {
            address = local_addr;
            prefixLength = lan.prefix_length;
          }
        ];
      };
    };

    nameservers = [ "127.0.0.1" ];
    # resolvconf = {
    #   useLocalResolver = true;
    #   extraConfig = ''
    #     search_domains="${lan.domain}"
    #   '';
    # };

    firewall = {
      enable = true;
      interfaces = {
        ${lan_if}.allowedTCPPorts = iperf_ports;
        ${wan_if} = {
          allowedUDPPorts = [ vpn_listen_port ];
        };
      };
      extraCommands = let
        inetForwardChain = "inet-forward";
        localToUtcTime = time: "$(date -u -d @$(date '+%s' -d '${time}') '+%H:%M')";
        limitedInetHosts = builtins.filter (h: builtins.hasAttr "inetActiveTime" h) lan.hosts;
        limitInetHostRule = h: ''
          ip46tables -A ${inetForwardChain} --match mac --mac-source ${h.mac} --match time --timestart ${localToUtcTime h.inetActiveTime.to} --timestop ${localToUtcTime h.inetActiveTime.from} -j REJECT
        '';
      in ''
        ip46tables -F ${inetForwardChain} 2>/dev/null || true
        ip46tables -X ${inetForwardChain} 2>/dev/null || true
        ip46tables -N ${inetForwardChain} 2>/dev/null || true
        ip46tables -A FORWARD -j ${inetForwardChain}
      #   ${lib.concatStringsSep "\n" (map limitInetHostRule limitedInetHosts)}
      # '';
    };

    nat = {
      enable = true;
      internalInterfaces = lan_zone;
      externalInterface = wan_if;
    };
  };

  services.fail2ban = {
    enable = true;
    ignoreIP = [
      lan.network
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

  environment.etc = {
    "systemd/network/30-br0.network" = {
      text = ''
        [Match]
        Name=${lan_if}

        [Link]
        ActivationPolicy=always-up
        RequiredForOnline=no

        [Network]
        DHCP=no
        IPv6PrivacyExtensions=kernel
        Address=${local_addr}/${toString lan.prefix_length}
        ConfigureWithoutCarrier=yes
      '';
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
 	      # My work laptop (Dell)
        publicKey = "CnQF8AEr/JZwfM/mg75z/Sh9j3VHNR59dgWegbc6rl8=";
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

  services.dhcp-server = {
    interface = lan_if;
    lan = lan;
  };

  services.dns-proxy = {
    interfaces = [ lan_if vpn_if ];
    bindAddr = local_addr;
    lan = lan;
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

  modules.ups = {
    listenAddrs = [ "127.0.0.1" local_addr ];
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
