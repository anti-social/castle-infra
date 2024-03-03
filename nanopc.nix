{ config, lib, pkgs, modulesPath, ... }:
let
  lanIf = "end0";
in {
  deployment = {
    targetHost = "nanopc.castle";
    targetUser = "root";
    keys."secrets.password" = {
      destDir = "/root";
      keyCommand = [ "cat" "secrets.password" ];
    };
  };


  ### Hardware configuration ###

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e064e662-cb44-40ef-ad55-7b40836af5fb";
      fsType = "ext4";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  ### End of hardware configuration ###


  # Use the extlinux boot loader. (NixOS wants to enable GRUB by default)
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  networking = {
    hostName = "nanopc"; # Define your hostname.
    # Pick only one of the below networking options.
    # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  };

  systemd.network = {
    enable = true;

    networks = {
      lan = {
        matchConfig = {
          Name = lanIf;
        };
        networkConfig = {
          DHCP = "ipv4";
        };
      };
    };
  };

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

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

  # Enable the X11 windowing system.
  # services.xserver = {
  #   enable = true;
  #
  #   # Enable touchpad support (enabled default in most desktopManager).
  #   libinput.enable = true;
  #
  #   desktopManager = {
  #       lxqt.enable = true;
  #   };
  #   displayManager.defaultSession = "lxqt";
  # };


  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  security.sudo.wheelNeedsPassword = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # turbovnc
    wget
  ];

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

  nixpkgs.overlays = [
    (self: super: {
      octoprint = super.octoprint.override {
        packageOverrides = pyself: pysuper: {
          octoprint-prettygcode = pyself.buildPythonPackage rec {
            pname = "PrettyGCode";
            version = "1.2.4";
            src = self.fetchFromGitHub {
              owner = "Kragrathea";
              repo = "OctoPrint-PrettyGCode";
              rev = "v${version}";
              sha256 = "sha256-q/B2oEy+D6L66HqmMkvKfboN+z3jhTQZqt86WVhC2vQ=";
            };
            propagatedBuildInputs = [ pysuper.octoprint ];
            doCheck = false;
          };
          octoprint-homeassistant = pyself.buildPythonPackage rec {
            pname = "HomeAssistant";
            version = "3.7.0";
            src = self.fetchFromGitHub {
              owner = "cmroche";
              repo = "OctoPrint-HomeAssistant";
              rev = version;
              sha256 = "sha256-R6ayI8KHpBSR2Cnp6B2mKdJGHaxTENkOKvbvILLte2E=";
            };
            propagatedBuildInputs = [ pysuper.octoprint ];
            doCheck = false;
          };
        };
      };
    })
  ];
  services.octoprint = {
    enable = true;
    openFirewall = true;
    plugins = plugins: with plugins; [
      bedlevelvisualizer
      mqtt
      psucontrol
      octoprint-prettygcode
      octoprint-homeassistant
    ];
  };
  users.users.octoprint = {
    isNormalUser = false;
    extraGroups = [ "video" ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.11"; # Did you read the comment?
}
