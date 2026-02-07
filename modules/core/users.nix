{ config, pkgs, lib, ... }:

{
  # SSH public keys managed via sops
  sops.secrets."ssh_keys/dvb" = {};
  sops.secrets."ssh_keys/urbain" = {};

  # Users
  users.mutableUsers = false;
  users.users.dvb = {
    isNormalUser = true;
    description = "Kluser goes DVBrrrr";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [];
    hashedPasswordFile = config.sops.secrets."user_passwords/dvb".path;
    openssh.authorizedKeys.keyFiles = [
      config.sops.secrets."ssh_keys/dvb".path
      config.sops.secrets."ssh_keys/urbain".path
    ];

    shell = pkgs.zsh;
  };
}