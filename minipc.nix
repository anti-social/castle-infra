{ config, lib, pkgs, ... }: let
  hostname = "minipc";

  lan1_if = "enp1s0";
  lan2_if = "enp2s0";
  wlan_if = "wlp3s0b1";

  lan_br_if = "br0";
  lan_br_ifs = [ lan1_if lan2_if ];

  lan_zone = [ lan_br_if wlan_if ];

  iperf_port = 5201;
in {
  imports =
    [ # Include the results of the hardware scan.
      ./gw-hardware-configuration.nix

      ./another-nix-secrets
    ];

  deployment = {
    targetHost = "minipc.castle";
    targetUser = "root";
    allowLocalDeployment = true;
    # buildOnTarget = true;
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
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

  hardware.pulseaudio.enable = true;

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

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking = {
    hostName = hostname;
    useNetworkd = true;
    useDHCP = false;

    networkmanager.enable = true;

    bridges = {
      ${lan_br_if} = {
        interfaces = lan_br_ifs;
      };
    };

    interfaces = {
      ${lan1_if} = {
        useDHCP = false;
      };
      ${lan2_if} = {
        useDHCP = false;
      };
      ${lan_br_if} = {
        useDHCP = true;
      };
    };

    resolvconf = {
      useLocalResolver = true;
    };

    firewall = {
      enable = true;
    };

    # wireless = {
    #   enable = true;
    # };
  };

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "-";
      item = "nofile";
      value = "65536";
    }
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.mutableUsers = false;
  users.users.alexk = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7H4F04bIi5au15Wo/IX8Cn1X49OR024MdOo735ew4h kovalidis@gmail.com"
    ];
  };

  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.displayManager.defaultSession = "plasmawayland";
  services.xserver.desktopManager.plasma5.enable = true;
  
  nixpkgs.config.allowUnfree = true;

  programs.zsh = {
    enable = true;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; let
    system-utils = [
      bat
      colmena
      git
      htop
      mc
      pciutils
      ripgrep
      tmux
      unzip
      usb-modeswitch
      usb-modeswitch-data
      usbutils
      zsh
    ];
    network-utils = [
      bridge-utils
      dnsutils
      ethtool
      inetutils
      iperf
      nftables
      nmap
      tcpdump
      tmate
      wakeonlan
      wget
    ];
    dev-tools = [
      esptool
      minicom
      picocom
      tio
    ];
    apps = [
      emacs
      firefox
      tdesktop
      turbovnc
      zoom-us
    ];
  in
    system-utils ++ network-utils ++ dev-tools ++ apps;

  ### List services that you want to enable:

  services.openssh = {
    enable = true;
  };

  virtualisation = {
    podman.enable = true;
    oci-containers.backend = "podman";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}

