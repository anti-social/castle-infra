{ pkgs }:

{
  alexk = {
    uid = 1000;
    subUidRanges = [ { startUid = 100000; count = 65536; } ];
    subGidRanges = [ { startGid = 100000; count = 65536; } ];
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
