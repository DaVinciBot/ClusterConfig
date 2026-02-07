{ config, pkgs, lib, ... }:

{
  # NTP time synchronization (required for RustFS MNMD cluster consistency)
  services.chrony = {
    enable = true;
    servers = [
      "0.nixos.pool.ntp.org"
      "1.nixos.pool.ntp.org"
      "2.nixos.pool.ntp.org"
      "3.nixos.pool.ntp.org"
    ];
    extraConfig = ''
      # Allow fast initial synchronization
      makestep 1.0 3
    '';
  };
}
