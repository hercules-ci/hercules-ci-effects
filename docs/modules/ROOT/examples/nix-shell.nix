let
  exampleShell = pkgs.mkShell {
    nativeBuildInputs = [ pkgs.hello pkgs.figlet ];
  };
in mkEffect {
  effectScript = ''
    echo 'Hello from plain effect environment'
    ${nix-shell { shell = exampleShell; } ''
      set -euo pipefail
      echo 'Hello from nix-shell environment'
      hello \
        | figlet
    ''}
    echo 'Bye!'
  '';
}
