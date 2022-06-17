{
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
    local_addr = lan.mkAddr 1;
  in {
    imports =
      [ # Include the results of the hardware scan.
        ./gw-hardware-configuration.nix

        ./another-nix-secrets
        ./modules/dhcp-server.nix
        ./modules/dns-proxy.nix
        ./modules/metrics.nix
        ./modules/node-exporter.nix
        ./modules/vmagent.nix
        ./modules/smart-home.nix
        ./modules/ups.nix
        ./modules/unifi-controller.nix
      ];

    deployment = {
      targetHost = "gw.castle";
      targetUser = "root";
      # buildOnTarget = true;
    };

    services.secrets = {
      passwordFile = "/root/secrets.password";
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

      SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="10c4", ATTR{idProduct}=="ea60", \
        SYMLINK+="zigbee-bridge", MODE="0666"
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
    services.secrets.files.wg0-privkey = {
      file = ./secrets/gw-wireguard-privkey.aes-256-cbc.base64;
      dest = "/etc/wireguard/wg0.privkey";
      beforeService = "wireguard-wg0.service";
    };

    services.secrets.templates."cloudns-auth.env" = {
      source = ''
        CLOUDNS_AUTH_ID=''${cloudns_auth_id}
        CLOUDNS_AUTH_PASSWORD=''${cloudns_auth_password}
      '';
      secretsEnvFile = ./secrets/cloudns-auth.env;
      beforeService = "acme-castle.mk";
    };
    security.acme = {
      acceptTerms = true;
      defaults.email = "kovalidis@gmail.com";
      certs."castle.mk" = {
        dnsProvider = "cloudns";
        dnsPropagationCheck = true;
        credentialsFile = config.secretsDestinations.templates."cloudns-auth.env";
        domain = "*.castle.mk";
      };
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
    users.users.nginx.extraGroups = [ "acme" ];

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
      inetutils
      mc
      nftables
      nmap
      pciutils
      ripgrep
      tcpdump
      #telnet
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

    services.dns-proxy = {
      interfaces = [ lan_br_if ];
      bindAddr = local_addr;
      lan = lan;
    };

    services.nginx.virtualHosts."\"\"" = {
      addSSL = true;
      sslCertificate = "/var/lib/acme/castle.mk/cert.pem";
      sslCertificateKey = "/var/lib/acme/castle.mk/key.pem";
      extraConfig = ''
        return 444;
      '';
    };

    services.node-exporter = {
      hostname = lan.mkFQDN(hostname);
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
        - targets:
          - "localhost:${toString config.services.prometheus.exporters.node.port}"
          - "pc.castle:9100"
          - "oldpc.castle:9182"
    '';

    networking.firewall.interfaces = {
      ${lan_br_if}.allowedTCPPorts = [ 80 443 ];
      ${wan_if}.allowedTCPPorts = [ 443 ];
    };
    services.nginx = {
      enable = true;
      #recommendedProxySettings = true;
    };

    ### Containers:

    virtualisation = {
      podman.enable = true;
      oci-containers.backend = "podman";
    };

    services.unifi-controller = {
      localAddr = local_addr;
    };

    services.smart-home = {
      iotLocalAddr = local_addr;
      iotInterface = lan_br_if;
      lanHost = lan.mkFQDN "home";
      extHost = "home.castle.mk";
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
