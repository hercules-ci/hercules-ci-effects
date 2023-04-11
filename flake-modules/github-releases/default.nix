{ config, lib, options, withSystem, ... }:
let
  inherit (lib) mkOption mkOptionType types;

  fileSpec = with types;
    submodule ({ config, options, ... }: {
      options = {
        label = mkOption {
          type = str;
          description = ''
            Label of the asset file or archive.

            This is the name that will be used in the GitHub release.
          '';
        };
        path = mkOption {
          type = path;
          description = ''
            Path to the asset file. Must not be a directory. Mutually exclusive with `paths`.
          '';
        };
        paths = mkOption {
          type = addCheck (listOf path) (xs: builtins.length xs > 0);
          description = ''
            Paths to the asset files.
            Mutually exclusive with `path`.

            Directories are allowed, and their contents will be archived recursively.
          '';
        };
        archiver = mkOption {
          type = enum [ "zip" ];
          description = ''
            The archiver to use for the archive.

            This must be set when `paths` is set.
          '';
          defaultText = lib.literalMD "_(unset)_";
        };
        _out = mkOption {
          readOnly = true;
          internal = true;
          default = if options.path.isDefined
            then
              # Assume single, but check first
              lib.throwIf (options.paths.isDefined) "${options.path} and ${options.paths} are mutually exclusive"
              lib.throwIf (options.archiver.isDefined) "${options.path} and ${options.archiver} are mutually exclusive"
              { inherit (config) label path; }
            else
              { inherit (config) label paths archiver; };
        };
      };
    });

in
{
  options =
    {
      hercules-ci.github-releases = {
        condition = mkOption {
          type = types.functionTo types.bool;
          description = ''
            Condition under which a release is going to be pushed.
            This is a function accepting [HerculesCI parameters](https://docs.hercules-ci.com/hercules-ci-agent/evaluation#params-herculesCI)
            and returning boolean.
            By default, pushing happens if a tag is present.
          '';
          default = { tag, ... }: tag != null;
          defaultText = lib.literalExpression ''
            { tag, ... }: tag != null
          '';
        };
        releaseTag = mkOption {
          type = types.functionTo types.str;
          description = ''
            Tag to be assigned to the release.
          '';
          default = herculesCI: herculesCI.config.repo.tag;
          defaultText = lib.literalExpression "herculesCI: herculesCI.config.repo.tag";
        };
        files = mkOption {
          type = types.listOf fileSpec;
          description = ''
            List of asset files or archives.

            Each entry must be either an attribute set of type
             - `{ label: string, path: string }` for a single file, or
             - `{ label: string, paths: [string], archiver: 'zip' }` for an archive.
            
            In case of archive, `paths` may contain directories: their _contents_ will be archived recursively.
          '';
          default = [];
          defaultText = lib.literalExpression "[]";
          example = lib.literalExpression ''
            [
              {
                label = "api.json";
                path = withSystem "x86_64-linux" ({config, ...}: config.packages.api-json);
              }
              {
                label = "api-docs.zip";
                paths = withSystem "x86_64-linux" ({config, ...}: [ config.packages.api-docs ]);
                archiver = "zip";
              }
            ]
          '';
        };
        systems = mkOption {
          type = types.nullOr (types.listOf types.str);
          description = ''
            List of systems for which to call [`filesPerSystem`](#opt-hercules-ci.github-releases.filesPerSystem).
          '';
          default = null;
          defaultText = lib.literalMD "`null`, which means that [`herculesCI.ciSystems`](#opt-herculesCI.ciSystems) will be used.";
        };
        filesPerSystem = mkOption {
          type = types.functionTo (types.listOf fileSpec);
          description = ''
            List of asset files or archives for each system.

            The arguments passed are the same as those passed to `perSystem` modules.

            The function is invoked for each of the [`systems`](#opt-hercules-ci.github-releases.systems). The returned labels must be unique across invocations. This generally means that you have to include the `system` value in the attribute names.

            NOTE: If you are implementing generic logic, consider placing the function in a `mkIf`, so that the function remains undefined in cases where it is statically known to produce no files. When `filesPerSystem` has no definitions, a traversal of potentially many `perSystems` modules is avoided.
          '';

          # NOTE: ''${ is just how to escape ${ inside a ''-string; it does not occur in the rendered example
          example = lib.literalExpression ''
            { system, config, ... }: [
              {
                label = "foo-static-''${system}";
                path = lib.getExe config.packages.foo-static;
              }
            ]
          '';
        };
        checkArtifacts = mkOption {
          type = types.functionTo types.bool;
          description = ''
            Condition under which to check whether artifacts can be built.
          '';
          default = _: true;
          defaultText = lib.literalExpression "_: true";
        };
        pushJobName = mkOption {
          type = types.str;
          description = ''
            Name of the Hercules CI job in which to perform the deployment.
            By default the GitHub pages deployment is triggered by the `onPush.default` job,
            so that the deployment only proceeds when the default builds are successful.
          '';
          default = "default";
          defaultText = lib.literalExpression "default";
        };
      };
    };

  config =
    let
      inherit (lib) mkIf mkMerge;
      inherit (config) defaultEffectSystem;

      cfg = config.hercules-ci.github-releases;
      opt = options.hercules-ci.github-releases;
      enable = cfg.files != [] || opt.filesPerSystem.isDefined;
    in
    {
      herculesCI = mkIf enable (herculesCI@{ config, ... }:
        let
          releaseSystems = if cfg.systems == null then config.ciSystems else cfg.systems;
          systemFiles =
            lib.optionals (opt.filesPerSystem.isDefined) (
              lib.concatMap
                (system: withSystem system cfg.filesPerSystem)
                releaseSystems
            );
          files = map (v: v._out) (cfg.files ++ systemFiles);
          filesJSON = builtins.toJSON files;

          artifacts-tool = pkgs: pkgs.callPackage ../../packages/artifacts-tool/package.nix { };
          deploy = withSystem defaultEffectSystem ({ hci-effects, pkgs, ... }:
            hci-effects.modularEffect {
              imports = [
                ../../effects/modules/git-auth-gh.nix
              ];
              secretsMap = {
                token = { type = "GitToken"; };
              };
              git.checkout = {
                remote.url = config.repo.remoteHttpUrl;
                forgeType = config.repo.forgeType;
              };
              effectScript = lib.getExe (artifacts-tool pkgs);
              env = {
                files = filesJSON;
                inherit (config.repo) owner;
                repo = config.repo.name;
                releaseTag = cfg.releaseTag herculesCI;
              };
              inputs = [ pkgs.zip ];
              extraAttributes.files = files;
            }
          );
        in
        {
          onPush = mkMerge [
            {
              ${cfg.pushJobName}.outputs.effects.github-releases =
                lib.optionalAttrs
                  (cfg.condition herculesCI.config.repo)
                  deploy;
            }
            {
              default.outputs.checks.release-artifacts = mkIf (cfg.checkArtifacts herculesCI) (withSystem defaultEffectSystem ({ pkgs, ... }:
                pkgs.runCommandNoCCLocal
                  "artifacts-check"
                  { files = filesJSON;
                    check_only = "";
                    passthru.files = files;
                  }
                  (lib.getExe (artifacts-tool pkgs))));
            }
          ];
        });
    };
}
