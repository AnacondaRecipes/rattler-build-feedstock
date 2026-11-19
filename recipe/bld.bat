@echo on

set CARGO_PROFILE_RELEASE_STRIP=symbols
REM aws-lc-sys jitterentropy.c must stay -O0; conda CFLAGS inject -O2.
REM cmake builder honors that; the default cc-rs path does not.
set AWS_LC_SYS_CMAKE_BUILDER=1
set CARGO_PROFILE_RELEASE_LTO=thin

REM AWS-LC's CMakeLists.txt requires the ClangCL toolset for win-arm64
REM assembly; plain MSVC is rejected ("Windows/ARM64 assembly code
REM requires ClangCL"). clang-cl is a drop-in cl.exe replacement.
if "%target_platform%" == "win-arm64" set CC=clang-cl

REM path too long for pixi_config subpackage, https://github.com/prefix-dev/pixi/issues/3691
set CARGO_HOME=C:\.cargo
md %CARGO_HOME%

REM native-tls = Schannel (TLS 1.3). rustls is only needed on macOS (SecureTransport).
cargo auditable install --locked --no-default-features --features native-tls,recipe-generation,s3,sigstore,performance --bin rattler-build --root %PREFIX% --path . --no-track
if errorlevel 1 exit 1

cargo-bundle-licenses --format yaml --output %SRC_DIR%\THIRDPARTY.yml
if errorlevel 1 exit 1
