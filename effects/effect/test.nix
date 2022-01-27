{ lib, pkgs, runCommand }:
let
  effects = import ../default.nix effects pkgs;
  inherit (effects) mkEffect;
in
lib.recurseIntoAttrs {
  unpack = mkEffect {
    src = runCommand "src" { } "mkdir $out; touch $out/{a,b,c}";
    effectScript = ''
      set -x
      test -f a
      test -f b
      test -f c
      set +x
    '';
  };
  no-unpack = mkEffect {
    effectScript = ''
      echo 'we got here, so no errors about missing src, it seems'
    '';
  };
}
