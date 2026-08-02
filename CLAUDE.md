# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

Desired state for `airflow-digitalocean`: one Apache Airflow server on a
DigitalOcean droplet, behind Cloudflare, with OpenTofu state in Cloudflare R2.
**There is no source code here.** Six files are tracked:

```text
colors.yml     the desired state — the only file you normally edit
green          the installed launcher (a COPY of ../airflow's skill payload)
.envrc         secret-free; sources the gitignored .envrc.private
devenv.nix     the toolchain
devenv.lock
.gitignore
```

Everything else is generated (`.colors/`) or secret (`.envrc.private`).
`.gitignore` is `.*` with narrow negations, so check `git ls-files` rather than
inferring what is tracked from the working tree.

The behaviour lives in `../airflow` (the package) on `../once` and `../green`.
**Read `../airflow/CLAUDE.md` before reasoning about what a verb actually
does** — the DAG, the stage list, the playbook's ordering constraints and the
ONCE reuse surface are all documented there, not here.

## Commands

```sh
./green build              # render .colors/airflow-digitalocean/ — contacts no provider
./green create --dry-run   # walk the DAG, skip every side effect
./green create             # converge for real
./green delete             # guarded; see below
```

There is no test suite. `build` and `create --dry-run` are the checks — both work
on a fresh checkout with an empty environment, which makes them the safe way to
verify a `colors.yml` edit. Exit code 2 is validation or usage failure and lists
every problem at once. The launcher walks up for `colors.yml`, so any
subdirectory works.

**No `stop` / `start`.** Those are walter's power verbs and they exist for OCI
only, because membership is a fact about a provider's API rather than its
OpenTofu template. This droplet bills continuously — size it for what it must
run, not for a peak you can park overnight.

`direnv allow` once per checkout brings in the toolchain from `devenv`.

## Credentials

Every credential is a `COLORS_PAR_<UPPER_SNAKE_KEY>` variable overlaid onto the
matching flat key at run time, living in the gitignored `.envrc.private`. The
header of `colors.yml` lists all eleven this project needs. Unlike `once-colors`
and `walter-oci` there is **no OCI session here** — DigitalOcean is reached by
OpenTofu with `COLORS_PAR_DO_TOKEN` and no CLI, so nothing needs refreshing
before a long create.

**Never export `COLORS_PAR_PROFILE`**, and this matters more here than anywhere
else in the workspace: three of this project's stages are ONCE's, so they carry
ONCE's directory and state-key names (`tofu-dns`, `tofu-smtp`,
`tofu-smtp-post`). For those three, `profile` is the *only* thing separating this
project's state from a `once-colors` in the same R2 bucket. The launcher refuses
to run when it is set. That is the guard working — do not work around it.

## Things about this deployment that bite

**`delete` destroys the metadata database.** It lives on the droplet's disk and
goes with it. WAL-G makes that recoverable, but recovery is a manual procedure
and not a verb, which is why `compute-prevent-destroy: true` stays in
`colors.yml`. Lift it for one intentional run with
`COLORS_PAR_COMPUTE_PREVENT_DESTROY=false`; never edit the committed flag.
`delete` does **not** delete the `dags-repo` — destroying compute is recoverable,
destroying the DAGs is not.

**The Cloudflare zone must not be shared.** ONCE's DNS template manages
zone-level settings as well as the A record, so a zone another Colors project
already manages would mean two states co-owning `cloudflare_zone_setting` — and a
`delete` here stripping settings from a zone serving something else.
`airflow-host` is on `bigconfig.online`; `once-colors` owns `getcolors.ai` and
`bigconfig.ai`. Note how little separates `bigconfig.online` from `bigconfig.ai`
when read quickly.

**Login is Caddy's, not Airflow's.** Airflow 3's `SimpleAuthManager` will not
take a password from configuration, so authentication is a `basic_auth` line with
a bcrypt hash computed on the machine at play time, and the api-server publishes
no port at all. Consequences: `COLORS_PAR_AIRFLOW_ADMIN_PASSWORD` is the
credential that matters most, and there is **no user model** — one login for one
operator, covering the REST API as well as the UI.

**Silence is ambiguous for backups.** The WAL-G base-backup timer alerts through
`OnFailure=`, which fires when a backup *runs* and fails. A timer that never
fires — masked, disabled, never installed — produces no failure and no mail.
`walg-max-backup-age-hours` covers most of that by alerting on absence;
`systemctl list-timers walg-basebackup.timer` is what settles it.

**`postgres-version` is a real pin, not documentation.** WAL-G base backups do
not restore across Postgres major versions, and Postgres comes from PGDG rather
than the distro.

**Verify a DigitalOcean size slug before changing it.** An unavailable slug fails
at apply, not at build. `s-2vcpu-8gb` — the obvious spelling, and what this
project used first — no longer exists. `doctl compute size list`. The same trap
applies to `digitalocean-vpc-uuid`: a VPC is region-scoped, and a mismatch fails
on something that does not name the real cause (`doctl vpcs list`).

**The root `green` is a copy of the payload, not a symlink** — despite what the
comment in the file's own header says, which is the package repo's situation, not
this one. It was copied by hand from `../airflow/skills/package-airflow-green/`,
so there is deliberately no `skills-lock.json` and no `.agents/` — a lockfile
records a hash an actual install computed, and hand-writing one would claim
provenance this project never earned. After every `bb pin` in `../airflow`:

```sh
cp ../airflow/skills/package-airflow-green/green green
```

Skip it and this project keeps running the old pin. Every `fix: re-copy the
launcher after the …` commit in this history is that step, done late.

**Editing a key in `../airflow` changes nothing here until it is pinned.**
`./green build` renders the playbook from the SHA stamped in the launcher, not
from the working tree. To see the working tree's version meanwhile:

```sh
AIRFLOW_LIB_ROOT=../airflow ./green build
```

`ONCE_LIB_ROOT` and `GREEN_LIB_ROOT` do the same one layer up. That is a
deliberate act, not the default: it renders something the pinned launcher would
not run.

**`.colors/` is generated output.** Never edit it, never read it as source, never
commit it. Change `colors.yml` or the upstream template.

## Git

Work on the current branch. Do not commit or push unless explicitly asked.
