{
  defaults = { lib, ... }: {
    boot.loader.grub.enable = lib.mkForce false;
    fileSystems."/".device = lib.mkDefault "/no-root-fs-for-prebuild";
  };
}