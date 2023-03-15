{ pkgs, lib }:
let
  effects = import ../default.nix effects pkgs;

  test = locked: effects.mkEffect {
    name = "test-git-crypt${lib.optionalString (!locked) "-unlocked"}";
    src = git-crypt-sample locked;
    inputs = [ effects.git-crypt-hook ];
    preUnpack = ''
      # make this test independent of the actual agent secrets
      export HERCULES_CI_SECRETS_JSON=${secrets-json}

      writeGPGKey git-crypt
    '';
    effectScript = ''
      grep 'the secret is readable' secret.key || { echo "error: could not read secret.key"; exit 1; }
    '';
  };

  git-crypt-sample = isLocked: pkgs.runCommand "git-crypt-sample" {
    nativeBuildInputs = [ pkgs.git pkgs.git-crypt pkgs.gnutar pkgs.gnupg ];
  } ''
    export HOME=$PWD
    git config --global user.email "you@example.com"
    git config --global user.name "Your Name"
    set -x
    git init sample
    cd sample
    git crypt init
    echo '# hi' >README.md
    echo '*.key filter=git-crypt diff=git-crypt' >.gitattributes
    echo 'the secret is readable' >secret.key
    git add .
    gpg --no-tty --import ${./test/fake-agent.pub.asc}
    # (echo trust; echo 5; echo quit) | gpg --no-tty --command-fd 0 --edit-key 21F488205D18E986
    gpg --list-keys
    gpg --list-secret-keys
    git crypt add-gpg-user --trusted fake-agent
    git commit -m 'First commit'
    git crypt status
    ${lib.optionalString isLocked ''
      cd ..
      git clone sample sample-copy
      cd sample-copy
      git crypt status
    ''}
    git archive --output ../archive.tar.gz master
    mkdir $out
    tar -xzC $out <../archive.tar.gz
    set +x
  '';

  sample-is-locked = pkgs.runCommand "git-crypt-sample-is-locked" { } ''
    grep GITCRYPT ${git-crypt-sample true}/secret.key
    touch $out
  '';

  # This adds decrypted secrets to the store.
  # See https://github.com/hercules-ci/hercules-ci-effects/issues/20
  sample-is-unlocked = pkgs.runCommand "git-crypt-sample-is-unlocked" { } ''
    grep 'the secret is readable' ${git-crypt-sample false}/secret.key
    touch $out
  '';

  secrets-json = pkgs.runCommand "fake-secrets.json" {
    nativeBuildInputs = [ pkgs.jq ];
  } ''
    echo {} | jq \
      --rawfile publicKey ${./test/fake-agent.pub.asc} \
      --rawfile privateKey ${./test/fake-agent.asc} \
      '{ "git-crypt": { data: { privateKey: $privateKey, publicKey: $publicKey } }}' >$out
  '';

in
lib.recurseIntoAttrs {
  can-unlock = test true;

  can-run-unlocked = test false;

  preconditions = lib.recurseIntoAttrs {
    inherit sample-is-locked sample-is-unlocked;
  };
}
