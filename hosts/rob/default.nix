{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
    ../../modules/services/k3s/node.nix
    ../../modules/services/rustfs.nix
    ../../modules/services/ntp.nix
  ];

  networking.hostName = "rob";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.11";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = lib.mkForce {
    device = "/dev/disk/by-uuid/eb5fc298-4f97-4c37-87a1-79e57f532df5";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
