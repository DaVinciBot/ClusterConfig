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

}
