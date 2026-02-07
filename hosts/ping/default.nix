{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
  ];

  networking.hostName = "ping";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.13";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/16222caa-fcee-4c0d-9eab-b6abb6a2350c";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
