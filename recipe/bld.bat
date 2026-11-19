@echo on

set CARGO_PROFILE_RELEASE_STRIP=symbols
REM aws-lc-sys jitterentropy.c must stay -O0; conda CFLAGS inject -O2.
REM cmake builder honors that; the default cc-rs path does not.
set AWS_LC_SYS_CMAKE_BUILDER=1
set CARGO_PROFILE_RELEASE_LTO=thin

REM AWS-LC's CMakeLists.txt requires the ClangCL toolset for win-arm64
REM assembly ("Windows/ARM64 assembly code requires ClangCL"); the MSVC
REM "Visual Studio" generator needs that as an MSBuild toolset plugin,
REM which isn't available here, so use aws-lc-sys's Ninja path instead
REM (cmake_builder.rs skips the ClangCL toolset requirement when
REM CMAKE_GENERATOR=Ninja) - it only needs clang-cl.exe + ninja on PATH.
if "%target_platform%" == "win-arm64" set CC=clang-cl
if "%target_platform%" == "win-arm64" set CMAKE_GENERATOR=Ninja

REM win-arm64: croot's deep, timestamped build path pushes aws-lc-sys's
REM nested jitterentropy object paths past Windows' 260-char MAX_PATH /
REM CMake's 250-char CMAKE_OBJECT_PATH_MAX (neither cmake nor MSVC's
REM lib.exe/link.exe are long-path aware - no workaround upstream, see
REM aws/aws-lc-rs#780). Relocate CARGO_TARGET_DIR to a short path.
if "%target_platform%" == "win-arm64" set CARGO_TARGET_DIR=C:\clb
if "%target_platform%" == "win-arm64" md %CARGO_TARGET_DIR%

REM path too long for pixi_config subpackage, https://github.com/prefix-dev/pixi/issues/3691
set CARGO_HOME=C:\.cargo
md %CARGO_HOME%

REM native-tls = Schannel (TLS 1.3). rustls is only needed on macOS (SecureTransport).
cargo auditable install --locked --no-default-features --features native-tls,recipe-generation,s3,sigstore,performance --bin rattler-build --root %PREFIX% --path . --no-track
if errorlevel 1 exit 1

cargo-bundle-licenses --format yaml --output %SRC_DIR%\THIRDPARTY.yml
if errorlevel 1 exit 1
