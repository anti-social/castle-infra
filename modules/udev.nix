{ config, lib, pkgs, ... }:

{
  config = {
    services.udev.extraRules = ''
      # ST-Link
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="660", GROUP="dialout"

      # STMicroelectronics STM Device in DFU Mode
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE="660", GROUP="dialout"

      # WCH-Link
      SUBSYSTEMS=="usb", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="8012", MODE="660", GROUP="dialout"
    '';
  };
}
