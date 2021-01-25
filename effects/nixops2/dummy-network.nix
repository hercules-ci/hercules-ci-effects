{
  defaults = { lib, ... }: {
    config = {
      boot.loader.grub.enable = lib.mkForce false;
      fileSystems."/".device = lib.mkDefault "/no-root-fs-for-prebuild";
    };
    options = {
      # FIXME: Fix the GCE plugin not to write here.
      deployment.autoLuks = lib.mkOption {};
    };
  };
}