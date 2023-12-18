{ withSystem, inputs, lib, ... }: {
  imports = [
    ./flake-module.nix
    ./flake-docs-render.nix
  ];
  systems = [ "x86_64-linux" "aarch64-linux" ];
  flake = {

    flakeModule = ./flake-module.nix;

    push-cache-module = ./effects/push-cache;

    lib.withPkgs = pkgs:
      let effects = import ./effects/default.nix effects pkgs;
      in effects;

    lib.mkHerculesCI = import ./lib/mkHerculesCI.nix inputs;

    modules = {
      # Also available as `(lib.withPkgs pkgs).modules` aka
      # `hci-effects.modules` when using flake-parts `perSystem` module argument.
      effect = import ./effects/modules.nix;
    };

    overlay = final: prev: {
      effects = lib.warn "pkgs.effects is deprecated. Use pkgs.hci-effects instead." final.hci-effects;
      hci-effects = import ./effects/default.nix final.effects final;
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
