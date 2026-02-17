{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/tunnel.nix
  ];

  services.clusterTunnel.secretName = "tunnel_ker";

  networking.hostName = "ker";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.10";
    prefixLength = 24;
  } ];
}
