{ config, pkgs, lib, ... }:

{
  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.download-buffer-size = 2147483648; # 2048MB

  # Automatic Garbage Collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.autoUpgrade = {
    enable = true;
    dates = "04:15";
    randomizedDelaySec = "45min";
    persistent = true;
    allowReboot = true;
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
    flake = "github:DaVinciBot/ClusterConfig#${config.networking.hostName}";
    flags = [ "--refresh" "-L" ];
  };

  # Optimize storage (deduplicate files)
  nix.settings.auto-optimise-store = true;
}