{ withSystem, inputs, ... }: {
  imports = [
    ./flake-module.nix
    ./flake-docs-render.nix
  ];
  systems = [ "x86_64-linux" "aarch64-linux" ];
  flake = {

    flakeModule = ./flake-module.nix;

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects pkgs;
      in effects;

    overlay = final: prev: {
      effects = import ./effects/default.nix final.effects final;
    };

    templates = rec {
      default = flake-parts;
      flake-parts = {
        path = ./templates/flake-parts;
        description = ''
          A demonstration of how to integrate effects with https://flake.parts.
        '';
      };
    };

  };
}
