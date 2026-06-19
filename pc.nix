args @ { config, lib, pkgs, modulesPath, home-manager, agenix, utils, ... }:
let
  lanIf = "enp14s0";
in {
  deployment = {
    targetHost = "pc";
    allowLocalDeployment = true;
  };

  imports =
    [ # Include the results of the hardware scan.
      (modulesPath + "/installer/scan/not-detected.nix")
      home-manager.nixosModules.home-manager
      agenix.nixosModules.default
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

  fileSystems."/media/var" = {
    device = "/dev/disk/by-uuid/ba5b0d97-82b4-48f1-9f01-ed4b59f04ca6";
    fsType = "btrfs";
  };
  fileSystems."/home/alexk/.local/share/containers" = {
    device = "/dev/disk/by-uuid/ba5b0d97-82b4-48f1-9f01-ed4b59f04ca6";
    fsType = "btrfs";
    options = [ "subvol=containers" ];
  };


  fileSystems."/media/data" = {
    device = "/dev/disk/by-uuid/94cd2049-ce86-48eb-b5f8-da86841c4303";
    fsType = "btrfs";
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
  boot.zfs = {
    extraPools = [ "storage" ];
    forceImportRoot = false;
  };

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
            PersistentKeepalive = 25;
        }];
      };
      "10-wg-firefly" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg-firefly";
        };
        # See also man systemd.netdev (also contains info on the permissions of the key files)
        wireguardConfig = {
          # Don't use a file from the Nix store as these are world readable.
          PrivateKeyFile = "${config.secretsDestinations.files.wg-firefly-privkey}";
        };
        wireguardPeers = [{
            PublicKey = "8TZmhsAgpMD+8q1gmLMR4r1jlw7R+cBmp0LSc6ctkEQ=";
            AllowedIPs = [ "10.248.0.0/16" ];
            Endpoint = "firefly.castle.mk:24801";
            PersistentKeepalive = 25;
        }];
      };
    };

    networks = {
      lan = {
        matchConfig = {
          Name = lanIf;
        };
        # networkConfig = {
        #   DHCP = "ipv4";
        # };
        address = [
          "192.168.2.2/24"
          "10.248.0.2/24"
        ];
        networkConfig = {
          # DNS = ["192.168.2.1" "fe80::5835:30ff:fe93:4e30"];
          DNS = ["192.168.2.1"];
          Gateway = "192.168.2.1";
          IPv6AcceptRA = false;
          LinkLocalAddressing = "no";
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
      wg-firefly = {
        matchConfig.Name = "wg-firefly";
        # IP addresses the client interface will have
        address = [
          "10.248.254.2/32"
        ];
        DHCP = "no";
        networkConfig = {
          IPv6AcceptRA = false;
        };
        routes = [
          {
            Gateway = "10.248.254.1";
            GatewayOnLink = "yes";
            Destination = "10.248.0.0/16";
            PreferredSource = "10.248.254.2";
          }
        ];
      };
    };
  };
  services.secrets.files."wg-bagspace-privkey" = {
    file = ./secrets/wg-bagspace-privkey.aes-256-cbc.base64;
    group = "systemd-network";
    mode = "0660";
    beforeService = "sys-subsystem-net-devices-wg-bagspace.device";
  };
  services.secrets.files."wg-firefly-privkey" = {
    file = ./secrets/wg-pc-firefly-privkey.aes-256-cbc.base64;
    group = "systemd-network";
    mode = "0660";
    beforeService = "sys-subsystem-net-devices-wg-firefly.device";
  };

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSSEC = "false";
      };
    };
  };

  networking = {
    hostId = "b5695485";
    hostName = "pc"; # Define your hostname.
    # Pick only one of the below networking options.
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.

    useDHCP = false;

    networkmanager = {
      enable = true;
      unmanaged = [ lanIf ];
    };

    extraHosts = ''
      127.0.0.1 hdfs-namenode-ceph-service
    '';

    nftables.enable = true;
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
            69  # tftp
            137 138  # samba
            2021  # bambu-studio
            5201  # iperf
            5353  # mdns
            24893 24894  # firefly
          ];
          allowedUDPPortRanges = [
            { from = 1714; to = 1764; } # kdeconnect
          ];
        };
        "wg-firefly" = {
          allowedUDPPorts = [
            5201  # iperf
            24893 24894  # firefly
          ];
        };

        # https://github.com/NixOS/nixpkgs/issues/226365#issuecomment-1599540111
        "podman0" = {
          allowedUDPPorts = [ 53 ];
        };

        # Allow DHCP for systemd-nspawn containers
        "ve-*" = {
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
    autoSubUidGidRange = false;
    isNormalUser = true;
    shell = pkgs.zsh;
  };
  users.users.alla = {
    uid = 1004;
    autoSubUidGidRange = false;
    isNormalUser = true;
    shell = pkgs.zsh;
  };
  users.groups.nopasswdlogin = {
    members = ["game"];
  };
  # TODO: Find out a better way to add a rule
  security.pam.services.sddm.text = lib.mkForce ''
    auth      sufficient    pam_succeed_if.so user ingroup nopasswdlogin
    auth      substack      login
    account   include       login
    password  substack      login
    session   include       login
  '';

  nixpkgs.config = {
    allowUnfree = true;
    input-fonts.acceptLicense = true;
  };

  nixpkgs.overlays = [
    (final: prev: {
      aml1 = (prev.aml.overrideAttrs (old: rec {
        version = "1.0.0";
        src = prev.fetchFromGitHub {
          owner = "any1";
          repo = "aml";
          rev = "v${version}";
          hash = "sha256-10gm6YphZrpLShj3NUj/AG24dSVLZAZbbnXr7GiF4DI=";
        };
      }));
      neatvnc1 = (prev.aml.overrideAttrs (old: rec {
        version = "1.0.0";
        src = prev.fetchFromGitHub {
          owner = "any1";
          repo = "neatvnc";
          rev = "v${version}";
          hash = "sha256-yEWNiazRxc8G7ToqOcTtCXEuBCgXO64v31Xx1YeOPCM=";
        };
        buildInputs = with prev; [
          final.aml1
          ffmpeg
          gnutls
          libjpeg_turbo
          libgbm
          pixman
          zlib
        ];
      }));
      wayvnc = (prev.wayvnc.overrideAttrs (old: rec {
        version = "0.10.0";
        src = prev.fetchFromGitHub {
          owner = "any1";
          repo = "wayvnc";
          rev = "v${version}";
          hash = "sha256-+CAH2jcIIQqImonWeWxMQyTtEEuuQlaGyl/ajPfClh8=";
        };
        buildInputs = with prev; [
          final.aml1
          jansson
          libxkbcommon
          libgbm
          final.neatvnc1
          pam
          pixman
          wayland
        ];
      }));
    })
  ];

  # environment.etc."gai.conf".text = ''
  #   precedence ::ffff:0:0/96  100
  # '';
  
  environment.sessionVariables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.zlib.dev}/lib/pkgconfig";
    LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib";
  };

  # List packages installed in system profile. To search, run: $ nix search wget
  environment.systemPackages = with pkgs; let
    lets = ({}:
      buildGoModule rec {
        pname = "lets";
        version = "0.0.61";

        src = fetchFromGitHub {
          owner = "lets-cli";
          repo = "lets";
          rev = "v${version}";
          hash = "sha256-AoANBxpOouasOe1EFmt75hqf+2IJqEpFOAsIQe+nuzc=";
        };

        vendorHash = "sha256-1H8eiRvS0Z3whY5EsPpnlbMzOTWdt3YpAtcYT96RU4A=";

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
      xkill
      xsetroot
      xterm
    ];
    apps = [
      alacritty
      betaflight-configurator
      chromium
      emacs
      emacs-shell
      firefox
      orca-slicer
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
      picotool
      pkg-config
      podman-compose
      protobuf
      pyright
      python313
      python313Packages.pip-tools
      ragenix
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
      btop-rocm
      clinfo
      colmena
      curl
      dmidecode
      dnsutils
      ethtool
      fd
      ffmpeg-full
      git
      graphviz
      grpcurl
      hdparm
      htop
      inetutils
      jq
      iperf
      llama-cpp-rocm
      linuxPackages.usbip
      lm_sensors
      mc
      nftables
      nix-index
      nix-du
      nix-tree
      nmap
      nvme-cli
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

  nixpkgs.config.permittedInsecurePackages = [
    "python3.12-ecdsa-0.19.1" # used by esptool
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [];
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];
    config.common.default = ["kde"];
  };

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
      noto-fonts
      nerd-fonts._0xproto
      nerd-fonts.droid-sans-mono
      nerd-fonts.liberation
      nerd-fonts.ubuntu-mono
      noto-fonts-color-emoji
      openmoji-color
      proggyfonts
      ubuntu-classic
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

        askpass /root/openvpn/smartweb.pass
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
        path = "/media/home/pictures";
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

  systemd.services.llama-cpp = {
    description = "LLaMA C++ server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "idle";
      KillSignal = "SIGINT";
      StateDirectory = "llama-cpp";
      CacheDirectory = "llama-cpp";
      WorkingDirectory = "/var/lib/llama-cpp";
      Environment = [
        "LLAMA_CACHE=/var/cache/llama-cpp"
        "ROCR_VISIBLE_DEVICES=0"
      ];
      ExecStart =
        let
          args = [
            "--host" "127.0.0.1"
            "--port" "11080"
            "--fit" "on"
            "--fit-target" "1024"
            "--models-preset" "/media/var/llama-cpp/models/presets.ini"
          ];
        in
        "${pkgs.llama-cpp-rocm}/bin/llama-server ${utils.escapeSystemdExecArgs args}";
      Restart = "on-failure";
      RestartSec = 300;

      # for GPU acceleration
      PrivateDevices = false;

      # hardening
      DynamicUser = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      NoNewPrivileges = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      SystemCallErrorNumber = "EPERM";
      ProtectProc = "invisible";
      ProtectHostname = true;
      ProcSubset = "pid";
    };
  };
  # services.llama-cpp = {
  #   enable = true;
  #   package = pkgs.llama-cpp-rocm;
  #   # modelsDir = "/media/data/ai/llama-cpp";
  #   environment = {
  #     ROCR_VISIBLE_DEVICES = "0";
  #   };
  #   modelsPreset = {
  #     "Qwen3.6-35B-A3B-UD-Q4_K_M" = {
  #       model = "/media/data/ai/llama-cpp/Qwen3.6-35B-A3B-UD-Q4_K_M.gguf";
  #       n-gpu-layers = 10;
  #     };
  #   };
  # };
  virtualisation.oci-containers.containers.open-webui = {
    image = "ghcr.io/open-webui/open-webui:0.9.6";
    environment = {
      PORT = "11081";
    };
    networks = [ "host" ];
    volumes = [
      "open-webui:/app/backend/data"
    ];
  };
  services.nginx.virtualHosts."llm.castle" = {
    extraConfig = ''
      client_max_body_size 10m;
      proxy_buffering off;
    '';
    locations."/" = {
      proxyPass = "http://localhost:11081";
      proxyWebsockets = true;
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

  # systemd.services.backup-mount = {
  #   description = "Backup user backups";
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "zfs-mount.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  #   script = ''
  #     ${pkgs.coreutils}/bin/echo "Mounting backups..."
  #     for snapshot in \
  #       $(${pkgs.zfs}/bin/zfs list -H -t snapshot -o name -S creation storage/home)
  #     do
  #       ${pkgs.coreutils}/bin/echo "Mounting snapshot: $snapshot"
  #       SNAPSHOT_NAME=''${snapshot#storage/home@}
  #       SNAPSHOT_USER_DIR=/media/home/alla/%backup%/''${SNAPSHOT_NAME}
  #       ${pkgs.coreutils}/bin/mkdir -p ''${SNAPSHOT_USER_DIR}
  #       /run/wrappers/bin/mount -o bind /media/home/.zfs/snapshot/''${SNAPSHOT_NAME} ''${SNAPSHOT_USER_DIR}
  #     done
  #   '';
  # };
  systemd.services.backup = {
    description = "Backup user datastores";
    serviceConfig = {
      Type = "oneshot";
    };
    startAt = "*-*-* 3:15:00";
    script = ''
      ${pkgs.coreutils}/bin/echo "Creating snapshot..."
      BACKUP_DT=$(${pkgs.coreutils}/bin/date +'%Y-%m-%d_%H-%M-%S')
      SNAPSHOT=storage/home@''${BACKUP_DT}
      ${pkgs.zfs}/bin/zfs snapshot $SNAPSHOT
      ${pkgs.coreutils}/bin/echo "Snapshot created: $SNAPSHOT"

      ${pkgs.coreutils}/bin/mkdir -p /media/home/alla/%backup%/''${BACKUP_DT}
      ${pkgs.coreutils}/bin/echo "Starting backup..."
      ${pkgs.rsync}/bin/rsync -ah \
        --one-file-system \
        --exclude=/%backup% \
        --delete-after \
        --verbose \
        /media/home/.zfs/snapshot/''${BACKUP_DT}/alla/ /media/backup/alla/current

      # Unmount the snapshot to not pollute 'df' output
      ${pkgs.util-linux}/bin/umount /media/home/.zfs/snapshot/$BACKUP_DT

      ${pkgs.coreutils}/bin/echo "Cleaning up old snapshots..."
      for snapshot in \
        $(${pkgs.zfs}/bin/zfs list -H -t snapshot -o name -S creation storage/home | tail -n +31)
      do
        ${pkgs.coreutils}/bin/echo "Destroying snapshot: $snapshot"
        ${pkgs.zfs}/bin/zfs destroy $snapshot
      done
    '';
  };

  virtualisation = {
    podman = {
      enable = true;

      # Required for containers under podman-compose to be able to talk to each other
      defaultNetwork.settings = {
        dns_enabled = true;
      };
    };

    oci-containers.backend = "podman";

    containers.containersConf.settings = {
      engine = {
        cgroup_manager = "cgroupfs";
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
