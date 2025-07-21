{ config, lib, pkgs, hddUUID, ... }:

{
  systemd.tmpfiles.rules = [
    "d /media 0755 root root -"
    "d /media/hdd1 0755 root root -"
  ];

  # Auto-mount sdb drive to /media/hdd1
  fileSystems."/media/hdd1" = {
    device = "/dev/disk/by-uuid/${hddUUID}";
    fsType = "ext4";
    options = [ 
      "defaults"
      "nofail"             # Don't fail boot if the drive is not present
      "x-systemd.automount" # Enable systemd automount
      "x-systemd.device-timeout=10" # Timeout after 10 seconds if device not found
    ];
  };
}
