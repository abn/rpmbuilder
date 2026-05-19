# `build` — Build RPM action

Build RPMs and/or SRPMs with the [rpmbuilder](https://github.com/abn/rpmbuilder)
container image. A single `mode` input selects the use case — spec/tito
auto-detection, SRPM-only, rebuild-from-SRPM, one-shot tito, or the strict
two-stage tito workflow — so every supported build is one action.

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

| `mode`           | What it does |
|:-----------------|:-------------|
| `auto`           | Detect spec vs tito from `sources-dir`; build SRPM + binary RPM |
| `srpm-only`      | Stop after the SRPM; skip binary RPM compilation |
| `from-srpm`      | Treat `sources-dir` as a directory of `.src.rpm` files; rebuild binary RPMs from them in a clean environment (no tito) |
| `tito-rpm-only`  | Tito project: run `tito build --rpm` directly, skipping the intermediate SRPM (no SRPM artifact) |
| `tito-two-stage` | Tito project, **strict dependency isolation**: generate the SRPM with tito, then rebuild the binary RPMs from it in a *fresh* container with **no tito present**, so only explicitly declared `BuildRequires` can be satisfied |

An unrecognised `mode` fails the step early with a clear error.

> **Why `tito-two-stage`?** tito and its dependencies are installed into the
> build environment at runtime and could inadvertently satisfy an *undeclared*
> `BuildRequires`. The two-stage workflow rebuilds in a clean container so the
> resulting RPM is guaranteed to depend only on declared build requirements.
> Use it when an undeclared-`BuildRequires` leak would be a correctness or
> policy problem; otherwise `auto` builds tito projects in a single pass.
>
> tito is available via EPEL on Fedora and EL 8/9 but not on EL 10
> (e.g. Rocky Linux 10).

## Inputs

| Input          | Required | Default | Description |
|:---------------|:--------:|:--------|:------------|
| `image`        | no  | `quay.io/abn/rpmbuilder:fedora-latest` | Fully-qualified rpmbuilder image. Tag format `<distro>-<version>`, e.g. `rockylinux-9`. |
| `sources-dir`  | **yes** | — | RPM sources on the runner: a dir with the `.spec` + sources, a tito project root (has `.tito`), or a dir of `.src.rpm` files when `mode: from-srpm`. |
| `output-dir`   | no  | `${{ github.workspace }}/rpmbuild-output` | Where built binary RPMs (and SRPMs, except in `tito-two-stage`) are written. Created if absent. |
| `mode`         | no  | `auto` | One of `auto`, `srpm-only`, `from-srpm`, `tito-rpm-only`, `tito-two-stage` (see above). |
| `arch`         | no  | `x86_64` | Target architecture (`x86_64`, `aarch64`, `noarch`, …). |
| `rpm-lint`     | no  | `false` | Run `rpmlint` on each built binary package. A non-zero exit fails the step. In `tito-two-stage` this applies to the stage-2 RPMs. |
| `ca-certs-dir` | no  | `''` | Host dir of `.crt` files injected into the container CA trust store before any build step. Applied to every container run. |

## Outputs

| Output       | Description |
|:-------------|:------------|
| `output-dir` | Absolute path to the directory of built binary RPMs (and SRPMs, except in `tito-two-stage`). |
| `srpm-dir`   | Absolute path to the directory of intermediate SRPMs. Set only in `tito-two-stage` mode; empty string otherwise. |
| `rpm-files`  | Newline-separated absolute paths of built binary RPMs (excludes SRPMs). Empty when `mode: srpm-only`. |
| `srpm-files` | Newline-separated absolute paths of built/intermediate SRPMs. |
| `rpm-count`  | Number of binary RPMs produced. |
| `srpm-count` | Number of SRPMs produced. |

The action also writes a build summary (mode, image, architecture, per-package
sizes) to the job summary and emits a notice/warning annotation with the
artifact counts.

## Examples

SRPM only (e.g. a manual stage 1):

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

Strict two-stage tito build, publishing binary RPMs and intermediate SRPMs
separately:

```yaml
- id: rpm
  uses: abn/rpmbuilder/.github/actions/build@main
  with:
    sources-dir: ${{ github.workspace }}      # tito project root (has .tito)
    mode:        tito-two-stage

- uses: actions/upload-artifact@v4
  with:
    name: rpms
    path: ${{ steps.rpm.outputs.output-dir }}/**/*.rpm

- uses: actions/upload-artifact@v4
  with:
    name: srpms
    path: ${{ steps.rpm.outputs.srpm-dir }}/**/*.src.rpm
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
