{ lib, config, ... }:
let
  inherit (lib)
    mkAfter
    mkDefault
    mkOption
    types
    ;

  isStoreContents = lib.hasPrefix builtins.storeDir config.contents;
in
{
  imports = [
    ../modules/git-update.nix
  ];

  options = {
    contents = mkOption {
      type = types.path;
      description = ''
        The contents to which the branch will be set.

        The basename of `contents` will not be used.
      '';
    };
    destination = mkOption {
      type = types.str;
      description = ''
        Relative path into repository that will be replaced by the `contents`.

        Any pre-existing contents at this location will be removed.
      '';
      default = ".";
    };
    message = mkOption {
      type = types.str;
      description = ''
        Commit message for the updated contents.
      '';
      defaultText = lib.literalMD ''
        `"Update "` + the `destination` or `git.update.branch`
      '';
      default = "Update ${if config.destination == "." then config.git.update.branch else config.destination}"
        + lib.optionalString isStoreContents
          "\n\nStore path: ${config.contents}";
    };
    allowExecutableFiles = mkOption {
      type = types.bool;
      description = ''
        Whether executable files are allowed. If not, these permission bits will
        be omitted when copying the `contents`.
      '';
      default = true;
    };
  };

  config = {
    secretsMap.token = mkDefault { type = "GitToken"; };

    name = "write-branch";

    env.contents = "${config.contents}";
    env.message = "${config.message}";
    env.destination =
      lib.throwIf (lib.hasPrefix "/" config.destination)
        "gitWriteBranch: destination must be a relative path, but got ${config.destination}"
        config.destination;

    git.update.script = mkAfter ''
      echo 1>&2 'Writing new tree...'

      if test -e "$destination"; then
        git rm -rf "$destination"
      else
        mkdir -p "$(dirname "$destination")"
      fi

      if test -d "''${contents}"; then
        contents="''${contents}/."
      fi
      cp -r ${lib.optionalString (!config.allowExecutableFiles) " --no-preserve=mode"} \
        "''${contents}" \
        "$destination"

      git add -v "$destination"

      if git diff --cached --quiet; then
        echo Nothing to commit.
      else
        git commit -m "''${message}"
      fi
    '';

    git.update.pullRequest.enable = mkDefault false;
  };
}
