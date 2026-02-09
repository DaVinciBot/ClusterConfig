{ config, pkgs, lib, ... }:

{
  imports = [
    ../../modules/services/docker.nix
    ../../modules/services/nvidia.nix
    ../../modules/services/tunnel.nix
    ../../modules/services/k3s/master.nix
    ../../modules/services/rustfs.nix
    ../../modules/services/ntp.nix
  ];

  networking.hostName = "flo";
  networking.interfaces.eno1.ipv4.addresses = [ {
    address = "192.168.0.10";
    prefixLength = 24;
  } ];

  fileSystems."/media/hdd1" = lib.mkForce {
    device = "/dev/disk/by-uuid/9b28a06f-e9cc-485d-a8ba-d59a6f1c84d4";
    fsType = "ext4";
    options = [ "defaults" "nofail" "x-systemd.automount" "x-systemd.device-timeout=10" ];
  };
}
