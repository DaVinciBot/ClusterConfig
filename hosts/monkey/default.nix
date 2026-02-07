{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
  ];

  networking.hostName = "monkey";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.16";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/5e1fdbfd-0f94-4278-9633-da651ad9e90c";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
