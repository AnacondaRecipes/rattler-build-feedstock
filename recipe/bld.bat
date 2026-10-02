@echo on

set CARGO_PROFILE_RELEASE_STRIP=symbols
REM cmake is required by aws-lc-sys when CFLAGS inject -O2 (overrides -O0 in jitterentropy)
set AWS_LC_SYS_CMAKE_BUILDER=1
set CARGO_PROFILE_RELEASE_LTO=thin

REM path too long for pixi_config subpackage, https://github.com/prefix-dev/pixi/issues/3691
set CARGO_HOME=C:\.cargo
md %CARGO_HOME%

cargo auditable install --locked --no-default-features --features native-tls,recipe-generation,s3,sigstore,performance --bin rattler-build --root %PREFIX% --path . --no-track
if errorlevel 1 exit 1

cargo-bundle-licenses --format yaml --output %SRC_DIR%\THIRDPARTY.yml
if errorlevel 1 exit 1
