rec {
  domain = "castle";
  addr_prefix = "192.168.2";
  mkAddr = i: "${addr_prefix}.${toString i}";
  mkFQDN = name: "${name}.${domain}";
  hosts = [
    {
      host = "gw";
      mac = "40:21:08:80:03:db";
      ip = mkAddr(1);
      aliases = [ "unifi" "grafana" "home" "mqtt" ];
    }
    {
      host = "pc";
      mac = "36:01:ca:37:a7:10";
      ip = mkAddr(2);
    }
    {
      host = "oldpc";
      mac = "f8:32:e4:9a:87:da";
      ip = mkAddr(3);
    }
    {
      host = "tv";
      mac = "c4:36:6c:06:73:3e";
      ip = mkAddr(10);
    }
    {
      host = "laptop";
      mac = "8c:47:be:32:67:10";
      ip = mkAddr(11);
    }
    {
      host = "laptop-wifi";
      mac = "cc:d9:ac:d8:60:7b";
      ip = mkAddr(12);
    }
    {
      host = "flipmoon";
      mac = "ac:12:03:2d:6e:eb";
      ip = mkAddr(13);
    }
    {
      host = "huawei-p10";
      mac = "30:74:96:46:1f:f9";
      ip = mkAddr(21);
    }
    {
      host = "redmi-1";
      mac = "4c:63:71:5a:c1:9d";
      ip = mkAddr(22);
      aliases = ["redmi-ksyusha"];
    }
    {
      host = "redmi-2";
      mac = "4c:63:71:5b:0b:00";
      ip = mkAddr(23);
      aliases = ["redmi-nastya"];
    }
    {
      host = "ipad";
      mac = "e2:2b:94:4a:d0:3d";
      ip = mkAddr(24);
    }
    {
      host = "iphone";
      mac = "ea:00:77:1a:1b:9c";
      ip = mkAddr(25);
    }
    {
      host = "vacuum";
      mac = "50:ec:50:1b:d5:ac";
      ip = mkAddr(80);
    }
    {
      host = "boiler";
      mac = "44:23:7c:ab:9c:07";
      ip = mkAddr(90);
    }
    {
      host = "heat-2";
      mac = "5c:e5:0c:0f:13:57";
      ip = mkAddr(91);
    }
    {
      host = "entrance-light";
      mac = "c4:4f:33:e2:81:3e";
      ip = mkAddr(92);
    }
    {
      host = "bath-fan";
      mac = "8c:ce:4e:0c:62:37";
      ip = mkAddr(93);
    }
    {
      host = "ap1";
      mac = "f0:9f:c2:7c:57:fe";
      ip = mkAddr(241);
    }
    {
      host = "ap2";
      mac = "78:8a:20:48:e3:9c";
      ip = mkAddr(242);
    }
    {
      host = "ap3";
      mac = "80:2a:a8:46:18:28";
      ip = mkAddr(243);
    }
    {
      host = "switch";
      mac = "bc:67:1c:c8:f2:3d";
      ip = mkAddr(254);
      aliases = [ "cisco" ];
    }
  ];
}
