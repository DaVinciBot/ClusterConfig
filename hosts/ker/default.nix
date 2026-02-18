{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/tunnel.nix
  ];

  services.clusterTunnel.secretName = "tunnel_ker";

  networking.hostName = "ker";
  networking.interfaces.wlo1.ipv4.addresses = [ {
    address = "192.168.1.10";
    prefixLength = 24;
  } ];


  networking.defaultGateway = "192.168.1.1";

  fileSystems."/media/ssd1" = lib.mkForce {
    device = "/dev/disk/by-uuid/41bc848a-7ff6-45c7-8fe1-e49d4a76028a";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };

}
