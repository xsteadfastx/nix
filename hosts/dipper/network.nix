_: {
  networking = {
    useNetworkd = true;
    useDHCP = false;
  };

  systemd.network = {
    enable = true;
    networks."10-uplink" = {
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      address = [
        "2a01:4f8:1c1c:1f0a::1/64"
      ];
      routes = [
        {
          Gateway = "172.31.1.1";
          GatewayOnLink = true;
        }
        {
          Gateway = "fe80::1";
        }
      ];
    };
  };
}
