{
  perSystem = { config, pkgs, lib, ... }: {
    packages.generated-option-doc-modularEffect =
      # TODO: use the render pipeline in flake-parts,
      #       which has support for things like {options}`foo`.
      let
        eval = lib.evalModules {
          modules = [
            {
              options._module.args = lib.mkOption {
                visible = false;
                # type = lib.types.submodule;
              };
            }
            ./effects/effect/effect-module.nix
          ];
        };
      in
      (pkgs.nixosOptionsDoc
        {
          options = eval.options;
        }).optionsCommonMark;

    packages.generated-antora-files =
      pkgs.runCommand "generated-antora-files"
        {
          nativeBuildInputs = [ pkgs.pandoc ];
          modularEffect = config.packages.generated-option-doc-modularEffect;
        }
        # TODO: use the render pipeline in flake-parts,
        #       which has support for things like {options}`foo`.
        ''
          mkdir -p $out/modules/ROOT/partials
          pandoc --from=markdown --to=asciidoc \
            < $modularEffect \
            > $out/modules/ROOT/partials/options.adoc
        '';
  };
}
