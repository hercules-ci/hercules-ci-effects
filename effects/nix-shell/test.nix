{ pkgs, lib }:
let
  effects = import ../default.nix effects pkgs;
  inherit (effects) mkEffect nix-shell;

  shell = pkgs.mkShell {
    nativeBuildInputs = [
      pkgs.hello
      pkgs.figlet
      pkgs.cowsay
    ];
  };
in

lib.recurseIntoAttrs {

  doctest = scopedImport { inherit pkgs nix-shell; 
    mkEffect = x: mkEffect (x // {
      dontUnpack = true;
      name = "nix-shell-doctest";
    });
  } ./../../docs/modules/ROOT/examples/nix-shell.nix;

  test = mkEffect {
    name = "nix-shell-test";
    dontUnpack = true;
    effectScript = ''
      ${nix-shell { inherit shell; } ''
        set -euo pipefail
        hello \
          | figlet
      ''} | grep ' '
      ${nix-shell { inherit shell; } ''
        set -euo pipefail
        echo 'hello' | cowsay
      ''} | grep hello
    '';
  };
}
