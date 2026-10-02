#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit

export CARGO_PROFILE_RELEASE_STRIP=symbols
# aws-lc-sys's jitterentropy.c must compile at -O0; conda CFLAGS inject -O2.
# The cmake builder honors that; the default cc-rs path does not.
export AWS_LC_SYS_CMAKE_BUILDER=1
# native-tls / openssl-sys look here instead of distro OpenSSL.
export OPENSSL_DIR="$PREFIX"

# fat LTO on osx-arm64 matches conda-forge; thin elsewhere keeps linux-64 RAM down.
if [[ "${target_platform}" == osx-arm64 ]]; then
  export CARGO_PROFILE_RELEASE_LTO=fat
else
  export CARGO_PROFILE_RELEASE_LTO=thin
fi

# jemalloc assumes 4 KiB pages; aarch64 (linux + osx) uses 64 KiB (2^16).
if [[ "${target_platform}" == linux-aarch64 || "${target_platform}" == osx-arm64 ]]; then
  export JEMALLOC_SYS_WITH_LG_PAGE=16
fi

# tikv-jemalloc-sys (performance feature) runs nested `make`. Cargo re-injects
# MAKEFLAGS=--jobserver-fds even after unset; GNU make then EAGAINs:
#   make: *** read jobs pipe: Resource temporarily unavailable
REAL_MAKE="$(command -v make)"
mkdir -p "${SRC_DIR}/.make-wrap"
cat > "${SRC_DIR}/.make-wrap/make" << EOF
#!/usr/bin/env bash
unset MAKEFLAGS MFLAGS
exec "${REAL_MAKE}" "\$@"
EOF
chmod +x "${SRC_DIR}/.make-wrap/make"
export PATH="${SRC_DIR}/.make-wrap:${PATH}"

# --no-default-features drops rustls/aws-lc so we link conda openssl (native-tls).
# performance = tikv-jemalloc; s3/sigstore/recipe-generation match the CF feature set.
cargo auditable install --locked \
  --no-default-features \
  --features native-tls,recipe-generation,s3,sigstore,performance \
  --bin rattler-build \
  --root "${PREFIX}" \
  --path . \
  --no-track

cargo-bundle-licenses --format yaml --output "${SRC_DIR}/THIRDPARTY.yml"

mkdir -p "${PREFIX}/share/zsh/site-functions"
"${PREFIX}/bin/rattler-build" completion --shell zsh > "${PREFIX}/share/zsh/site-functions/_rattler-build"
mkdir -p "${PREFIX}/share/bash-completion/completions"
"${PREFIX}/bin/rattler-build" completion --shell bash > "${PREFIX}/share/bash-completion/completions/rattler-build"
mkdir -p "${PREFIX}/share/fish/vendor_completions.d"
"${PREFIX}/bin/rattler-build" completion --shell fish > "${PREFIX}/share/fish/vendor_completions.d/rattler-build.fish"
