{ effectVMTest, effects, hello, lib, mkEffect, runCommand, writeText }:

let
  
in
effectVMTest {
  imports = [ ../testsupport/dns.nix ];
  name = "flake-update";
  nodes = {
    gitea = { pkgs, ... }: {
      services.gitea.enable = true;
      services.gitea.settings.service.DISABLE_REGISTRATION = true;
      # services.gitea.settings.log.LEVEL = "Trace";
      # services.gitea.settings.databas.LOG_SQL = true;
      services.gitea.settings.log.LEVEL = "Info";
      services.gitea.settings.database.LOG_SQL = false;
      networking.firewall.allowedTCPPorts = [ 3000 ];
      environment.systemPackages = [ pkgs.gitea ];
    };
    client = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.git ];
    };
  };
  defaults = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.jq ];
  };
  effects = {
    update = effects.flakeUpdate {
      gitRemote = "http://gitea:3000/test/repo";
      user = "test";
      forgeType = "gitea";
      createPullRequest = false; # not supported
    };
  };
  secrets = {
  };
  
  testScript = ''
    start_all()
    gitea.wait_for_unit("gitea.service")

    gitea.succeed("""
      su -l gitea -c 'GITEA_WORK_DIR=/var/lib/gitea gitea admin user create \
        --username test --password test123 --email test@client'
    """)

    client.wait_for_unit("multi-user.target")
    gitea.wait_for_open_port(3000)

    token = gitea.succeed("""
      curl --fail -X POST http://test:test123@gitea:3000/api/v1/users/test/tokens \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        -d '{\"name\":\"token\"}' \
        | jq -r '.sha1'
    """).strip()

    repo = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"repo", "private":true}'
    """)
    print(repo)

    dep = client.succeed("""
      curl -v --fail -X POST http://gitea:3000/api/v1/user/repos \
        -H 'Accept: application/json' -H 'Content-Type: application/json' \
        """ + f"-H 'Authorization: token {token}'" + """ \
        -d '{"name":"dep", "private":true}'
    """)
    print(dep)

    dep_commits = client.succeed("""
    (
    # set -x
    echo "http://test:test123@gitea:3000" >~/.git-credentials
    git config --global credential.helper store
    git config --global user.email "test@client"
    git config --global user.name "Test User"

    git clone http://gitea:3000/test/dep.git
    cd dep
    touch file
    git add file
    git commit -m 'init'
    git push
    cd ..

    git clone http://gitea:3000/test/repo.git
    cd repo
    cat >flake.nix <<EOF
    {
      inputs.dep = {
        url = "git+http://gitea:3000/test/dep";
        flake = false;
      };
      outputs = { ... }: {
      };
    }
    EOF
    ls -al
    cat flake.nix
    git add .
    nix flake lock -v --extra-experimental-features nix-command\ flakes
    git add .
    git commit -m 'init'
    git push
    cd ..

    cd dep
    echo v2 >file
    git add file
    git commit -m 'init'
    git push
    git log --format=oneline
    cd ..
    ) 1>&2
    (
    cd dep
    git log --format=%H
    )
    """).splitlines()

    assert len(dep_commits) == 2

    agent.succeed("echo test123 | effect-update")

    repo_update_rev = client.succeed(f"""
      (
        set -x
        cd repo
        git fetch origin
        git checkout flake-update
        grep '{dep_commits[0]}' <flake.lock
        git log 1>&2
        git log | grep 'flake.lock: Update'
        # The commit message mentions the hostname
        git log | grep gitea
        # The commit hashes occur in the message
        # We only check for shortRev length, which is 7
        git log | grep '{dep_commits[0][:7]}'
        git log | grep '{dep_commits[1][:7]}'
      ) 1>&2
      (cd repo; git rev-parse HEAD)
    """).rstrip()

    with subtest("Idempotent and successful when up to date"):
      agent.succeed("echo test123 | effect-update")
      client.succeed(f"""
        (
          set -x
          cd repo
          git pull
          [[ $(git rev-parse HEAD) == {repo_update_rev} ]]
        )
    """)
  '';
}