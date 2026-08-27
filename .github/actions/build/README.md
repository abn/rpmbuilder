# `build` — Build RPM action

Build RPMs and/or SRPMs with the [rpmbuilder](https://github.com/abn/rpmbuilder)
container image in a **single container run**. A `mode` input selects the use
case: spec/tito auto-detection, SRPM-only, or rebuild-from-SRPM.

> This action is consumed by path reference, not from the GitHub Marketplace:
>
> ```yaml
> - uses: abn/rpmbuilder/.github/actions/build@main
> ```
>
> Pin to a tag or commit SHA instead of `@main` for reproducible builds.

## Usage

```yaml
- name: Build RPMs
  id: rpm
  uses: abn/rpmbuilder/.github/actions/build@main
  with:
    image:       quay.io/abn/rpmbuilder:fedora-latest
    sources-dir: ${{ github.workspace }}/rpm   # dir with the .spec + sources
    output-dir:  ${{ runner.temp }}/rpmbuild-output
    # mode: auto (default) — spec vs tito auto-detected from sources-dir

- name: Upload artifacts
  uses: actions/upload-artifact@v4
  with:
    name: rpms
    path: ${{ steps.rpm.outputs.output-dir }}/**/*.rpm
```

The action runs the image with **rootless podman**. On a runner without
podman preinstalled it is installed via
[`redhat-actions/podman-install`](https://github.com/redhat-actions/podman-install).
For private registries, call
[`redhat-actions/podman-login`](https://github.com/redhat-actions/podman-login)
before this action.

## Modes

`mode` selects one mutually-exclusive use case (default `auto`):

| `mode`          | What it does |
|:----------------|:-------------|
| `auto`          | Detect spec vs tito from `sources-dir`; build SRPM + binary RPM |
| `srpm-only`     | Stop after the SRPM; skip binary RPM compilation |
| `from-srpm`     | Treat `sources-dir` as a directory of `.src.rpm` files; rebuild binary RPMs from them in a clean environment (no tito present) |

An unrecognised `mode` fails the step early with a clear error.

> tito is available via EPEL on Fedora and EL 8/9 but not on EL 10
> (e.g. Rocky Linux 10).

### Strict two-stage tito builds (composition, not a mode)

tito and its dependencies are installed into the build environment at runtime
and could inadvertently satisfy an *undeclared* `BuildRequires`. To guarantee
the RPM depends only on declared build requirements, rebuild the SRPM in a
clean container with no tito present. This is **the action used twice**, not a
built-in mode — keeping the action a single-run primitive and the workflow in
control of the composition:

```yaml
# Stage 1: tito generates the SRPM only
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}        # tito project root (.tito)
    output-dir:  ${{ runner.temp }}/srpm
    mode:        srpm-only

# Stage 2: rebuild from that SRPM in a clean container (no tito)
- id: rpm
  uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ runner.temp }}/srpm
    output-dir:  ${{ runner.temp }}/rpms
    mode:        from-srpm
```

The reusable workflow
[`rpm-build.yml`](../../workflows/rpm-build.yml) wires this up for you behind
its `tito-two-stage: true` input.

## Inputs

| Input          | Required | Default | Description |
|:---------------|:--------:|:--------|:------------|
| `image`        | no  | `quay.io/abn/rpmbuilder:fedora-latest` | Fully-qualified rpmbuilder image. Tag format `<distro>-<version>`, e.g. `rockylinux-9`. |
| `sources-dir`  | **yes** | — | RPM sources on the runner: a dir with the `.spec` + sources, a tito project root (has `.tito`), or a dir of `.src.rpm` files when `mode: from-srpm`. |
| `output-dir`   | no  | `${{ github.workspace }}/rpmbuild-output` | Where built RPMs and SRPMs are written. Created if absent. |
| `mode`         | no  | `auto` | One of `auto`, `srpm-only`, `from-srpm` (see above). |
| `arch`         | no  | `x86_64` | Target architecture (`x86_64`, `aarch64`, `noarch`, …). |
| `rpm-lint`     | no  | `false` | Run `rpmlint` on each built binary package. A non-zero exit fails the step. |
| `ca-certs-dir` | no  | `''` | Host dir of `.crt` files injected into the container CA trust store before any build step. |
| `copr-repos`   | no  | `''` | Space- or newline-separated list of Fedora COPR repositories to enable dynamically. |
| `repos`        | no  | `''` | Space- or newline-separated list of custom repository URLs or .repo files to enable. |

## Outputs

| Output       | Description |
|:-------------|:------------|
| `output-dir` | Absolute path to the directory of all built artifacts. |
| `rpm-files`  | Newline-separated absolute paths of built binary RPMs (excludes SRPMs). Empty when `mode: srpm-only`. |
| `srpm-files` | Newline-separated absolute paths of built SRPMs. |
| `rpm-count`  | Number of binary RPMs produced. |
| `srpm-count` | Number of SRPMs produced. |

The action also writes a build summary (mode, image, architecture, per-package
sizes) to the job summary and emits a notice/warning annotation with the
artifact counts.

## Examples

SRPM only:

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}/rpm
    mode:        srpm-only
```

Rebuild from an existing SRPM, with lint:

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}/srpms
    mode:        from-srpm
    rpm-lint:    'true'
```

Build with an external COPR repository:

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}/rpm
    copr-repos:  "@fedora-llvm-team/llvm-snapshots"
```

Build for `aarch64` against Rocky Linux 9 with a corporate CA:

```yaml
- uses: abn/rpmbuilder/.github/actions/build@main
  with:
    image:        quay.io/abn/rpmbuilder:rockylinux-9
    sources-dir:  ${{ github.workspace }}/rpm
    arch:         aarch64
    ca-certs-dir: ${{ github.workspace }}/ca
```
