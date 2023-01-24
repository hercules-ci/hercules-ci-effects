# `gh-pages` effect

`gh-pages` is an effect intended to be used to build documentation and deploy in to `gh-pages` branch.

## Example

```nix
{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    hercules-ci-effects.url = github:hercules-ci/hercules-ci-effects;
  };

  outputs = { self, nixpkgs, hercules-ci-effects }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      hci-effects = hercules-ci-effects.lib.withPkgs pkgs;

      # import gh-pages
      mkGhPagesBuilder = import "${hercules-ci-effects}/effects/gh-pages" {
        inherit pkgs;
        inherit (hci-effects) runIf mkEffect;
      };
    in
    {
      # example "documentation"
      packages.${system}.gh-pages = pkgs.runCommandNoCC "generate-gh-pages" {}
        ''
          mkdir $out
          echo "<h1>This is a GH page</h1>" > $out/index.html
        '';

      # consise way to get your gh-pages effect visible to Hercules CI
      herculesCI = mkGhPagesBuilder { inherit (self.packages.${system}) gh-pages; };
    };
}
```

In case you already have effects:

```nix
herculesCI = herculesEnv: {
  onPush.myEffect = ...;
} // mkGhPagesBuilder { inherit (self.packages.${system}) gh-pages; } herculesEnv;
```

If you only have recommended `herculesCI.ciSystems = ...;` and wondering what is this `herculesEnv`:

```diff
-herculesCI.ciSystems = ...;
+herculesCI = herculesEnv: {
+  ciSystems = ...;
+} // mkGhPagesBuilder { inherit (self.packages.${system}) gh-pages; } herculesEnv;
```

## Reference

```PureScript
import "${hercules-ci-effects}/effects/gh-pages" ::
  { pkgs :: Nixpkgs
      -- in fact, only lib.elem, lib.optionalString, lib.openssh and lib.git are used
  , runIf, mkEffect
      -- from hercules-ci-effects
  } ->
  { gh-pages :: Derivation
      -- derivation to build and push
  , branchName :: String ? "gh-pages"
      -- branch to push
  , condition :: Repo -> Boolean ? { ref, ... }: lib.elem ref ["refs/heads/main" "refs/heads/master"]
      -- if a repo does not satisfy this condition, the effect will not be run
      -- by default it checks that CI is triggered by main branch
      -- Repo is the type of https://docs.hercules-ci.com/hercules-ci-agent/evaluation#param-herculesCI-primaryRepo
  , committer :: { name :: String, email :: String } ? <credentials of sincerely yours> }
      -- name and email that will be used as author and committer by Git
      -- you probably want to change these
  } ->
  HerculesCIArgs ->
  { onPush.gh-pages.outputs.effects.default :: Effect }
```
