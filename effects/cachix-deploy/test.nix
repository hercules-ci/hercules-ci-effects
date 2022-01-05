{ pkgs, lib, nixos }:
let effects = import ../default.nix effects pkgs;
in
lib.recurseIntoAttrs {
  simple = effects.runIf false (
    effects.runCachixDeploy {
      deploy.agent.a = (nixos {
        fileSystems."/".device = "x";
        boot.loader.grub.enable = false;
      }).config.system.build.toplevel;
    });
}
