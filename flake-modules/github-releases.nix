{ config, lib, withSystem, ... }:
{
  options =
    let
      inherit (lib) mkOption mkOptionType types;
    in
    {
      hercules-ci.github-releases = {
        condition = lib.mkOption {
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
        releaseTag = lib.mkOption {
          type = types.functionTo types.str;
          description = ''
            Tag to be assigned to the release.
          '';
          default = herculesCI: herculesCI.config.repo.tag;
          defaultText = lib.literalExpression "herculesCI: herculesCI.config.repo.tag";
        };
        files = lib.mkOption {
          type = types.listOf types.str;
          description = ''
            List of asset _files_ --- no directories allowed.
            Each path is in a form of `/path/to/file[#display_label]|glob`:
            either a path with an optional display label (`/nix/store/path#short_name`)
            or a unix-style glob (`/nix/store/path/*.tgz`)
          '';
          default = [];
          defaultText = lib.literalExpression "[]";
        };
        pushJobName = lib.mkOption {
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
          deploy = withSystem defaultEffectSystem ({ hci-effects, ... }:
            hci-effects.modularEffect {
              imports = [
                ../effects/modules/git-auth-gh.nix
              ];
              secretsMap = {
                token = { type = "GitToken"; };
              };
              git.checkout = {
                remote.url = config.repo.remoteHttpUrl;
                forgeType = config.repo.forgeType;
              };
              effectScript = ''
                gh repo clone ${config.repo.owner}/${config.repo.name} source -- --branch ${config.repo.tag} --single-branch
                cd source
                gh release create \
                  --verify-tag ${cfg.releaseTag herculesCI} \
                  ${lib.concatStringsSep " " cfg.files}
              '';
              env = { };
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
          ];
        };
    };
}
