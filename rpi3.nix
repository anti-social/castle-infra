{ config, pkgs, lib, modulesPath, ... }:
{
  deployment = {
    targetHost = "192.168.2.198";
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
  boot.kernelModules = [ "bcm2835-v4l2" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "ext4";
    };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlan0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  ### End of hardware configuration ###


  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  # boot.loader.generic-extlinux-compatible.enable = true;

  boot.loader.raspberryPi.enable = true;
  # Set the version depending on your raspberry pi. 
  boot.loader.raspberryPi.version = 3;
  # We need uboot
  boot.loader.raspberryPi.uboot.enable = true;
  # These two parameters are the important ones to get the
  # camera working. These will be appended to /boot/config.txt.
  boot.loader.raspberryPi.firmwareConfig = ''
    start_x=1
    gpu_mem=256
  '';
 
  # On other boards, pick a different kernel, note that on most boards with good mainline support, default, latest and hardened should all work
  # Others might need a BSP kernel, which should be noted in their respective wiki entries
  
  # nixos-generate-config should normally set up file systems correctly
  # imports = [ ./hardware-configuration.nix ];
  # If not, you can set them up manually as shown below

  networking = {
    hostName = "octo";

    wireless = {
      enable = true;
      networks.Castle.psk = "0459796103";
    };

    firewall = {
      enable = true;
      interfaces = {
        wlan0 = {
          allowedTCPPorts = [ 5000 8080 ];
        };
      };
    };
  };

  services.udev.extraRules = ''
    # allow access to raspi cec device for video group (and optionally register it as a systemd device, used below)
    SUBSYSTEM=="vchiq", GROUP="video", MODE="0660", TAG+="systemd", ENV{SYSTEMD_ALIAS}="/dev/vchiq"
  '';

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
            version = "3.6.2";
            src = self.fetchFromGitHub {
              owner = "cmroche";
              repo = "OctoPrint-HomeAssistant";
              rev = version;
              sha256 = "sha256-oo9OBmHoJFNGK7u9cVouMuBuUcUxRUrY0ppRq0OS1ro=";
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

  users.users.alexk = {
    isNormalUser  = true;
    home  = "/home/alexk";
    extraGroups  = [ "wheel" "video" ];
    openssh.authorizedKeys.keys  = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjh0wyd1lNSvdEKWb1GkFmf5F61i5fWeCm7ENr/W0Vt kovalidis@gmail.com"
    ];
  };
  
  environment.systemPackages = with pkgs; [
    ffmpeg
    htop
    libraspberrypi
    mjpg-streamer
    tmux
    usbutils
  ];

  system.stateVersion = "22.11";
}
