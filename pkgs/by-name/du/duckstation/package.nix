{
  lib,
  stdenv,
  llvmPackages,
  SDL2,
  callPackage,
  cmake,
  cpuinfo,
  cubeb,
  curl,
  extra-cmake-modules,
  libXrandr,
  libbacktrace,
  libwebp,
  makeWrapper,
  ninja,
  pkg-config,
  qt6,
  vulkan-loader,
  wayland,
  wayland-scanner,
}:

let
  sources = callPackage ./sources.nix { };
  inherit (qt6)
    qtbase
    qtsvg
    qttools
    qtwayland
    wrapQtAppsHook
    ;
in
llvmPackages.stdenv.mkDerivation (finalAttrs: {
  inherit (sources.duckstation) pname version src;

  patches = [
    # Tests are not built by default
    ./001-fix-test-inclusion.diff
    # Patching yet another script that fills data based on git commands . . .
    ./002-hardcode-vars.diff
    # Fix NEON intrinsics usage
    ./003-fix-NEON-intrinsics.patch
    ./remove-cubeb-vendor.patch
  ];

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    ninja
    pkg-config
    qttools
    wayland-scanner
    wrapQtAppsHook
  ];

  buildInputs = [
    SDL2
    cpuinfo
    cubeb
    curl
    libXrandr
    libbacktrace
    libwebp
    qtbase
    qtsvg
    qtwayland
    sources.discord-rpc-patched
    sources.lunasvg
    sources.shaderc-patched
    sources.soundtouch-patched
    sources.spirv-cross-patched
    wayland
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTS" true)
  ];

  strictDeps = true;

  doInstallCheck = true;

  postPatch = ''
    gitHash=$(cat .nixpkgs-auxfiles/git_hash) \
    gitBranch=$(cat .nixpkgs-auxfiles/git_branch) \
    gitTag=$(cat .nixpkgs-auxfiles/git_tag) \
    gitDate=$(cat .nixpkgs-auxfiles/git_date) \
      substituteAllInPlace src/scmversion/gen_scmversion.sh
  '';

  # error: cannot convert 'int16x8_t' to '__Int32x4_t'
  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.hostPlatform.isAarch64 "-flax-vector-conversions";

  installCheckPhase = ''
    runHook preInstallCheck

    $out/share/duckstation/common-tests

    runHook postInstallCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share

    cp -r bin $out/share/duckstation
    ln -s $out/share/duckstation/duckstation-qt $out/bin/

    install -Dm644 $src/scripts/org.duckstation.DuckStation.desktop $out/share/applications/org.duckstation.DuckStation.desktop
    install -Dm644 $src/scripts/org.duckstation.DuckStation.png $out/share/pixmaps/org.duckstation.DuckStation.png

    runHook postInstall
  '';

  qtWrapperArgs =
    let
      libPath = lib.makeLibraryPath ([
        sources.shaderc-patched
        sources.spirv-cross-patched
        vulkan-loader
      ]);
    in
    [
      "--prefix LD_LIBRARY_PATH : ${libPath}"
    ];

  # https://github.com/stenzek/duckstation/blob/master/scripts/appimage/apprun-hooks/default-to-x11.sh
  # Can't avoid the double wrapping, the binary wrapper from qtWrapperArgs doesn't support --run
  postFixup = ''
    source "${makeWrapper}/nix-support/setup-hook"
    wrapProgram $out/bin/duckstation-qt \
      --run 'if [[ -z $I_WANT_A_BROKEN_WAYLAND_UI ]]; then export QT_QPA_PLATFORM=xcb; fi'
  '';

  meta = {
    homepage = "https://github.com/stenzek/duckstation";
    description = "Fast PlayStation 1 emulator for x86-64/AArch32/AArch64";
    license = lib.licenses.gpl3Only;
    mainProgram = "duckstation-qt";
    maintainers = with lib.maintainers; [
      guibou
    ];
    platforms = lib.platforms.linux;
  };
})
