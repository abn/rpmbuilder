# rpmbuilder

[![](https://github.com/abn/rpmbuilder/workflows/Image%20Build/badge.svg)](https://github.com/abn/rpmbuilder/actions?query=workflow%3A%22Image+Build%22)
[![Quay Container](https://quay.io/repository/abn/rpmbuilder/status "Quay Container")](https://quay.io/repository/abn/rpmbuilder)

Clean, containerized RPM and SRPM build environments for Red Hat and openSUSE distributions. Builds spec files, fetches remote sources via spectool, auto-resolves package build dependencies, and supports tito release workflows.

---

## Supported Distributions & Tags

Container images are published to [`quay.io/abn/rpmbuilder`](https://quay.io/repository/abn/rpmbuilder?tab=tags):

| Distribution | Version / Stream | Image Tag |
|:-------------|:-----------------|:----------|
| **Fedora** | Latest stable | `quay.io/abn/rpmbuilder:fedora-latest` |
| **Fedora** | 44 | `quay.io/abn/rpmbuilder:fedora-44` |
| **Fedora** | 43 | `quay.io/abn/rpmbuilder:fedora-43` |
| **Fedora** | Rawhide (development) | `quay.io/abn/rpmbuilder:fedora-rawhide` |
| **Rocky Linux** | 10 | `quay.io/abn/rpmbuilder:rockylinux-10` |
| **Rocky Linux** | 9 / Latest | `quay.io/abn/rpmbuilder:rockylinux-9` (or `rockylinux-latest`) |
| **openSUSE Leap** | 15.6 / Latest | `quay.io/abn/rpmbuilder:opensuse-leap-15.6` (or `opensuse-leap-latest`) |
| **openSUSE Tumbleweed** | Rolling / Latest | `quay.io/abn/rpmbuilder:opensuse-tumbleweed-latest` |

---

## Quickstart & Common Recipes

Set your source and output directories:
```bash
SOURCE_DIR=$(pwd)/sources
OUTPUT_DIR=$(pwd)/output
mkdir -p "${OUTPUT_DIR}"
```

### 1. Standard Spec File Build
Builds all `.spec` files in `SOURCE_DIR`, automatically downloads remote `SourceX` archives, installs `BuildRequires`, and outputs both SRPMs and binary RPMs:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:fedora-latest
```

### 2. Tito Projects (Single Step)
If `SOURCE_DIR` contains a `.tito` project directory, `rpmbuilder` automatically provisions tito at runtime and runs `tito build --test`:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:fedora-latest
```

### 3. Strict Two-Stage Tito Build (Dependency Isolation)
Because tito installs runtime dependencies into the container, they could inadvertently satisfy undeclared `BuildRequires` in a spec file. For strict isolation, run the build in two stages:

```bash
# Stage 1: Generate the SRPM only
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    -e SRPM_ONLY=1 \
    quay.io/abn/rpmbuilder:fedora-latest

# Stage 2: Rebuild binary RPMs from that SRPM in a clean environment (no tito)
podman run --rm -it \
    -v ${OUTPUT_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    -e FROM_SRPM=1 \
    quay.io/abn/rpmbuilder:fedora-latest
```

### 4. Rebuilding from an Existing SRPM
To rebuild binary RPMs from existing `.src.rpm` files:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -e OUTPUT_USER=$UID \
    -e FROM_SRPM=1 \
    quay.io/abn/rpmbuilder:fedora-latest
```

### 5. Enabling COPR & Custom Repositories
Dynamically enable Fedora COPR repositories or custom package repositories before build dependencies are installed:

- **Via Environment Variables:**
  ```bash
  podman run --rm -it \
      -v ${SOURCE_DIR}:/sources:z \
      -v ${OUTPUT_DIR}:/output:z \
      -e OUTPUT_USER=$UID \
      -e COPR_REPOS="@fedora-llvm-team/llvm-snapshots user/my-repo" \
      -e REPOS="https://example.com/custom.repo" \
      quay.io/abn/rpmbuilder:fedora-latest
  ```
- **Via Configuration Files in `${SOURCE_DIR}`:**
  - `${SOURCE_DIR}/.copr`: Plain text file listing COPR repos (one per line, `#` comments ignored).
  - `${SOURCE_DIR}/.repos`: Plain text file listing repository URLs (one per line).
  - `${SOURCE_DIR}/.repos/*.repo`: Drop-in `.repo` files automatically copied to the system repository directory.

### 6. Corporate & Self-Signed CA Certificates
Mount a host directory containing `.crt` certificates. Certificates are added to the system trust store before downloading remote sources or installing packages:

```bash
podman run --rm -it \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    -v ${CERT_DIR}:/etc/pki/ca-trust/source/anchors:z \
    -e OUTPUT_USER=$UID \
    quay.io/abn/rpmbuilder:fedora-latest
```

### 7. Interactive Debugging Shell
To inspect the environment or debug spec build failures interactively:

```bash
podman run --rm -it --entrypoint bash \
    -v ${SOURCE_DIR}:/sources:z \
    -v ${OUTPUT_DIR}:/output:z \
    quay.io/abn/rpmbuilder:fedora-latest
```

---

## GitHub Actions & CI Integration

rpmbuilder provides both a turnkey reusable workflow and a composite action. They are consumed by path reference (`abn/rpmbuilder/...@<ref>`).

### Option A: Reusable Workflow (Turnkey Matrix Builds)
Use [`.github/workflows/rpm-build.yml`](.github/workflows/rpm-build.yml) to build across a matrix of images and upload build artifacts automatically:

```yaml
jobs:
  build-rpms:
    uses: abn/rpmbuilder/.github/workflows/rpm-build.yml@main
    with:
      sources-path:   rpm
      images:         '["fedora-latest", "fedora-rawhide", "rockylinux-9", "opensuse-leap-15.6"]'
      copr-repos:     '@fedora-llvm-team/llvm-snapshots'
      rpm-lint:       true
      tito-two-stage: false   # set true for strict two-stage tito isolation
```

### Option B: Composite Action (Single Step)
Use [`.github/actions/build`](.github/actions/build/README.md) for custom single-step pipelines:

```yaml
- name: Build RPMs
  uses: abn/rpmbuilder/.github/actions/build@main
  with:
    image:       quay.io/abn/rpmbuilder:fedora-latest
    sources-dir: ${{ github.workspace }}/rpm
    mode:        auto   # or: srpm-only | from-srpm
    copr-repos:  '@fedora-llvm-team/llvm-snapshots'
    rpm-lint:    'true'
```

---

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|:---------|:--------|:------------|
| `SOURCES` | `/sources` | Path to the directory containing `.spec` files and source archives |
| `OUTPUT` | `/output` (or `${SOURCES}/.rpmbuild`) | Path where final built RPMs and SRPMs are placed |
| `OUTPUT_USER` | Container `$USER` | UID or username applied to output files via `install` (set to host `$UID` to prevent root-owned files on volume mounts) |
| `ARCH` | `x86_64` | Target RPM architecture (`x86_64`, `aarch64`, `noarch`, …) |
| `RPM_LINT` | _unset_ | When defined, executes `rpmlint` on all generated binary RPMs |
| `SRPM_ONLY` | _unset_ | When defined, stops after building SRPMs; skips binary RPM compilation |
| `FROM_SRPM` | _unset_ | When defined, treats `SOURCES` as a directory of `.src.rpm` files and rebuilds binary RPMs |
| `COPR_REPOS` | _unset_ | Space- or comma-separated list of Fedora COPR repositories to enable dynamically |
| `REPOS` / `ADDITIONAL_REPOS` | _unset_ | Space- or comma-separated list of custom repository URLs to enable |
| `DEBUG` / `VERBOSE` | _unset_ | When defined, enables shell execution tracing (`set -x`) |

### Source Directory Configuration Files

| Path | Purpose |
|:-----|:--------|
| `${SOURCES}/.copr` | Plain text list of COPR repositories to enable |
| `${SOURCES}/.repos` | Plain text list of repository URLs to add |
| `${SOURCES}/.repos/*.repo` | Drop-in `.repo` files copied directly into `/etc/yum.repos.d/` or `/etc/zypp/repos.d/` |

### Container Volume Mounts

| Container Path | Purpose |
|:---------------|:--------|
| `/sources` | Input directory with `.spec` files, source tarballs, or `.src.rpm` files |
| `/output` | Destination directory where built RPMs and SRPMs are written |
| `/etc/pki/ca-trust/source/anchors` | Directory of `.crt` certificates to inject into trust store (Red Hat / Fedora) |
| `/etc/pki/trust/anchors` | Directory of `.crt` certificates to inject into trust store (openSUSE) |

---

## Building the Image Locally

Build images directly using `make` (auto-detects `podman` or `docker`):

```bash
# Build default image (Fedora)
make build

# Build a specific distribution
BASE_IMAGE=rockylinux:9 TARGET_IMAGE=rpmbuilder:rocky-9 make build
BASE_IMAGE=opensuse/leap:15.6 TARGET_IMAGE=rpmbuilder:opensuse-leap-15.6 make build

# Force docker instead of podman
CONTAINER_CLI=docker make build

# Run the BATS test suite
TARGET_IMAGE=quay.io/abn/rpmbuilder:fedora-latest make test
```
