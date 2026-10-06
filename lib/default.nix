{
  mkNodeExporter = ip: {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = ip;
      port = 9100;
    };
    networking.firewall.trustedInterfaces = [ "tailscale0" ];
    systemd.services.prometheus-node-exporter = {
      after = [ "sys-subsystem-net-devices-tailscale0.device" ];
      bindsTo = [ "sys-subsystem-net-devices-tailscale0.device" ];
    };
  };
}
