{ config, pkgs, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
    ../../modules/services/k3s/node.nix
    ../../modules/services/rustfs.nix
    ../../modules/services/ntp.nix
  ];

  networking.hostName = "bob";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.12";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/98c08844-c0a7-4b17-b0ed-380641462584";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
