{ config, pkgs, lib, ... }:

{
  # Networking
  networking.networkmanager.enable = true;
  networking.defaultGateway = "192.168.0.1";
  networking.nameservers = ["8.8.8.8" "8.8.4.4"];

}