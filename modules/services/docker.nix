{ config, pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true; # Auto-remove unused containers/images
    daemon.settings = {
      data-root = "/home/dvb/docker";
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "10m";
        "max-file" = "3";
      };
    };
  };
  
  environment.systemPackages = [ pkgs.docker-compose ];
  
  users.users.dvb.extraGroups = [ "docker" ];
}