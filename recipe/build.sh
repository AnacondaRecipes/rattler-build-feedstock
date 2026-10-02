#!/usr/bin/env bash

set -o xtrace -o nounset -o pipefail -o errexit

export CARGO_PROFILE_RELEASE_STRIP=symbols
# cmake is required by aws-lc-sys when CFLAGS inject -O2 (overrides -O0 in jitterentropy)
export AWS_LC_SYS_CMAKE_BUILDER=1
export OPENSSL_DIR="$PREFIX"

if [[ "${target_platform}" == osx-arm64 ]]; then
  export CARGO_PROFILE_RELEASE_LTO=fat
else
  export CARGO_PROFILE_RELEASE_LTO=thin
fi

if [[ "${target_platform}" == linux-aarch64 || "${target_platform}" == osx-arm64 ]]; then
  export JEMALLOC_SYS_WITH_LG_PAGE=16
fi

# tikv-jemalloc-sys (performance feature) runs nested `make` that cannot
# inherit cargo's jobserver: "make: *** read jobs pipe: Resource temporarily unavailable"
unset CARGO_MAKEFLAGS
unset MAKEFLAGS

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
