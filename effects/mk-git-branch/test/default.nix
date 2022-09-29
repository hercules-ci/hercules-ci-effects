{ effectVMTest, effects, lib, mkGitBranch, runCommand, writeText }:

let
  inherit (lib) mapAttrsToList concatStringsSep concatMapStringsSep;

  contents1 = runCommand "contents1" { } ''
    mkdir -p $out/somedir
    echo "hi" >$out/index.txt
    echo "hello" >$out/somedir/detail.txt
    { echo "#!/usr/bin/env bash"
      echo "echo hi there"
    } >$out/executable
    chmod a+x $out/executable
  '';
  contents2 = runCommand "contents2" { } ''
    mkdir -p $out/somedir
    # contents change
    echo "hi2" >$out/index.txt
    echo "hello" >$out/somedir/detail.txt
    { echo "#!/usr/bin/env bash"
      echo "echo hi there"
    } >$out/executable
    # not executable any more
    # chmod a+x $out/executable
    # new file
    echo "more" >$out/greed.txt
  '';

in
effectVMTest {
  name = "ssh";
  imports = [ ../../testsupport/dns.nix ];
  nodes = {
    agent = { nodes, ... }: {
      networking.dhcpcd.enable = false;
    };
    githost = { pkgs, ... }: {
      environment.etc."unsafe-ssh/host" = {
        source = ./host;
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
      environment.systemPackages = [ pkgs.git ];
      users.users.git = {
        isNormalUser = true;
        openssh.authorizedKeys.keyFiles = [ ./id.pub ];
      };
    };
  };
  effects.mkGitBranch1 = mkGitBranch {
    pushToBranch = "my-branch";
    preGitInit = ''
      echo "bonus content" >extra-file
    '';
    branchRoot = contents1;
    gitRemote = "git@githost";
    hostKey = "githost ${builtins.readFile ./host.pub}";
    owner = "gitfan42";
    repo = "cats";
    committerEmail = "gitfan42+automation@example.com";
    committerName = "GitFan42";
    authorName = "Jane";
    sshSecretName = "deploykey";
  };
  effects.mkGitBranch2 = mkGitBranch {
    pushToBranch = "my-branch";
    branchRoot = contents2;
    gitRemote = "git@githost";
    hostKey = "githost ${builtins.readFile ./host.pub}";
    owner = "gitfan42";
    repo = "cats";
    committerEmail = "gitfan42+automation@example.com";
    committerName = "GitFan42";
    authorName = "Jane";
    sshSecretName = "deploykey";
  };
  secrets.deploykey.data = {
    publicKey = builtins.readFile ./id.pub;
    privateKey = builtins.readFile ./id;
  };
  testScript = { nodes, ... }: ''

    # setup

    start_all()
    dns.wait_for_unit("bind.service")
    dns.wait_for_open_port(53)
    agent.wait_for_unit("multi-user.target")
    githost.wait_for_unit("sshd.service")
    githost.wait_for_open_port(22)

    # setup check

    agent.succeed("cat /etc/hosts >/dev/console")
    agent.succeed("cat /etc/resolv.conf >/dev/console")
    agent.succeed("host githost ${nodes.dns.networking.primaryIPAddress}")
    agent.succeed("host githost")

    with subtest("init with mkGitBranch1"):

      # git-remote doesn't go about creating new repos, so we do it here.
      githost.succeed("""
        sudo -u git mkdir -p /home/git/gitfan42 >/dev/console 2>/dev/console
        sudo -u git git init --bare /home/git/gitfan42/cats.git >/dev/console 2>/dev/console
      """)

      agent.succeed("effect-mkGitBranch1")

      githost.succeed("""
        # TODO: make the effect set HEAD so this doesn't need --branch?
        git clone /home/git/gitfan42/cats.git tmp1 --branch my-branch
        pushd tmp1
        [[ "$(cat extra-file)" == "bonus content" ]] || {
          echo extra-file not right 1>&2
          false
        }

        [[ -x executable ]] || {
          echo executable should be executable
          false
        }

        rm extra-file
        rm -rf .git
        diff -r . ${contents1}
        popd
        rm -rf tmp1
      """)


    with subtest("idempotency of mkGitBranch1"):
      # relies on the previous test run

      agent.succeed("effect-mkGitBranch1")

      githost.succeed("""
        # TODO: make the effect set HEAD so this doesn't need --branch? Not sure.
        git clone /home/git/gitfan42/cats.git tmp1 --branch my-branch
        pushd tmp1
        [[ "$(cat extra-file)" == "bonus content" ]] || {
          echo extra-file not right 1>&2
          false
        }

        [[ -x executable ]] || {
          echo executable should be executable 1>&2
          false
        }

        rm extra-file
        rm -rf .git
        diff -r . ${contents1}
        popd
        rm -rf tmp1
      """)

    with subtest("removals and additions with mkGitBranch2"):
      # relies on the previous test run

      agent.succeed("effect-mkGitBranch2")

      githost.succeed("""
        # TODO: make the effect set HEAD so this doesn't need --branch?
        git clone /home/git/gitfan42/cats.git tmp1 --branch my-branch
        pushd tmp1

        [[ -e executable ]] || {
          echo executable gone? 1>&2
          false
        }
        [[ ! -x executable ]] || {
          echo executable should not be executable
          false
        }

        rm -rf .git
        diff -r . ${contents2}
        popd
        rm -rf tmp1
      """)

  '';
}
