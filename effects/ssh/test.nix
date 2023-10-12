{ effectVMTest, effects, hello, lib, mkEffect, runCommand, writeText, cowsay, pkgs }:

let
  inherit (lib) mapAttrsToList concatStringsSep concatMapStringsSep;

in
effectVMTest {
  imports = [ ../testsupport/dns.nix ];
  name = "ssh";
  nodes = {
    target = { ... }: {
      environment.etc."unsafe-ssh/host" = {
        source = ./test/host;
        mode = "0400";
        user = "openssh";
      };
      services.openssh = {
        enable = true;
        openFirewall = true;
        hostKeys = [
          {
            type = "rsa";
            path = "/etc/unsafe-ssh/host";
          }
        ];
      };
      users.users.root.openssh.authorizedKeys.keyFiles = [ ./test/id.pub ];
      system.extraDependencies = [
        # Build dependencies
        cowsay.inputDerivation
        pkgs.stdenv
        pkgs.stdenvNoCC
      ];

      # Make sure we don't accidentally make use of any "garbage" that might
      # be around in the store, depending on how sandboxed the build is,
      # and considering that we're doing some unsafeDiscardStringContext.
      virtualisation.useNixStoreImage = true;
      virtualisation.writableStore = true;

      # nix.package = pkgs.nixVersions.nix_2_13;

      # Don't waste time trying to contact cache.nixos.org.
      nix.settings.substituters = lib.mkForce [ ];
    };
  };
  effects.ssh1 = mkEffect {
    name = "ssh1";
    effectScript = ''
      writeSSHKey
      echo 'target ${builtins.readFile ./test/host.pub}' >>~/.ssh/known_hosts
      echo about to ssh
      ${effects.ssh { destination = "target"; } ''
        echo -n 'it worked' >~/it-worked
        echo >&2 plain ssh part is done
      ''}
      ${effects.ssh { destination = "target"; } ''
        ${hello}/bin/hello >~/greeting
        echo >&2 closure ssh part is done
      ''}
      ${effects.ssh { destination = "target"; buildOnDestination = true; destinationPkgs = pkgs; } ''
        echo >&2 remotely built script start
        ${cowsay}/bin/cowsay "i am cow" >~/cowsaid
        echo >&2 remotely built part is done
      ''}
    '';
    secretsMap.ssh = "deploykey";
  };
  secrets.deploykey.data = {
    publicKey = builtins.readFile ./test/id.pub;
    privateKey = builtins.readFile ./test/id;
  };
  testScript = { nodes, ... }: ''
    start_all()
    dns.wait_for_unit("bind.service")
    dns.wait_for_open_port(53)
    agent.wait_for_unit("multi-user.target")
    target.wait_for_unit("sshd.service")
    target.wait_for_open_port(22)

    # Workaround for
    # error: restoring parent mount namespace: Operation not permitted
    target.succeed("systemctl restart nix-daemon.service")

    agent.succeed("effect-ssh1")
    target.succeed("""[[ "$(cat ~/it-worked)" == it\ worked ]]""")
    target.succeed("grep Hello <~/greeting")
    target.succeed("cat ~/cowsaid >/dev/stderr")
    target.succeed("grep 'i am cow' <~/cowsaid")
  '';
}
