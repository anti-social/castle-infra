{ config, pkgs, lib, modulesPath, ... }:
{
  deployment = {
    targetHost = "192.168.2.198";
    targetUser = "root";
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
  boot.loader.generic-extlinux-compatible.enable = true;
 
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
          allowedTCPPorts = [ 5000 ];
        };
      };
    };
  };

  services.openssh.enable = true;

  services.octoprint = {
    enable = true;
    plugins = plugins: [
      plugins.psucontrol
    ];
  };

  users.users.alexk = {
    isNormalUser  = true;
    home  = "/home/alexk";
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys  = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGjh0wyd1lNSvdEKWb1GkFmf5F61i5fWeCm7ENr/W0Vt kovalidis@gmail.com"
    ];
  };
  
  environment.systemPackages = with pkgs; [
    htop
    libraspberrypi
    tmux
    usbutils
  ];

  system.stateVersion = "22.11";
}
