{ lib
, modularEffect
, pkgs
}:

let
  inherit (builtins) concatStringsSep;
  inherit (lib) attrNames forEach length mapAttrsToList optionals optionalAttrs optionalString;

  genTitle = flakes:
    let
      names = attrNames flakes;
      showName = name: if name == "." then "`flake.lock`" else "`${name}/flake.lock`";
      allNames = concatStringsSep ", " (map showName names);
      sensibleNames = if length names > 3 then "`flake.lock`" else allNames;
    in
      "${sensibleNames}: Update";
in

passedArgs@
{ gitRemote
, tokenSecret ? { type = "GitToken"; }
, user ? "git"
, updateBranch ? "flake-update"
, forgeType ? "github"
, createPullRequest ? true
, autoMergeMethod ? null
  # NB: Default also specified in ./flake-module.nix
, pullRequestTitle ? genTitle flakes
, pullRequestBody ? null
  # TODO [baseMerge] "HEAD" by default instead of null after real world testing
, baseMergeBranch ? null
, baseMergeMethod ? "merge"
, flakes ? { "." = { inherit inputs commitSummary; }; }
, inputs ? [ ]
, commitSummary ? ""
, module ? { }
, nix ? pkgs.nix
}:
assert createPullRequest -> forgeType == "github";
assert (autoMergeMethod != null) -> forgeType == "github";

# Do not specify inputs when `flakes` is used
assert passedArgs?flakes -> inputs == [ ];

# Do not specify commitSummary when `flakes` is used
assert passedArgs?flakes -> commitSummary == "";

# If you don't specify any flakes, probably that's a mistake, or don't create the effect.
assert flakes != { };

modularEffect {
  imports = [
    ../modules/git-update.nix
    module
  ];

  git.checkout.remote.url = gitRemote;
  git.checkout.forgeType = forgeType;
  git.checkout.user = user;

  git.update.branch = updateBranch;
  git.update.pullRequest.enable = createPullRequest;
  git.update.pullRequest.title = pullRequestTitle;
  git.update.pullRequest.body = pullRequestBody;
  git.update.pullRequest.autoMergeMethod = autoMergeMethod;
  git.update.baseMerge.branch = lib.mkIf (baseMergeBranch != null) (lib.mkDefault baseMergeBranch);
  git.update.baseMerge.method = lib.mkDefault baseMergeMethod;
  git.update.baseMerge.enable = lib.mkDefault (baseMergeMethod != null && baseMergeBranch != null);

  secretsMap.token = tokenSecret;

  name = "flake-update";
  inputs = [
    nix
  ];

  git.update.script =
    let
      script = concatStringsSep "\n" (mapAttrsToList toScript flakes);
      toScript = relPath: flakeCfg@{inputs ? [], commitSummary ? ""}:
        let
          atLeast_2_19 = lib.versionAtLeast nix.version "2.19";
          hasSummary = commitSummary != "";
          extraArgs =
            if atLeast_2_19 then
              lib.escapeShellArgs inputs
            else
              concatStringsSep " " (forEach inputs (i: "--update-input ${i}"));
          command =
            if atLeast_2_19 then "flake update"
            else
              if inputs != [ ] then "flake lock" else "flake update";
          locationContext = if attrNames flakes != ["."] then " in '${relPath}'" else "";
        in
        ''
          echo 1>&2 'Running nix ${command}${locationContext}...'
          ( cd ${lib.escapeShellArg relPath}
            # yes n: Say "n" to questions about accepting nixConfig
            # works around https://github.com/NixOS/nix/pull/11816
            (yes n || :) | nix \
              --extra-experimental-features 'nix-command flakes' \
              ${command} ${extraArgs} \
              --commit-lock-file \
              ${optionalString hasSummary "--commit-lockfile-summary \"${commitSummary}\""} \
          )
        '';
    in
    script;

}
