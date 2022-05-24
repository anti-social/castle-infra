{
  nixie = { modulesPath, lib, name, ... }:
  {
    imports = lib.optional (builtins.pathExists ./do-userdata.nix) ./do-userdata.nix ++ [
      (modulesPath + "/virtualisation/digital-ocean-config.nix")
    ];

    deployment = {
      targetHost = "164.92.183.176";
      targetUser = "root";
    };

    networking.hostName = name;
  };
}
