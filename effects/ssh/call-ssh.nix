deps@{
  lib,
  nix,
  runCommand,
  openssh,
  writeText,
}:

let
  inherit (lib)
    escapeShellArg
    escapeShellArgs
    makeBinPath
    optionalString
    ;
in

{ destination
, useSubstitutes ? true
, ssh ? openssh
, sshOptions ? ""
, nix ? deps.nix
, nix-copy-closureOptions ? ""
, compress ? false
, compressClosure ? compress
, compressSession ? compress
, inheritVariables ? []
}:

remoteCommands:

let

  commands = optionalString (inheritVariables != []) ''"$(declare -p ${escapeShellArgs inheritVariables});"''
    + lib.escapeShellArg remoteCommands;

  # TODO (2022-01): Use upstream function: https://github.com/NixOS/nixpkgs/pull/123111
  writeDirectReferencesToFile = path: runCommand "runtime-references"
    {
      exportReferencesGraph = ["graph" path];
      inherit path;
    }
    ''
      touch ./references
      while read p; do
        read dummy
        read nrRefs
        if [[ $p == $path ]]; then
          for ((i = 0; i < nrRefs; i++)); do
            read ref;
            echo $ref >>./references
          done
        else
          for ((i = 0; i < nrRefs; i++)); do
            read ref;
          done
        fi
      done < graph
      sort ./references >$out
    '';

  referencesFile = writeDirectReferencesToFile (writeText "remote-commands" remoteCommands);
in ''(
  export PATH="${makeBinPath [nix ssh]}:$PATH"
  _call_ssh_references="''${ssh_copy_paths:-}''${ssh_copy_paths:+ }$(cat ${referencesFile})"
  if [[ -n "$_call_ssh_references" ]]; then
    NIX_SSHOPTS="${sshOptions}" nix-copy-closure ${nix-copy-closureOptions} ${optionalString useSubstitutes "--use-substitutes"} ${optionalString compressClosure "--gzip"} --to ${destination} $_call_ssh_references
  fi
  ssh ${optionalString compressSession "-C"} ${sshOptions} ${destination} -- ${commands})''
