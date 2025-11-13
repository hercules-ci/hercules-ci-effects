{
  imports = [ ./hardware-configuration.nix ];
  boot.loader.grub.enable = false;
  system.stateVersion = "25.11";
}
