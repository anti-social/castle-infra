{ config, lib, pkgs, ... }:

{
  config = {
    services.udev.extraRules = ''
      # ST-Link
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="660", GROUP="wheel"
    '';
  };
}
