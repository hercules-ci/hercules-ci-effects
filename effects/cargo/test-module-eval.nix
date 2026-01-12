# Run with:
#   nix build '.#checks.x86_64-linux.evaluation-cargoPublishModule'
args@{
  inputs ? hercules-ci-effects.inputs,
  hercules-ci-effects ?
    if args ? inputs then inputs.self else builtins.getFlake "git+file://${toString ./../..}",
}:
let
  testSupport = import ../../lib/testSupport.nix args;

  # callFlakeOutputs with a mock outPath so self.outPath works
  callFlakeOutputs =
    outputs:
    testSupport.callFlake {
      inherit outputs;
      inputs = inputs // {
        inherit hercules-ci-effects;
      };
      sourceInfo = {
        outPath = ./test;
      };
    };
in
rec {
  inherit (inputs) flake-parts nixpkgs;
  inherit (nixpkgs) lib;

  fakeRepoBranch = {
    branch = "main";
    ref = "refs/heads/main";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = null;
    remoteHttpUrl = "https://git.forge/repo.git";
  };
  fakeRepoTag = {
    branch = null;
    ref = "refs/tags/1.0.0";
    rev = "deadbeef";
    shortRev = "deadbe";
    tag = "1.0.0";
    remoteHttpUrl = "https://git.forge/repo.git";
  };
  fakeHerculesCI = repo: {
    primaryRepo = repo;
    inherit (repo)
      branch
      ref
      tag
      rev
      shortRev
      remoteHttpUrl
      ;
  };

  # Basic module usage
  basicOutputs = callFlakeOutputs (
    inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          ../../flake-module.nix
        ];
        systems = [ "x86_64-linux" ];
        hercules-ci.cargo-publish = {
          enable = true;
          secretName = "crates-io";
        };
      }
    )
  );

  # With assertVersions enabled
  assertVersionsOutputs = callFlakeOutputs (
    inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          ../../flake-module.nix
        ];
        systems = [ "x86_64-linux" ];
        hercules-ci.cargo-publish = {
          enable = true;
          secretName = "crates-io";
          assertVersions = true;
        };
      }
    )
  );

  # Evaluate herculesCI for different repo states
  basicBranchHerculesCI = basicOutputs.herculesCI (fakeHerculesCI fakeRepoBranch);
  basicTagHerculesCI = basicOutputs.herculesCI (fakeHerculesCI fakeRepoTag);
  assertVersionsBranchHerculesCI = assertVersionsOutputs.herculesCI (fakeHerculesCI fakeRepoBranch);
  assertVersionsTagHerculesCI = assertVersionsOutputs.herculesCI (fakeHerculesCI fakeRepoTag);

  # Get the cargoPublish effects
  branchEffect = basicBranchHerculesCI.onPush.default.outputs.effects.cargoPublish;
  tagEffect = basicTagHerculesCI.onPush.default.outputs.effects.cargoPublish;
  assertVersionsBranchEffect =
    assertVersionsBranchHerculesCI.onPush.default.outputs.effects.cargoPublish;
  assertVersionsTagEffect = assertVersionsTagHerculesCI.onPush.default.outputs.effects.cargoPublish;

  tests =
    ok:

    # Basic module produces effects
    assert branchEffect.isEffect or null == true;
    assert tagEffect.isEffect or null == true;

    # Effects instantiate
    assert lib.isString branchEffect.drvPath;
    assert lib.isString tagEffect.drvPath;

    # assertVersions module produces effects
    assert assertVersionsBranchEffect.isEffect or null == true;
    assert assertVersionsTagEffect.isEffect or null == true;
    assert lib.isString assertVersionsBranchEffect.drvPath;
    assert lib.isString assertVersionsTagEffect.drvPath;

    ok;
}
