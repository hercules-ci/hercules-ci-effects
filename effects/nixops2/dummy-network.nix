{
  defaults = { lib, ... }:
  let
    inherit (lib) types;
    inherit (types) attrsOf unspecified;
  in {
    config = {
      boot.loader.grub.enable = lib.mkForce false;
      fileSystems."/".device = lib.mkDefault "/no-root-fs-for-prebuild";
    };
    options = {
      # FIXME: Fix the AWS and GCE plugin not to write here; then remove this option placeholder
      # See https://github.com/NixOS/nixops/blob/c9fdc936ba7066564993b6b34557c2f0f77f43ab/doc/release-notes/index.rst#release-20
      deployment.autoLuks = lib.mkOption { default = {}; type = attrsOf (attrsOf unspecified); };
    };
  };
}