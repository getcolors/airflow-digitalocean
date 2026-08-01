{ pkgs, lib, config, inputs, ... }:

{
  # The launcher is a Babashka script that resolves the package by git SHA, so
  # it needs a JVM Clojure toolchain underneath it as well as bb itself.
  languages.clojure.enable = true;
  languages.ansible.enable = true;
  languages.opentofu.enable = true;

  packages = [
    pkgs.babashka
    pkgs.jet
    pkgs.hcl2json

    # The R2 state backend authenticates through the AWS credential chain.
    pkgs.awscli2

    # The github stage shells out to `gh` throughout — creating the DAG
    # repository, seeding it, and writing the deploy key and server variables
    # into an Actions environment. once-colors and walter-oci do not list this
    # and rely on an ambient install; this project leans on it much harder, so
    # it is declared rather than assumed.
    pkgs.gh

    # DigitalOcean is reached by OpenTofu with COLORS_PAR_DO_TOKEN and needs no
    # CLI, so this is for inspecting what was created rather than for creating
    # it. There is no session to keep alive here — the reason once-colors and
    # walter-oci carry oci-cli and this project carries no equivalent.
    pkgs.doctl

    # For verifying a DAG sync by hand against the rrsync ForceCommand, which
    # is the fastest way to tell a broken key from a broken workflow.
    pkgs.rsync
  ];
}
