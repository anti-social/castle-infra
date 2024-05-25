{ pkgs }:

{
  alexk = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [ "audio" "dialout" "libvirtd" "networkmanager" "video" "wheel" "wireshark" ];
    shell = pkgs.zsh;
    linger = true;
  };
}
