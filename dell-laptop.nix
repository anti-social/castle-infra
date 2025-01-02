args @ { config, lib, pkgs, modulesPath, home-manager, ... }: let
  lan = import ./lan.nix;
in {
  deployment = {
    targetHost = "dell-laptop";
    allowLocalDeployment = true;
  };

  ### Hardware configuration ###

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    home-manager.nixosModules.home-manager
    ./modules/common.nix
    ./modules/udev.nix
    ./modules/ld-linux.nix
    ./modules/overlays.nix
  ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ rtl88xxau-aircrack ];
  boot.supportedFilesystems = [ "ntfs" ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/00a980b8-4a96-489e-8b01-d841f74e83c2";
      fsType = "xfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/1167-4934";
      fsType = "vfat";
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/48d47520-2a5c-4650-9018-9d56c8e056dc";
      fsType = "xfs";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/3e8ee286-3bcd-41ca-b238-55aa092155ca"; }
    ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  ### End of hardware configuration ###


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  #boot.loader.grub = {
  #  enable = true;
  #  enableCryptodisk = true;
  #  efiSupport = true;
  #};

  # boot.initrd = {
  #   kernelModules = 
  # };
  boot.initrd.luks.devices = {
    lvmcrypt = {
      device = "/dev/nvme0n1p2";
      allowDiscards = true;
      preLVM = true;
    };
  };

  networking.hostName = "dell-laptop"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Set your time zone.
  time.timeZone = "Europe/Kiev";

  networking.networkmanager.enable = true;

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;
  # networking.interfaces.wlp0s20f3.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  networking.extraHosts = ''
    # 192.168.122.50 app.example.com
  '';

  services.resolved = {
    enable = true;
    dnssec = "false";
  };

  # Select internationalisation properties.
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "uk_UA.UTF-8/UTF-8"
    ];
  };
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };


  services.logind.killUserProcesses = true;


  # Enable the X11 windowing system.
  services.xserver.enable = true;


  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager = {
    sddm.enable = true;
    autoLogin = {
      enable = true;
      # TODO: Make username a value
      user = "alexk";
    };
  };
  services.xserver.desktopManager.plasma5.enable = true;
  

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.cnijfilter2
    pkgs.gutenprint
    pkgs.gutenprintBin
    pkgs.hplipWithPlugin
  ];

  # Sound configuration
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  };

  # Enable bluetooth.
  hardware.bluetooth.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  virtualisation.libvirtd = {
    enable = true;
  };
  programs.virt-manager.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alexk = ((import ./users.nix) { pkgs = pkgs; }).alexk;
  home-manager.users.alexk = (import ./home/alexk.nix) args;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; let
    build-essentials = [
      cmake
      gnumake
      libtool  # to compile emacs libvterm module
    ];
  in build-essentials ++ [
    ansible
    appimage-run
    bambu-studio
    # bandwich
    bat
    betaflight-configurator
    # blender
    bottom
    chromium
    cloud-init
    cloud-utils
    colmena
    # cura
    # darktable
    delta
    dnsutils
    du-dust
    emacs
    esptool
    ethtool
    eza
    fd
    file
    firefox
    gcc
    git
    glxinfo
    # graalvm-ce
    graphviz
    grex
    htop
    inav-configurator
    inetutils
    iperf
    # ipython
    jql
    krdc
    kubectl
    libguestfs
    linuxPackages.usbip
    lm_sensors
    mc
    meld
    networkmanager-openvpn
    nix-du
    nix-index
    nmap
    # nomachine-client
    nushell
    okular
    openvpn
    p7zip
    podman
    podman-compose
    procs
    prusa-slicer
    python311
    python311Packages.ipython
    qbittorrent
    ripgrep
    ripgrep-all
    rustup
    sd
    signal-desktop
    starship
    tdesktop
    tmate
    tmux
    tokei
    turbovnc
    unrar
    unzip
    usbutils
    vim
    virt-manager
    vlc
    # vscode
    vscodium
    vulkan-tools
    uv
    wakeonlan
    wget
    # wine
    wireguard-tools
    wireshark
    xh
    xorg.xdpyinfo
    xorg.xkill
    zoom-us
    zsh

    # KDE
    ark
    kate

    # (pkgs.callPackage ./pkgs/hello {})
    # (pkgs.callPackage /home/alexk/projects/nix/hello {})
    # (pkgs.callPackage /home/alexk/projects/nix/vagga {})
  ];

  fonts = {
    packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
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
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  systemd.services.usbipd = {
    enable = true;
    description = "Exports USB devices";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 1;
      ExecStart = "${pkgs.linuxPackages.usbip}/bin/usbipd";
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  networking = {
    nftables.enable = true;

    firewall = {
      checkReversePath = false;

      allowedUDPPorts = [
        24892
      ];
      extraInputRules = ''
        # Usbip devices attaching
        tcp dport 3240 ether saddr == ${lan.hosts.pc.mac} accept
        # Bambu-studio
        udp dport 2021 ip saddr == 192.168.2.0/24 accept
      '';
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # trusted-users = [ "alexk" ];
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
