{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
  ];

  networking.hostName = "oogway";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.14";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/006342c8-3bb9-4b9f-8567-89e52a3c203b";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
