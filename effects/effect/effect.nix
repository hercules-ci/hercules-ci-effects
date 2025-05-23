{ bash, cacert, coreutils, curl, jq, lib, runCommand, stdenvNoCC,

  # Optional, used by nixpkgs version check.
  revInfo ? "",
}:
let

  checkVersion = import ../lib-version-check.nix {
    inherit revInfo lib;
    component = "hercules-ci-effects/mkEffect";
  };

  defaultInputs = [
    effectSetupHook
    cacert
    curl
    jq
  ];

  mkDrv = args:
    let
      mkDerivation =
        lib.throwIf (args?imports) "`mkEffect` does not support `imports`. Did you mean `modularEffect` instead of `mkEffect`?"
        stdenvNoCC.mkDerivation;

    in checkVersion mkDerivation (args // {


    phases = args.phases or "initPhase unpackPhase patchPhase ${args.preGetStatePhases or ""} getStatePhase userSetupPhase ${args.preEffectPhases or ""} effectPhase putStatePhase ${args.postEffectPhases or ""}";

    name = lib.strings.sanitizeDerivationName (if args?name then "effect-${args.name}" else "effect");

    # nativeBuildInputs normally corresponds to what the building machine can
    # execute. Likewise, effects are executed on the machine type that would
    # otherwise perform the build.
    # To keep things simple and avoid "build" terminology, we alias this as "inputs".
    nativeBuildInputs =
      (args.defaultInputs or defaultInputs) 
      ++ (args.inputs or [])
      ++ (args.nativeBuildInputs or []);

    isEffect = true;

    # TODO: Use structured attrs instead
    secretsMap = builtins.toJSON (args.secretsMap or {});

    dontUnpack = args.dontUnpack or (!(args?src || args?srcs));

  });

  invokeOverride = f: defaults: (lib.makeOverridable f defaults).override;

  effectSetupHook = runCommand "hercules-ci-effect-sh" {} ''
    mkdir -p $out/nix-support
    cp ${./effects-setup-hook.sh} $out/nix-support/setup-hook
  '';


in
invokeOverride mkDrv {

  /** If you'd like to customize this, use modularEffect instead. */
  # NB: Sync with modularEffect
  __hci_effect_fsroot_copy = runCommand "mkEffect-root" {} ''
    mkdir -p $out/bin $out/usr/bin
    ln -s ${lib.getExe bash} $out/bin/sh
    ln -s ${coreutils}/bin/env $out/usr/bin/env
  '';

  preGetStatePhases = "";
  preEffectPhases = "priorCheckPhase";

  # Extension point for reporting notifications etc that are less criticial and
  # don't write state.
  postEffectPhases = "effectCheckPhase";

  initPhase = ''
    # eof on stdin
    exec </dev/null
    runHook preInit
    eval "$initScript"
    runHook postInit
  '';
  initScript = ''
    export HOME=/build/home
    mkdir -p $HOME
    echo >/etc/passwd root:x:0:0:System administrator:/build/home:/run/current-system/sw/bin/bash
    mkdir -p ~/.ssh
    echo "BatchMode yes" >>~/.ssh/config
  '';

  userSetupPhase = ''
    runHook preUserSetup
    eval "$userSetupScript"
    runHook postUserSetup
  '';
  userSetupScript = "";


  # TODO Read a variable to optionally bail out if not already ok. That won't
  #      permit a commit to fix a problem, which is why that isn't the current
  #      behavior.
  #      This variable can also be set dynamically by priorCheckScript to signal
  #      that the problem is severe enough to abort the effect and thus require
  #      manual intervention.
  priorCheckPhase = ''
    runHook prePriorCheck
    if [[ -n "$priorCheckScript" ]]; then
      if eval "$priorCheckScript"; then
        echo 1>&2 -e 'Prior check \e[32;1mOK\e[0m.'
      else
        echo 1>&2
        echo 1>&2 -e 'WARNING: Prior check \e[31;1mFAILED\e[0m!'
        echo 1>&2
        echo 1>&2 Continuing execution to allow subsequent steps to hopefully fix the problem.
      fi
    fi

    runHook postPriorCheck
  '';
  priorCheckScript = "";

  effectPhase = ''
    runHook preEffect
    eval "$effectScript"
    runHook postEffect
  '';
  effectScript = "";

  effectCheckPhase = ''
    runHook preEffectCheck
    eval "$effectCheckScript"
    runHook postEffectCheck
  '';
  effectCheckScript = "";

  getStatePhase = ''
    runHook preGetState
    eval "$getStateScript"
    runHook postGetState
    registerPutStatePhaseOnFailure
  '';
  getStateScript = "";

  putStatePhase = ''
    if [[ -z ''${PUT_STATE_DONE:-} ]]; then
      runHook prePutState
      eval "$putStateScript"
      runHook postPutState
      PUT_STATE_DONE=true
    else
      echo 1>&2 "NOTE: State has already been uploaded and was not uploaded again."
    fi
  '';
  putStateScript = "";
}
