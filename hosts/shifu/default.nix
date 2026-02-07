{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
  ];

  networking.hostName = "shifu";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.15";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/438e198f-c884-4161-9e03-db1bd26ab957";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
