{ config, pkgs, lib, ... }:

{
  imports = [
    ./locale.nix
    ./networking.nix
    ./nix.nix
    ./packages.nix
    ./security.nix
    ./shell.nix
    ./system.nix
    ./users.nix
  ];
}