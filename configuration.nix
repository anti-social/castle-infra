# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

let
  lan1_if = "enp1s0";
  lan2_if = "enp2s0";
  lan_br_if = "br0";
  wan_bak_if = "enp0s21f0u2";
  wlan_if = "wlp3s0b1";
  lan_zone = [ lan_br_if ];
  wan_zone = [ wan_bak_if ];

  hostname = "gw";
  hostname_aliases = [ "unifi" "grafana" ];
  local_domain = "castle";
  lan_addr_prefix = "192.168.2";
  local_addr = "${lan_addr_prefix}.1";
  static_hosts = [
    {
      host = "pc";
      mac = "36:01:ca:37:a7:10";
      ip = "${lan_addr_prefix}.2";
    }
    {
      host = "ap1";
      mac = "f0:9f:c2:7c:57:fe";
      ip = "${lan_addr_prefix}.241";
    }
    {
      host = "ap2";
      mac = "78:8a:20:48:e3:9c";
      ip = "${lan_addr_prefix}.242";
    }
    {
      host = "ap3";
      mac = "80:2a:a8:46:18:28";
      ip = "${lan_addr_prefix}.243";
    }
  ];
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

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
      "${lan_br_if}" = {
        interfaces = [ lan1_if lan2_if ];
      };
    };

    interfaces = {
      "${lan1_if}".useDHCP = false;
      "${lan2_if}".useDHCP = false;
      "${lan_br_if}" = {
        useDHCP = false;
        ipv4.addresses = [
          { address = local_addr; prefixLength = 24; }
        ];
      };
      "${wan_bak_if}".useDHCP = true;
      "${wlan_if}".useDHCP = false;
    };

    firewall = {
      enable = true;
      interfaces."${lan_br_if}" = {
        allowedTCPPorts = [ 80 ];
        allowedUDPPorts = [ 53 67 68 ];
      };
    };

    nat = {
      enable = true;
      internalInterfaces = lan_zone;
      externalInterface = wan_bak_if;
    };

    wireless = {
      enable = true;
      networks.Castle = {
        pskRaw = "fd4c201d618d6cd19f43d3f17f757f19505c6011d3fa3fc069761acc7d391356";
      };
    };
  };

  services.dhcpd4 = let 
    renderHost = { host, mac, ip, ... }: ''
      host ${host} {
        hardware ethernet ${mac};
        fixed-address ${ip};
      }
    '';
  in {
    enable = true;
    interfaces = [ lan_br_if ];
    extraConfig = ''
      option domain-name-servers ${local_addr};
      option domain-name castle;
      option subnet-mask 255.255.255.0;
      
      subnet ${lan_addr_prefix}.0 netmask 255.255.255.0 {
        option broadcast-address ${lan_addr_prefix}.255;
        option routers ${local_addr};
        interface ${lan_br_if};
        range ${lan_addr_prefix}.100 ${lan_addr_prefix}.200;
      }

      ${builtins.concatStringsSep "\n" (map renderHost static_hosts)}
    '';
  };

  services.dnsmasq = let
    fqdn = host: "${host}.${local_domain}";
    renderHost = { host, ip, aliases ? [], ... }:
      let
        record_values = ["${fqdn host}"] ++ (map fqdn aliases) ++ [ip];
      in
        "host-record=${builtins.concatStringsSep "," record_values}";
  in {
    enable = true;
    servers = [ "1.1.1.2" "1.0.0.2" ];
    extraConfig = ''
      no-resolv
      no-hosts
      cache-size=10000
      domain=${local_domain}
      expand-hosts
      ${renderHost {host = hostname; ip = local_addr; aliases = hostname_aliases;}}
      ${builtins.concatStringsSep "\n" (map renderHost static_hosts)}
    '';
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    # mutableUsers = false;
    users.nixos = {
      uid = 999;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
    };
    users.alexk = {
      uid = 1000;
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7H4F04bIi5au15Wo/IX8Cn1X49OR024MdOo735ew4h kovalidis@gmail.com"
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bridge-utils
    dnsutils
    ethtool
    git
    htop
    pciutils
    mc
    nftables
    tcpdump
    telnet
    tmux
    usb-modeswitch
    usb-modeswitch-data
    usbutils
    wget
  ];

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
          ports = [
            "8080:8080"
            "8443:8443"
            "3478:3478/udp"
            "10001:10001/udp"
          ];
        };
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
  };

  services = {
    victoriametrics = {
      enable = true;
      listenAddress = "127.0.0.1:8428";
    };

    prometheus = {
      exporters = {
        node = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 9100;
          enabledCollectors = [ "systemd" ];
        };
      };
      scrapeConfigs = [
        {
          job_name = "gw";
          static_configs = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ];
        }
      ];
    };

    grafana = {
      enable = true;
      domain = "grafana.castle";
      port = 5000;
      addr = "127.0.0.1";
    };
  };

  environment.etc = {
    "vmagent.yaml" = {
      text = ''
        scrape_configs:
        - job_name: node
          scrape_interval: 15s
          static_configs:
          - targets: [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]
      '';
    };
  };

  systemd.services.vmagent = {
    enable = true;
    description = "Victoria metrics agent";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${config.services.victoriametrics.package}/bin/vmagent -promscrape.config=/etc/vmagent.yaml -remoteWrite.url=http://${toString config.services.victoriametrics.listenAddress}/api/v1/write";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.${config.services.grafana.domain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        # proxyWebsockets = true;
      };
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
