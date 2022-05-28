# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

let
  lan1_if = "enp1s0";
  lan2_if = "enp2s0";
  wlan_if = "wlp3s0b1";

  lan_br_if = "br0";
  lan_br_ifs = [ lan2_if ];

  wan_if = lan1_if;
  # wan_if = "enp0s21f0u2";

  lan_zone = [ lan_br_if ];
  wan_zone = [ wan_if ];

  hostname = "gw";
  hostname_aliases = [ "unifi" "grafana" "home" "mqtt" ];
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
      host = "oldpc";
      mac = "f8:32:e4:9a:87:da";
      ip = "${lan_addr_prefix}.3";
    }
    {
      host = "tv";
      mac = "c4:36:6c:06:73:3e";
      ip = "${lan_addr_prefix}.10";
    }
    {
      host = "laptop";
      mac = "8c:47:be:32:67:10";
      ip = "${lan_addr_prefix}.11";
    }
    {
      host = "laptop-wifi";
      mac = "cc:d9:ac:d8:60:7b";
      ip = "${lan_addr_prefix}.12";
    }
    {
      host = "flipmoon";
      mac = "ac:12:03:2d:6e:eb";
      ip = "${lan_addr_prefix}.13";
    }
    {
      host = "huawei-p10";
      mac = "30:74:96:46:1f:f9";
      ip = "${lan_addr_prefix}.21";
    }
    {
      host = "redmi-1";
      mac = "4c:63:71:5a:c1:9d";
      ip = "${lan_addr_prefix}.22";
      aliases = ["redmi-ksyusha"];
    }
    {
      host = "redmi-2";
      mac = "4c:63:71:5b:0b:00";
      ip = "${lan_addr_prefix}.23";
      aliases = ["redmi-nastya"];
    }
    {
      host = "ipad";
      mac = "e2:2b:94:4a:d0:3d";
      ip = "${lan_addr_prefix}.24";
    }
    {
      host = "iphone";
      mac = "ea:00:77:1a:1b:9c";
      ip = "${lan_addr_prefix}.25";
    }
    {
      host = "vacuum";
      mac = "50:ec:50:1b:d5:ac";
      ip = "${lan_addr_prefix}.80";
    }
    {
      host = "boiler";
      mac = "44:23:7c:ab:9c:07";
      ip = "${lan_addr_prefix}.90";
    }
    {
      host = "heat-2";
      mac = "5c:e5:0c:0f:13:57";
      ip = "${lan_addr_prefix}.91";
    }
    {
      host = "entrance-light";
      mac = "c4:4f:33:e2:81:3e";
      ip = "${lan_addr_prefix}.92";
    }
    {
      host = "bath-fan";
      mac = "8c:ce:4e:0c:62:37";
      ip = "${lan_addr_prefix}.93";
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
    {
      host = "switch";
      mac = "bc:67:1c:c8:f2:3d";
      ip = "${lan_addr_prefix}.254";
      aliases = [ "cisco" ];
    }
  ];
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./vmagent.nix
      ./dns-proxy.nix
      ./mqtt.nix
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
        search_domains="${local_domain}"
      '';
    };

    firewall = {
      enable = true;
      interfaces.${lan_br_if} = {
        allowedTCPPorts = [ 80 1883 ];
        allowedUDPPorts = [ 53 67 68 ];
      };
      interfaces.cni-podman0 = {
        allowedTCPPorts = [ 1883 ];
      };
    };

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
      shell = pkgs.zsh;
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
    nmap
    ripgrep
    tcpdump
    telnet
    tmux
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

  services.dns-proxy = let
    fqdn = host: "${host}.${local_domain}";
    renderStaticHost = { host, ip, aliases ? [], ... }:
      let
        record_values = [ip] ++ [(fqdn host)] ++ (map fqdn aliases);
      in
        "${builtins.concatStringsSep " " record_values}";
  in {
    enable = true;
    bindAddr = local_addr;
    staticHosts = [ (renderStaticHost { host = hostname; ip = local_addr; aliases = hostname_aliases; }) ] ++
      (map renderStaticHost static_hosts);
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
      replacement: "${hostname}.${local_domain}"
  '';

  services.grafana = {
    enable = true;
    domain = "grafana.castle";
    port = 5000;
    addr = "127.0.0.1";
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

  services.mqtt = {
    enable = true;
    bindAddr = local_addr;
  };
  virtualisation.oci-containers.containers.home-assistant = let
    configuration = pkgs.writeText "home-assistant-configuration.yaml" ''
      # Loads default set of integrations. Do not remove.
      default_config:

      http:
        #server_host: "127.0.0.1"
        use_x_forwarded_for: true
        trusted_proxies:
        - "127.0.0.1"
        - "10.88.0.1"

      # Text to speech
      tts:
      - platform: google_translate

      automation: !include automations.yaml
      #script: !include scripts.yaml
      #scene: !include scenes.yaml
    '';
    #sonoff_lan_plugin = fetchTarball {
    #  url = "https://github.com/AlexxIT/SonoffLAN/archive/refs/tags/v3.0.5.tar.gz";
    #  sha256 = "146a197znmwgph3s404939wqjk2sbcmnzxifhll9xr76xn3xmjsv";
    #};
  in {
    image = "ghcr.io/home-assistant/home-assistant:2022.5.5";
    environment = {
      TZ = config.time.timeZone;
    };
    volumes = [
      "home-assistant:/config"
      "${configuration}:/config/configuration.yaml"
      #"${sonoff_lan_plugin}/custom_components/sonoff:/config/custom_components/sonoff"
    ];
    ports = [
      "127.0.0.1:8123:8123"
    ];
    #extraOptions = [ "--network=host" ];
  };
  services.nginx.virtualHosts."home.castle" = {
    extraConfig = ''
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:8123";
      proxyWebsockets = true;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
