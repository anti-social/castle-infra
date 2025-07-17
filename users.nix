{ pkgs }:

{
  alexk = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "audio"
      "dialout"
      "libvirtd"
      "networkmanager"
      "podman"
      "video"
      "wheel"
      "wireshark"
    ];
    shell = pkgs.zsh;
    linger = true;
  };
}
