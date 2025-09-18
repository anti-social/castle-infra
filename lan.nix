rec {
  addr_prefix = "192.168.2";
  prefix_length = 24;
  mkAddr = i: "${addr_prefix}.${toString i}";
  mkFQDN = name: "${name}.${domain}";

  domain = "castle";
  network = "${net_addr}/${toString prefix_length}";
  net_mask = "255.255.255.0";
  net_addr = mkAddr 0;
  broadcast_addr = mkAddr 255;
  hosts = {
    gw = {
      mac = "40:21:08:80:03:db";
      ip = mkAddr 1;
      aliases = [ "unifi" "grafana" "home" "mqtt" ];
      # Don't work with home assistant when it tries to reconnect after switching from home network
      # Possibly it don't resolve dns name when reconnecting
      # additionalDomain = "castle.mk";
    };
    pc = {
      # Previous address
      # mac = "18:c0:4d:a4:67:97";
      mac = "74:56:3c:43:9a:36";
      ip = mkAddr 2;
    };
    oldpc = {
      mac = "f8:32:e4:9a:87:da";
      ip = mkAddr 3;
      inetActiveTime = { from = "07:00"; to = "00:00"; };
    };
    minipc = {
      mac = "a6:ff:98:64:78:92";
      ip = mkAddr 4;
    };
    newpc = {
      mac = "18:C0:4d:a4:67:97";
      ip = mkAddr 5;
    };
    nanopc = {
      mac = "c2:92:26:00:ec:f6";
      ip = mkAddr 6;
      aliases = [ "octo"];
    };
    rpi3 = {
      mac = "b8:27:eb:0b:8d:6f";
      ip = mkAddr 7;
    };
    tv = {
      mac = "c4:36:6c:06:73:3e";
      ip = mkAddr 10;
    };
    dell-laptop-lan = {
      mac = "8c:47:be:32:67:10";
      ip = mkAddr 11;
    };
    dell-laptop = {
      mac = "cc:d9:ac:d8:60:7b";
      ip = mkAddr 12;
    };
    flipmoon = {
      mac = "ac:12:03:2d:6e:eb";
      ip = mkAddr 13;
    };
    redmi-1 = {
      mac = "4c:63:71:5a:c1:9d";
      ip = mkAddr 22;
      aliases = ["redmi-ksyusha"];
    };
    redmi-2 = {
      mac = "4c:63:71:5b:0b:00";
      ip = mkAddr 23;
      aliases = ["redmi-nastya"];
    };
    ipad = {
      mac = "e2:2b:94:4a:d0:3d";
      ip = mkAddr 24;
    };
    iphone = {
      mac = "ea:00:77:1a:1b:9c";
      ip = mkAddr 25;
    };
    vacuum = {
      mac = "50:ec:50:1b:d5:ac";
      ip = mkAddr 80;
    };
    boiler = {
      mac = "44:23:7c:ab:9c:07";
      ip = mkAddr 90;
    };
    heat-2 = {
      mac = "5c:e5:0c:0f:13:57";
      ip = mkAddr 91;
    };
    entrance-light = {
      mac = "c4:4f:33:e2:81:3e";
      ip = mkAddr 92;
    };
    bath-fan = {
      mac = "8c:ce:4e:0c:62:37";
      ip = mkAddr 93;
    };
    ap1 = {
      mac = "f0:9f:c2:7c:57:fe";
      ip = mkAddr 241;
    };
    ap2 = {
      mac = "78:8a:20:48:e3:9c";
      ip = mkAddr 242;
    };
    ap3 = {
      mac = "80:2a:a8:46:18:28";
      ip = mkAddr 243;
    };
    ap4 = {
      mac = "1c:0b:8b:c2:9e:dc";
      ip = mkAddr 244;
    };
    flex5 = {
      mac = "94:2a:6f:4e:9d:d5";
      ip = mkAddr 253;
    };
    flex8 = {
      mac = "a8:9c:6c:08:c5:3d";
      ip = mkAddr 254;
      aliases = [ "flex8" ];
    };
  };
}
