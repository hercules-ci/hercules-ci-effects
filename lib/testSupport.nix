args@
{ inputs ? hercules-ci-effects.inputs
, hercules-ci-effects ? if args?inputs then inputs.self else builtins.getFlake "git+file://${toString ./..}"
}:

let
  # Approximates https://github.com/NixOS/nix/blob/7cd08ae379746749506f2e33c3baeb49b58299b8/src/libexpr/flake/call-flake.nix#L46
  # s/flake.outputs/args.outputs/
  callFlake = args@{ inputs, outputs, sourceInfo }:
    let
      outputs = args.outputs (inputs // { self = result; });
      result = outputs // sourceInfo // { inherit inputs outputs sourceInfo; _type = "flake"; };
    in
    result;

  callFlakeOutputs = outputs: callFlake {
    inherit outputs;
    inputs = inputs // {
      inherit hercules-ci-effects;
    };
    sourceInfo = { };
  };

in {
  inherit
    callFlake
    callFlakeOutputs
    ;
}