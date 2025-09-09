args @ { config, lib, pkgs, modulesPath, home-manager, ... }:
let
  lanIf = "enp13s0";
in {
  deployment = {
    targetHost = "pc";
    allowLocalDeployment = true;
  };

  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      home-manager.nixosModules.home-manager
      ./another-nix-secrets
      ./modules/common.nix
      ./modules/udev.nix
      ./modules/ld-linux.nix
      ./modules/overlays.nix
    ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/52a954ae-2a1f-42cd-b4a3-78249213d9dd";
    fsType = "xfs";
  };

  fileSystems."/efi" = {
    device = "/dev/disk/by-uuid/EB98-AA71";
    fsType = "vfat";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/99bf6dfb-8e78-49ba-96c4-06fe340f9fc6";
    fsType = "xfs";
  };

  fileSystems."/media/backup" = {
    device = "/dev/disk/by-uuid/94cd2049-ce86-48eb-b5f8-da86841c4303";
    fsType = "btrfs";
    options = [ "subvol=backup" ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-uuid/1e47dcce-063e-404b-a2db-a9733b62d7a5";
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usbhid" ];
  boot.initrd.kernelModules = [ "amdgpu" "dm-snapshot" "dm-raid" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelParams = [
    "amdgpu.runpm=0"
    # "drm.edid_firmware=HDMI-A-1:/root/lgtv-edid.bin"
  ];
  boot.extraModulePackages = [ ];
  boot.supportedFilesystems = [ "zfs" ];
  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=${toString (4 * 1024 * 1024 * 1024)}
  '';
  boot.zfs.extraPools = [ "storage" ];

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

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "vm.max_map_count" = 262144;
  };

  services.secrets = {
    passwordFile = "/root/secrets.password";
  };

  systemd.network = {
    enable = true;

    links = {
      lan = {
        matchConfig = {
          OriginalName = lanIf;
        };
        linkConfig = {
          WakeOnLan = "magic";
        };
      };
    };

    netdevs = {
      "10-wg-bagspace" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg-bagspace";
        };
        # See also man systemd.netdev (also contains info on the permissions of the key files)
        wireguardConfig = {
          # Don't use a file from the Nix store as these are world readable.
          PrivateKeyFile = "${config.secretsDestinations.files.wg-bagspace-privkey}";
        };
        wireguardPeers = [{
            PublicKey = "J5OIl0Q3QiWuxfEDYIrJ45rLqlxIdJLMKg5V5XEblgA=";
            AllowedIPs = [ "192.168.51.1" ];
            Endpoint = "api.bagspace.ua:51820";
        }];
      };
    };

    networks = {
      lan = {
        matchConfig = {
          Name = lanIf;
        };
        networkConfig = {
          DHCP = "ipv4";
        };
      };
      wg-bagspace = {
        matchConfig.Name = "wg-bagspace";
        # IP addresses the client interface will have
        address = [
          "192.168.51.5/24"
        ];
        DHCP = "no";
        dns = [ "192.168.51.1" ];
        domains = [ "bagspace.vpn" ];
        networkConfig = {
          IPv6AcceptRA = false;
        };
      };
    };
  };
  services.secrets.files."wg-bagspace-privkey" = {
    file = ./secrets/wg-bagspace-privkey.aes-256-cbc.base64;
    group = "systemd-network";
    mode = "0660";
    beforeService = "sys-subsystem-net-devices-wg-bagspace.device";
  };

  services.resolved = {
    enable = true;
    dnssec = "false";
  };

  networking = {
    hostId = "b5695485";
    hostName = "pc"; # Define your hostname.
    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.

    useDHCP = false;

    networkmanager.enable = true;

    extraHosts = ''
      127.0.0.1 hdfs-namenode-ceph-service
    '';

    firewall = {
      enable = true;
      connectionTrackingModules = [ "ftp" ];
      allowedUDPPorts = [
        53
        24892  # fly-by-wire video stream
      ];
      interfaces = {
        ${lanIf} = {
         allowedTCPPorts = [
            21
            80
            139 445  # samba
            2342  # photoprism
            5201  # iperf
            5901  # vnc
            8080  # home projects
            9100  # node exporter
          ];
          allowedTCPPortRanges = [
            { from = 10090; to = 11000; }  # ftp
            { from = 1714; to = 1764; } # kdeconnect
          ];
          allowedUDPPorts = [
            137 138  # samba
            2021  # bambu-studio
            5201  # iperf
            24893 24894  # firefly
          ];
          allowedUDPPortRanges = [
            { from = 1714; to = 1764; } # kdeconnect
          ];
        };

        # https://github.com/NixOS/nixpkgs/issues/226365#issuecomment-1599540111
        "podman0" = {
          allowedUDPPorts = [ 53 ];
        };

        # Allow DHCP for systemd-nspawn containers
        "ve-+" = {
          allowedUDPPorts = [ 67 ];
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

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      # rocm-opencl-runtime
    ];
  };

  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
    # monitorSection = ''
    #   DisplaySize 1920 1080
    # '';

  };
  services.desktopManager.plasma6.enable = true;

  services.displayManager = {
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

  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.bluetooth.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alexk = ((import ./users.nix) { pkgs = pkgs; }).alexk;
  home-manager.users.alexk = (import ./home/alexk.nix) args;

  users.users.game = {
    uid = 1003;
    isNormalUser = true;
    shell = pkgs.zsh;
  };
  users.users.alla = {
    uid = 1004;
    isNormalUser = true;
    shell = pkgs.zsh;
  };

  nixpkgs.config = {
    allowUnfree = true;
    input-fonts.acceptLicense = true;
  };

  environment.sessionVariables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig";
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";
  };

  # List packages installed in system profile. To search, run: $ nix search wget
  environment.systemPackages = with pkgs; let
    lets = ({}:
      buildGoModule rec {
        pname = "lets";
        version = "0.0.52";

        src = fetchFromGitHub {
          owner = "lets-cli";
          repo = "lets";
          rev = "v${version}";
          hash = "sha256-iYjakrzZ2l00ph2T1gjxPJLI8zXlc5TCMpY4j2oEVzM=";
        };

        vendorHash = "sha256-tIRXQB/gbG8zrZht6RJQ26m4mJQeWb0AxlS1UYNe8V0=";

        meta = with lib; {
          description = "Simple command-line snippet manager, written in Go";

          homepage = "https://github.com/lets-cli/lets";
          license = licenses.mit;
          maintainers = with maintainers; [ maintainers.anti-social ];
        };
      }
    );
    emacs-shell = pkgs.writeShellScriptBin "emacs-shell" ''
      PROJECT_DIR=''${1:?}
      exec nix-shell --run "SHELL=${pkgs.zsh}/bin/zsh exec emacs $PROJECT_DIR" $PROJECT_DIR
    '';
    i3wm = [
      dmenu
      i3
      i3status
      i3blocks
      maim
      turbovnc
      virtualgl
      xclip
      xdotool
      xorg.xkill
      xorg.xsetroot
      xterm
    ];
    apps = [
      alacritty
      betaflight-configurator
      chromium
      emacs
      emacs-shell
      firefox
      kicad
      stm32cubemx
      telegram-desktop
      signal-desktop
      virt-manager
      vlc
      wireshark
    ];
    dev = [
      ansible
      async-profiler
      bear  # generates compile_commands.json for C/C++ projects: bear -- make
      buildah
      ccls
      clang-tools
      clinfo
      cmake
      debootstrap
      delta
      diesel-cli
      dive
      docker-compose
      esptool
      gcc
      gdb
      gnumake
      gradle
      grpc
      ktlint
      kubectl
      kubelogin-oidc
      (pkgs.callPackage lets {})
      libtool  # to compile emacs libvterm module
      libxcrypt
      llvmPackages.libclang
      multimarkdown
      ninja
      nodejs
      openssl
      openssl.dev
      patchelf
      pkg-config
      podman-compose
      protobuf
      pyright
      python312Full
      python312Packages.pip-tools
      rustup
      shellcheck
      stm32flash
      uv
      wasmtime
      zlib
    ];
    tools = [
      awscli2
      bat
      clinfo
      colmena
      curl
      dmidecode
      dnsutils
      ethtool
      fd
      ffmpeg-full
      git
      grpcurl
      hdparm
      htop
      inetutils
      jq
      iperf
      linuxPackages.usbip
      lm_sensors
      mc
      nftables
      nix-index
      nmap
      pciutils
      radeontop
      read-edid
      ripgrep
      tmate
      tmux
      unzip
      update-systemd-resolved
      usbutils
      vulkan-tools
      watchman
      wget
    ];
  in apps ++ dev ++ i3wm ++ tools;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [];
  };

  # Please explicitly use kdePackages.xdg-desktop-portal-kde for the latest Qt 6-based version
  # xdg.portal = {
  #   enable = true;
  #   extraPortals = with pkgs; [
  #     xdg-desktop-portal-kde
  #   ];
  # };

  programs.zsh.enable = true;

  programs.gnupg = {
    agent.enable = true;
  };

  programs.wireshark.enable = true;

  programs.java = {
    enable = true;
    package = pkgs.openjdk;
  };

  programs.steam = {
    enable = true;
  };

  programs.kdeconnect.enable = true;

  fonts = {
    packages = with pkgs; [
      dejavu_fonts
      dina-font
      emacs-all-the-icons-fonts
      fira-code
      fira-code-symbols
      input-fonts
      liberation_ttf
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      noto-fonts
      noto-fonts-emoji
      openmoji-color
      proggyfonts
      ubuntu_font_family
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

  services.flatpak.enable = true;

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

  # services.vsftpd = {
  #   enable = true;
  #   anonymousUser = true;
  #   anonymousUserNoPassword = true;
  #   anonymousUserHome = "/media/data/libvirt";
  #   extraConfig = ''
  #     pasv_enable=Yes
  #     pasv_min_port=10090
  #     pasv_max_port=11000
  #   '';
  # };

  services.samba = {
    enable = true;
    openFirewall = false;
    settings = {
      global = {
        "workgroup" = "CASTLE";
        "server string" = "PC";
        "netbios name" = "pc";
        "security" = "user";

        "use sendfile" = "yes";

        # "max protocol" = "smb2";
        "server min protocol" = "SMB2_10";
        "client min protocol" = "SMB2";
        "client max protocol" = "SMB3";

        # note: localhost is the ipv6 localhost ::1
        "hosts allow" = "192.168.2. 192.168.102. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
      };
      data = {
        path = "/media/data";
        comment = "Media share";
        public = "yes";
        writable = "no";
        "guest ok" = "no";
      };
      pictures = {
        path = "/media/important_data/Images";
        public = "no";
        writable = "no";
        "valid users" = "alexk alla";
      };
      alexk = {
        path = "/media/home/alexk";
        public = "no";
        writable = "yes";
        "valid users" = "alexk";
      };
      alla = {
        path = "/media/home/alla";
        public = "no";
        writable = "yes";
        "valid users" = "alla";
      };
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.drive = {
      locations."~ /drive/(.+)" = {
        root = "/media/share";
        extraConfig = ''
          charset UTF-8;
          autoindex on;

          rewrite ^/drive/(.*)$ /$1;
          if (-e /media/home/alla/public$uri) {
            root /media/home/alla/public;
          }
          break;
        '';
      };
    };
  };

  services.mysql = {
    enable = true;
    # dataDir = "/var/lib/mariadb";
    package = pkgs.mariadb;
    settings = {
      mysqld = {
        bind = "localhost";
      };
    };
    ensureDatabases = [ "photoprism" ];
    ensureUsers = [
      {
        name = "photoprism";
        ensurePermissions = {
          "photoprism.*" = "ALL PRIVILEGES";
        };
      }
    ];
  };
  users.groups.photoprism = {
    gid = 500;
  };
  users.users.photoprism = {
    uid = 500;
    isNormalUser = false;
    group = "photoprism";
    home = "/media/important_data/photoprism";
  };
  # virtualisation.oci-containers.containers.photoprism = {
  #   image = "docker.io/photoprism/photoprism:230607";
  #   environment = {
  #     PHOTOPRISM_DATABASE_DRIVER = "mysql";
  #     PHOTOPRISM_DATABASE_SERVER = "/run/mysqld/mysqld.sock";
  #     PHOTOPRISM_DATABASE_NAME = "photoprism";
  #     PHOTOPRISM_DATABASE_USER = "photoprism";
  #     PHOTOPRISM_ADMIN_PASSWORD = "insecure";
  #     PHOTOPRISM_SITE_URL = "https://photos.castle.mk";
  #     PHOTOPRISM_UPLOAD_NSFW = "true";
  #   };
  #   volumes = [
  #     "/run/mysqld/mysqld.sock:/run/mysqld/mysqld.sock"
  #     "/media/important_data/photoprism:/photoprism"
  #   ];
  #   user = "500:500";

  #   # ports = [
  #   #   "2342:2342"
  #   # ];
  #   extraOptions = [ "--network=host" ];
  # };
  # systemd.services.podman-photoprism.serviceConfig.User = "photoprism";

  virtualisation = {
    podman = {
      enable = true;

      # Required for containers under podman-compose to be able to talk to each other
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    # docker.rootless = {
    #   enable = true;
    #   setSocketVariable = true;
    #   package = pkgs.docker_24;
    #   daemon.settings = {
    #     dns = [ "192.168.10.17" "192.168.2.1" ];
    #   };
    # };

    libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
      };
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
