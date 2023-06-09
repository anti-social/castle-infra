# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, lib, pkgs, modulesPath, ... }:

{
  deployment = {
    targetHost = "pc";
    allowLocalDeployment = true;
  };

  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      # <home-manager/nixos>
    ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/52a954ae-2a1f-42cd-b4a3-78249213d9dd";
      fsType = "xfs";
    };

  fileSystems."/efi" =
    { device = "/dev/disk/by-uuid/EB98-AA71";
      fsType = "vfat";
    };

  fileSystems."/media/data" =
    { device = "/dev/disk/by-uuid/fdca98fe-6273-4f51-99ef-cb375d0a8c28";
      fsType = "ext4";
    };

  fileSystems."/media/important_data" =
    { device = "/dev/disk/by-uuid/30c60db2-6ea8-4380-8a91-52086679b815";
      fsType = "ext4";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/99bf6dfb-8e78-49ba-96c4-06fe340f9fc6";
      fsType = "xfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/1e47dcce-063e-404b-a2db-a9733b62d7a5"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ "amdgpu" "dm-snapshot" "dm-raid" ];
  boot.kernelModules = [ "kvm-amd" ];
  # boot.kernelParams = [ "drm.edid_firmware=HDMI-A-1:/root/lgtv-edid.bin" ];
  boot.extraModulePackages = [ ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  #boot.loader.grub = {
  #  enable = true;
  #  efiSupport = true;
  #  devices = [ "/dev/nvme0n1p1" ];
  #  # devices = [ "/dev/disk/by-uuid/EB98-AA71" "/dev/disk/by-uuid/EC0B-9C0A" ];
  #};
  boot.loader.efi = {
    canTouchEfiVariables = true;
    efiSysMountPoint = "/efi";
  };

  systemd.network.enable = true;
  networking = {
    hostName = "pc"; # Define your hostname.
    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.

    useDHCP = lib.mkDefault true;

    interfaces.enp11s0.wakeOnLan.enable = true;

    firewall = {
      enable = true;
      connectionTrackingModules = [ "ftp" ];
      interfaces = {
        enp11s0 = {
         allowedTCPPorts = [
            21
            5201  # iperf
            5901  # vnc
            9100  # node exporter
          ];
          allowedTCPPortRanges = [
            { from = 10090; to = 11000; }
          ];
        };
      };
    };
  };

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };

  hardware.opengl = {
    enable = true;
    driSupport = true;
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
    # monitorSection = ''
    #   DisplaySize 1920 1080
    # '';

    displayManager = {
      sddm.enable = true;
      # gdm = {
      #   enable = true;
      #   wayland = true;
      # };
      autoLogin = {
        enable = true;
        user = "game";
      };
      # defaultSession = "plasmawayland";
    };
    desktopManager.plasma5.enable = true;
  };

  security.polkit.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  hardware.bluetooth.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alexk = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" ];
    shell = pkgs.zsh;
  };
  # home-manager.users.alexk = { pkgs, ... }: {
  #   # home.packages = [ pkgs.atool pkgs.httpie ];
  #   # programs.bash.enable = true;
  #   programs.home-manager.enable = true;

  #   home.stateVersion = "23.05";
  # };

  users.users.game = {
    uid = 1003;
    isNormalUser = true;
    shell = pkgs.zsh;
  };

  nixpkgs.config = {
    allowUnfree = true;
    input-fonts.acceptLicense = true;
  };

  nixpkgs.overlays = [
    (self: super: {
      turbovnc = super.turbovnc.overrideAttrs (old:
        rec {
          version = "3.0.3";
          src = pkgs.fetchFromGitHub {
            owner = "TurboVNC";
            repo = "turbovnc";
            rev = version;
            sha256 = "sha256-akkkbDb5ZHTG5GEEeDm1ns60GedQ+DnFXgVMZumRQHc=";
          };

          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
        }
      );

      qemu = super.qemu.overrideAttrs (
        old: rec {
          version = "8.0.2";
          src = pkgs.fetchurl {
            url = "https://download.qemu.org/qemu-${version}.tar.xz";
            sha256 = "8GCr1DX75nlBJeLDmFaP/Dz6VABCWWkHqLGO3KNM9qU=";
          };
          patches = old.patches ++ [ ./qemu/qemu-anti-cheat-8.0.2.patch ];
        }
      );

      ktlint = super.ktlint.overrideAttrs (
        old: rec {
          version = "0.49.1";
          src = pkgs.fetchurl {
            url = "https://github.com/pinterest/ktlint/releases/download/${version}/ktlint";
            sha256 = "Kz9vZ0qUTSW7jSg8NTmUe76GB0eTASkJpV3kt3H3S8w=";
          };
        }
      );
    })
  ];

  # List packages installed in system profile. To search, run: $ nix search wget
  environment.systemPackages = with pkgs; let
    rye = ({ lib, fetchFromGithub, rustPlatform, pkgconfig, openssl, libiconv, git }:
      rustPlatform.buildRustPackage rec {
        pname = "rye";
        version = "0.5.0";

        src = fetchFromGitHub {
          owner = "mitsuhiko";
          repo = pname;
          rev = version;
          sha256 = "fMGWxOSMd1q+S6Gm2U+ncPosAk0bdbaEG/0QgzuS5J0=";
        };

        cargoLock = {
          lockFile = ./rye/Cargo.lock;
          outputHashes = {
            "dialoguer-0.10.4" = "sha256-WDqUKOu7Y0HElpPxf2T8EpzAY3mY8sSn9lf0V0jyAFc=";
          };
        };

        patches = [ ./rye/0001-offline-licenses.patch ];

        buildInputs = [
          openssl
        ];
        nativeBuildInputs = [
          pkgconfig
          git
        ];

        env = {
          OPENSSL_NO_VENDOR = 1;
        };

        doCheck = false;

        meta = with lib; {
          description = "Yet another python packages manager";
          homepage = "https://github.com/mitsuhiko/rye";
          license = licenses.unlicense;
          maintainers = [ maintainers.tailhook ];
        };
      });
    i3wm = [
      dmenu
      i3
      i3status
      i3blocks
      turbovnc
      xorg.xkill
      xorg.xsetroot
      xterm
    ];
    apps = [
      alacritty
      chromium
      emacs
      firefox
      telegram-desktop
      virt-manager
      wireshark
    ];
    dev = [
      async-profiler
      cmake
      gcc
      gnumake
      gradle
      grpc
      ktlint
      kubectl
      libtool  # to compile emacs libvterm module
      libxcrypt
      multimarkdown
      nodejs
      patchelf
      protobuf
      python311Full
      rustup
      (pkgs.callPackage rye {})
      shellcheck
    ];
    tools = [
      awscli2
      bat
      colmena
      curl
      dmidecode
      dnsutils
      ethtool
      fd
      git
      grpcurl
      hdparm
      htop
      inetutils
      jq
      iperf
      lm_sensors
      mc
      nix-index
      pciutils
      read-edid
      ripgrep
      tmux
      update-systemd-resolved
      usbutils
      vulkan-tools
      wget
    ];
  in apps ++ dev ++ i3wm ++ tools;

  programs.zsh.enable = true;

  programs.gnupg = {
    agent.enable = true;
  };

  programs.java = {
    enable = true;
    package = pkgs.openjdk17;
  };

  programs.steam = {
    enable = true;
  };

  fonts = {
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      ubuntu_font_family
      proggyfonts
      dejavu_fonts
      input-fonts
    ];

    # enableDefaultFonts = true;
    fontconfig = {
      defaultFonts = {
        serif = [ "Noto Sans" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "Noto Sans Mono" ];
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
  services.openssh.enable = true;

  services.prometheus.exporters = {
    node = {
      enable = true;
    };
  };

  services.openvpn.servers = {
    smartweb  = {
      config = ''
        config /root/openvpn/smartweb.conf

        script-security 2
        up ${pkgs.update-systemd-resolved}/libexec/openvpn/update-systemd-resolved
        down ${pkgs.update-systemd-resolved}/libexec/openvpn/update-systemd-resolved
        '';
      };
  };

  services.vsftpd = {
    enable = true;
    anonymousUser = true;
    anonymousUserNoPassword = true;
    anonymousUserHome = "/media/data/libvirt";
    extraConfig = ''
      pasv_enable=Yes
      pasv_min_port=10090
      pasv_max_port=11000
    '';
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = pc
      netbios name = pc
      security = user
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.2. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      images = {
        path = "/media/data/libvirt";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "nobody";
        "force group" = "nogroup";
      };
    };
  };

  virtualisation = {
    podman = {
      enable = true;
      # defaultNetwork.settings = {
      #   dns_enabled = true;
      # };
    };

    libvirtd = {
      enable = true;
    };
  };

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}