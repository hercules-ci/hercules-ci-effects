{ config, lib, withSystem, ... }:
{
  options =
    let
      inherit (lib) mkOption mkOptionType types;
    in
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
        files = with types;
          let label = mkOption { type = str; };
              fileSpec = submodule {
                options = {
                  inherit label;
                  path = mkOption { type = path; };
                };
              };
              archiveSpec = submodule {
                options = {
                  inherit label;
                  paths = mkOption { type = addCheck (listOf path) (xs: builtins.length xs > 0); };
                  archiver = mkOption { type = enum [ "zip" ]; };
                };
              };
          in
          mkOption {
            type = listOf (oneOf [archiveSpec fileSpec]);
            description = ''
              List of asset files or archives.
              Each entry must be either an attribute set of type
              `{ label: string, path: string }` for a single file or
              `{ label: string, paths: [string], archiver: 'zip' }` for an archive.
              In case of archive, `paths` may contain directories: their _contents_ will be archived recursively.
            '';
            default = [];
            defaultText = lib.literalExpression "[]";
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
      enable = cfg.files != [];
    in
    mkIf enable {
      herculesCI = herculesCI@{ config, ... }:
        let
          artifacts-tool = pkgs: pkgs.writers.writePython3 "artifacts-tool" {} (builtins.readFile ./effect.py);
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
              effectScript = (artifacts-tool pkgs).outPath;
              env = {
                files = builtins.toJSON cfg.files;
                inherit (config.repo) owner;
                repo = config.repo.name;
                releaseTag = cfg.releaseTag herculesCI;
              };
              inputs = [ pkgs.zip ];
            }
          );
        in
        {
          onPush = mkMerge [
            {
              ${cfg.pushJobName}.outputs.effects.gh-releases =
                lib.optionalAttrs
                  (cfg.condition herculesCI.config.repo)
                  deploy;
            }
            {
              default.outputs.checks.release-artifacts = mkIf (cfg.checkArtifacts herculesCI) (withSystem defaultEffectSystem ({ pkgs, ... }:
                pkgs.runCommandNoCCLocal
                  "artifacts-check"
                  { files = builtins.toJSON cfg.files; check_only = ""; }
                  (artifacts-tool pkgs).outPath));
            }
          ];
        };
    };
}
