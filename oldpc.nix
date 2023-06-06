# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running `nixos-help`).

{ config, pkgs, lib, modulesPath, ... }:

{
  deployment = {
    targetHost = "oldpc.castle";
    targetUser = "root";
  };

  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e1118175-a517-48d9-a740-90d3c26be93e";
      fsType = "ext4";
    };

  fileSystems."/efi" =
    { device = "/dev/disk/by-uuid/2FF3-AAC5";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/f9cad69e-8a0b-4393-ab88-79bf87b28715"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
  boot.kernelParams = [ "mitigations=off" "intel_iommu=on" "vfio-pci.ids=1002:73ff,1002:ab28,8086:a12f" ];
  boot.extraModulePackages = [ ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.efiSysMountPoint = "/efi";

  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  networking = {
    hostName = "oldpc"; # Define your hostname.



    firewall = {
      enable = false;
    };
  };
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Kyiv";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    # keyMap = "us";
    useXkbConfig = true; # use xkbOptions in tty.
  };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  sound.enable = true;
  #hardware.pulseaudio = {
  #  enable = true;
  #  systemWide = true;
  #};

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alexk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bat
    cifs-utils
    curl
    hdparm
    htop
    iperf
    lm_sensors
    mc
    pciutils
    ripgrep
    tmux
    usbutils
    wget

    (python311.withPackages(ps: with ps; [ libvirt ]))
  ];

  programs.zsh.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  security.polkit.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.prometheus.exporters = {
    node.enable = true;
  };

  systemd.services.win10 = {
    restartIfChanged = false;

    # wantedBy = lib.mkForce [];
    wantedBy = [ "multi-user.target" "suspend.target" ];
    requires = [ "libvirt-guests.service" ];
    after = [ "libvirt-guests.service" "suspend.target" ];

    serviceConfig = let
      qemuDataDir = "/run/libvirt/qemu";
      virsh = "${pkgs.libvirt}/bin/virsh";
      bash = "${pkgs.bash}/bin/bash";
      systemctl = "${pkgs.systemd}/bin/systemctl";

      vmManager = pkgs.writers.writePython3 "vm_manager.py" {
        libraries = [ pkgs.python3Packages.libvirt ];
      } ''
        import sys
        import time

        import libvirt


        if __name__ == "__main__":
            if len(sys.argv) < 3:
                raise SystemExit("Required 2 arguments: vm name and a command")

            vm_name = sys.argv[1]
            cmd = sys.argv[2]

            with libvirt.open("qemu:///system") as virt_conn:
                try:
                    vm = virt_conn.lookupByName(vm_name)
                except libvirt.libvirtError as e:
                    raise SystemExit(f"Error when looking up a VM: {e}")

                match cmd:
                    case "start":
                        if vm.state()[0] != libvirt.VIR_DOMAIN_RUNNING:
                            print(f"Starting a VM: {vm_name}")
                            vm.create()
                    case "stop":
                        if vm.state()[0] == libvirt.VIR_DOMAIN_RUNNING:
                            print(f"Stopping a VM: {vm_name}")
                            vm.shutdown()
                            for i in range(60):
                                if vm.state()[0] == libvirt.VIR_DOMAIN_SHUTOFF:
                                    break
                                time.sleep(1)
                            else:
                                raise SystemExit(
                                    f"Timeout shutting down a VM: {vm_name}"
                                )
                            print(f"VM {vm_name} was stopped")
                    case _:
                        raise SystemExit(f"Unknown command: {cmd}")
      '';
    in {
      Type = "forking";
      PIDFile = "${qemuDataDir}/win10.pid";
      ExecStart = "${vmManager} win10 start";
      ExecStop = "${vmManager} win10 stop";
      ExecStopPost = ''${bash} -c ''\'if [ "''$SERVICE_RESULT" = "success" ] && [ ! -f "${qemuDataDir}/no-poweroff" ]; then ${systemctl} poweroff; fi''\''';
      TimeoutStartSec = 30;
      TimeoutStopSec = 90;
    };
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.verbatimConfig = ''
        nvram = [
          "/run/libvirt/nix-ovmf/OVMF_CODE.fd:/run/libvirt/nix-ovmf/OVMF_VARS.fd"
        ]
      '';
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
