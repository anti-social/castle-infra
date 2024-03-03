{ lib, pkgs, ... }:

{
  config = {
    # Hack to be able to run third-party binaries
    # https://github.com/google/protobuf-gradle-plugin/issues/426#issuecomment-771740235
    system.activationScripts.ldso = lib.stringAfter [ "usrbinenv" ] ''
      mkdir -m 0755 -p /lib64
      ln -sfn ${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2.tmp
      mv -f /lib64/ld-linux-x86-64.so.2.tmp /lib64/ld-linux-x86-64.so.2
    '';
  };
}
