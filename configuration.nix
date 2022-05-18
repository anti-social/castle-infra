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
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.device = "/dev/sda";

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
    hostName = "gw2";
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
          { address = "192.168.2.1"; prefixLength = 24; }
        ];
      };
      "${wan_bak_if}".useDHCP = true;
      "${wlan_if}".useDHCP = false;
    };

    firewall = {
      enable = true;      
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

  services.dhcpd4 = {
    enable = true;
    interfaces = [ lan_br_if ];
    extraConfig = ''
      option domain-name-servers 1.1.1.1;
      option subnet-mask 255.255.255.0;
      
      subnet 192.168.2.0 netmask 255.255.255.0 {
        option broadcast-address 192.168.2.255;
        option routers 192.168.2.1;
        interface ${lan_br_if};
        range 192.168.2.100 192.168.2.200;
      }

      host pc {
        hardware ethernet 36:01:ca:37:a7:10;
        fixed-address 192.168.2.2;
      }
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
    ethtool
    git
    htop
    pciutils
    mc
    nftables
    tcpdump
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
