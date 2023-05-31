{ effectVMTest, hci-effects, runCommand }:

let
  contents = runCommand "contents" { } ''
    mkdir -p $out/bin
    echo hi >$out/index.md
    echo hidden >$out/.i-am-hidden
    echo 'echo hello' >$out/bin/hello
    chmod a+x $out/bin/hello
    ln -s hello $out/bin/greet
  '';
  lessContents = runCommand "contents" { } ''
    mkdir -p $out
    echo hi >$out/index.md
  '';
  defaults = { lib, ... }: {
    _file = "${__curPos.file}:let defaults";
    git.checkout.remote.url = "http://gitea:3000/test/repo";
    git.checkout.forgeType = "gitea";
    git.checkout.user = "test";
    git.update.branch = "my-test-branch";
    contents = lib.mkDefault contents;
  };
in
effectVMTest {
  imports = [
    ../testsupport/dns.nix
    ../testsupport/gitea.nix
    ../testsupport/setup.nix
  ];
  name = "write-branch";
  effects = {
    write-contents = hci-effects.gitWriteBranch {
      imports = [ defaults ];
    };
    write-contents-no-exe = hci-effects.gitWriteBranch {
      imports = [ defaults ];
      allowExecutableFiles = false;
    };
    write-contents-less = hci-effects.gitWriteBranch {
      imports = [ defaults ];
      contents = lessContents;
    };
    write-contents-destination = hci-effects.gitWriteBranch {
      imports = [ defaults ];
      destination = "www/public";
    };
  };

  testCases = ''

    token = gitea_admin_token

    repo = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"repo", "private":true}'
    """)
    print(repo)

    client.succeed("""
      git clone http://gitea:3000/test/repo.git
      cd repo
      mkdir -p redundant-dir
      touch redundant-file redundant-dir/keep
      git add .
      git commit -m 'init'
      git push
    """).splitlines()

    with subtest("Can write contents"):
      agent.succeed(f"echo {gitea_admin_password} | effect-write-contents")

      repo_update_rev = client.succeed("""
        (
          set -x
          cd repo
          git fetch origin
          git checkout my-test-branch
          find .
          test -x bin/hello
          test -L bin/greet
          echo hi | cmp - index.md
          echo hidden | cmp - .i-am-hidden
          ! test -e redundant-file
          ! test -e redundant-dir
          git log | grep -F 'Update my-test-branch'
          git log | grep -F 'Store path: ${contents}'
        )
      """).rstrip()

    with subtest("Idempotent and successful when up to date"):
      agent.succeed(f"echo {gitea_admin_password} | effect-write-contents")
      client.succeed("""
        (
          set -x
          cd repo
          git pull

          lines=$(git show | grep -F 'Update my-test-branch' | wc -l)
          [[ 1 == $lines ]]

          lines=$(git log | grep -F 'Update my-test-branch' | wc -l)
          [[ 1 == $lines ]]
        )
    """)

    with subtest("Removes executable bit when that is not allowed"):
      agent.succeed(f"echo {gitea_admin_password} | effect-write-contents-no-exe")
      client.succeed("""
        (
          set -x
          cd repo
          git pull
          test -r bin/hello
          ! test -x bin/hello

          lines=$(git log | grep -F 'Update my-test-branch' | wc -l)
          [[ 2 == $lines ]]
        )
      """)

    with subtest("Removes files and directories that are not in the contents anymore"):
      agent.succeed(f"echo {gitea_admin_password} | effect-write-contents-less")
      client.succeed("""
        (
          set -x
          cd repo
          git pull
          test index.md
          ! test -e bin
          ! test -e .i-am-hidden

          lines=$(git log | grep -F 'Update my-test-branch' | wc -l)
          [[ 3 == $lines ]]
        )
      """)

    with subtest("Files and directories can be put in a directory without replacing everything"):
      agent.succeed(f"echo {gitea_admin_password} | effect-write-contents-destination")
      client.succeed("""
        (
          set -x
          cd repo
          git pull
          test index.md
          ! test -e bin
          ! test -e .i-am-hidden
          test -r www/public/index.md
          test -r www/public/.i-am-hidden
          test -x www/public/bin/hello
          test -L www/public/bin/greet

          lines=$(git log | grep -F 'Update www/public' | wc -l)
          [[ 1 == $lines ]]
        )
      """)

  '';
}
