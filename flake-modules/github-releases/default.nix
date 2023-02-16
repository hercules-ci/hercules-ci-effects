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
          let fileSpec = submodule {
                options = {
                  path = mkOption { type = str; };
                  label = mkOption { type = str; };
                };
              };
          in
          mkOption {
            type = listOf (either str fileSpec);
            description = ''
              List of asset _files_ --- no directories allowed.
              Each entry must be either a path (e.g. `/nix/store/...path`) or
              an attribute set of type `{ path :: string, label :: string }`.
              In the first case, `label` defaults to file name.
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
          artifacts-checker = pkgs: pkgs.writers.writePython3 "artifacts-checker" {} (builtins.readFile ./effect.py);
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
              effectScript = (artifacts-checker pkgs).outPath;
              env = {
                files = builtins.toJSON cfg.files;
                inherit (config.repo) owner;
                repo = config.repo.name;
                releaseTag = cfg.releaseTag herculesCI;
              };
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
                  (artifacts-checker pkgs).outPath));
            }
          ];
        };
    };
}
