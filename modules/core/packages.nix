{ config, pkgs, lib, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System Packages
  environment.systemPackages = with pkgs; [
    git
    python3
    fastfetch
    tmux
    wget
    screen
    btop
    micro
    eza         # Better 'ls'
    bat         # Better 'cat' with syntax highlighting
    ripgrep     # Better 'grep' (faster)
    fd          # Better 'find'
    fzf         # Fuzzy finder (essential for history search)
    dnsutils    # dig, nslookup
    iotop       # Disk I/O monitoring
    iftop       # Network bandwidth monitoring
    ncdu        # Disk usage analyzer (ncurses)
    lsof        # List open files/ports
    jq          # JSON processor (great for API debugging)
    zip
    unzip
  ];
}