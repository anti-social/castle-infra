# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, lib, pkgs, modulesPath, ... }:
let
  lanIf = "enp11s0";
in {
  deployment = {
    targetHost = "pc";
    allowLocalDeployment = true;
  };

  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      ./another-nix-secrets
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
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
  boot.extraModprobeConfig = ''
    options zfs zfs_arc_max=2147483648
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
          wireguardPeerConfig = {
            PublicKey = "J5OIl0Q3QiWuxfEDYIrJ45rLqlxIdJLMKg5V5XEblgA=";
            AllowedIPs = [ "192.168.51.1" ];
            Endpoint = "api.bagspace.ua:51820";
          };
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

  networking = {
    hostId = "b5695485";
    hostName = "pc"; # Define your hostname.
    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.

    firewall = {
      enable = true;
      connectionTrackingModules = [ "ftp" ];
      interfaces = {
        ${lanIf} = {
         allowedTCPPorts = [
            21
            139 445  # samba
            2342  # photoprism
            5201  # iperf
            5901  # vnc
            9100  # node exporter
          ];
          allowedTCPPortRanges = [
            { from = 10090; to = 11000; }  # ftp
          ];
          allowedUDPPorts = [
            137 138  # samba
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
    extraGroups = [ "libvirtd" "wheel" "wireshark" ];
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
  users.users.alla = {
    uid = 1004;
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
          version = "3.0.91";
          src = pkgs.fetchFromGitHub {
            owner = "TurboVNC";
            repo = "turbovnc";
            rev = version;
            sha256 = "sha256-akkkbDb5ZHTG5GEEeDm1ns60GedQ+DnFXgVMZumRQHc=";
          };

          nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.pkgconfig ];
        }
      );

      # qemu = super.qemu.overrideAttrs (
      #   old: rec {
      #     version = "8.0.2";
      #     src = pkgs.fetchurl {
      #       url = "https://download.qemu.org/qemu-${version}.tar.xz";
      #       sha256 = "8GCr1DX75nlBJeLDmFaP/Dz6VABCWWkHqLGO3KNM9qU=";
      #     };
      #     patches = old.patches ++ [ ./qemu/qemu-anti-cheat-8.0.2.patch ];
      #   }
      # );

      ktlint = super.ktlint.overrideAttrs (
        old: rec {
          version = "1.0.0";
          src = pkgs.fetchurl {
            url = "https://github.com/pinterest/ktlint/releases/download/${version}/ktlint";
            sha256 = "Kz9vZ0qUTSW7jSg8NTmUe76GB0eTASkJpV3kt3H3S8w=";
          };
        }
      );

      python310 = super.python310.override {
        packageOverrides = pyself: pysuper: {
          ansible = pysuper.ansible.overrideAttrs (
            old: rec {
              version = "8.3.0";
              src = pkgs.fetchPypi {
                pname = "ansible";
                version = "8.3.0";
                hash = "sha256-XlgAHX1twz5dFWyjQ4g7YT7JiPaTZLCkP3Ek/ktb4vI=";
              };
            }
          );
          ansible-core = pysuper.ansible-core.overrideAttrs (
            old: rec {
              version = "2.15.4";
              src = pkgs.fetchPypi {
                pname = "ansible-core";
                version = "2.15.4";
                hash = "sha256-waiq7emF955ZMrohY2OTeffYAlv9myg3jbFkmk71Qe0=";
              };
              postPatch = "";
            }
          );
          uvloop = pysuper.uvloop.overrideAttrs (_: {
            doCheck = false;
          });
        };
      };
    })
  ];

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
      });
    rye = ({ lib, fetchFromGithub, rustPlatform, pkgconfig, openssl, libiconv, git }:
      rustPlatform.buildRustPackage rec {
        pname = "rye";
        version = "0.13.0";

        src = fetchFromGitHub {
          owner = "mitsuhiko";
          repo = pname;
          rev = version;
          sha256 = "B53oTAgy+y+FWk7y+unJPt7Mc7m4nwnTX+5wqL6AX+4=";
        };

        cargoLock = {
          lockFile = ./rye/Cargo.lock;
          outputHashes = {
            "dialoguer-0.10.4" = "sha256-WDqUKOu7Y0HElpPxf2T8EpzAY3mY8sSn9lf0V0jyAFc=";
            "monotrail-utils-0.0.1" = "sha256-4x5jnXczXnToU0QXpFalpG5A+7jeyaEBt8vBwxbFCKQ=";
          };
        };

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
      vlc
      wireshark
    ];
    dev = [
      ansible
      async-profiler
      buildah
      cmake
      debootstrap
      diesel-cli
      dive
      docker-compose
      gcc
      gnumake
      gradle
      grpc
      ktlint
      kubectl
      kubelogin-oidc
      (pkgs.callPackage lets {})
      libtool  # to compile emacs libvterm module
      libxcrypt
      multimarkdown
      ninja
      nodejs
      openssl
      openssl.dev
      patchelf
      pkg-config
      podman-compose
      protobuf
      python311Full
      python311Packages.pip-tools
      rustup
      (pkgs.callPackage rye {})
      shellcheck
      wasmtime
      zlib
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
      nmap
      pciutils
      read-edid
      ripgrep
      tmux
      unzip
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

  programs.wireshark.enable = true;

  programs.java = {
    enable = true;
    package = pkgs.openjdk;
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
      dina-font
      input-fonts
      emacs-all-the-icons-fonts
      nerdfonts
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
    securityType = "user";
    extraConfig = ''
      workgroup = CASTLE
      server string = PC
      netbios name = pc
      security = user

      use sendfile = yes

      # max protocol = smb2
      server min protocol = SMB2_10
      client min protocol = SMB2
      client max protocol = SMB3

      # note: localhost is the ipv6 localhost ::1
      hosts allow = 192.168.2. 192.168.102. 127.0.0.1 localhost
      hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      # images = {
      #   path = "/media/data/libvirt";
      #   browseable = "yes";
      #   "read only" = "yes";
      #   "guest ok" = "yes";
      #   "create mask" = "0644";
      #   "directory mask" = "0755";
      #   "force user" = "nobody";
      #   "force group" = "nogroup";
      # };
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
  virtualisation.oci-containers.containers.photoprism = {
    image = "docker.io/photoprism/photoprism:230607";
    environment = {
      PHOTOPRISM_DATABASE_DRIVER = "mysql";
      PHOTOPRISM_DATABASE_SERVER = "/run/mysqld/mysqld.sock";
      PHOTOPRISM_DATABASE_NAME = "photoprism";
      PHOTOPRISM_DATABASE_USER = "photoprism";
      PHOTOPRISM_ADMIN_PASSWORD = "insecure";
      PHOTOPRISM_SITE_URL = "https://photos.castle.mk";
      PHOTOPRISM_UPLOAD_NSFW = "true";
    };
    volumes = [
      "/run/mysqld/mysqld.sock:/run/mysqld/mysqld.sock"
      "/media/important_data/photoprism:/photoprism"
    ];
    user = "500:500";

    # ports = [
    #   "2342:2342"
    # ];
    extraOptions = [ "--network=host" ];
  };
  # systemd.services.podman-photoprism.serviceConfig.User = "photoprism";

  virtualisation = {
    podman = {
      enable = true;

      # Required for containers under podman-compose to be able to talk to each other
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };

    libvirtd = {
      enable = true;
    };
  };

  # Hack to be able to run third-party binaries
  # https://github.com/google/protobuf-gradle-plugin/issues/426#issuecomment-771740235
  system.activationScripts.ldso = lib.stringAfter [ "usrbinenv" ] ''
    mkdir -m 0755 -p /lib64
    ln -sfn ${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2.tmp
    mv -f /lib64/ld-linux-x86-64.so.2.tmp /lib64/ld-linux-x86-64.so.2
  '';

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
