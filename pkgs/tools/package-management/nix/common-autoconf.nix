{
  lib,
  fetchFromGitHub,
  version,
  suffix ? "",
  hash ? null,
  src ? fetchFromGitHub {
    owner = "NixOS";
    repo = "nix";
    rev = version;
    inherit hash;
  },
  patches ? [ ],
  knownVulnerabilities ? [ ],
  maintainers ? [
    lib.maintainers.lovesegfault
    lib.maintainers.artturin
  ],
  teams ? [ lib.teams.nix ],
  self_attribute_name,
}@args:
assert (hash == null) -> (src != null);
let
  atLeast224 = lib.versionAtLeast version "2.24pre";
  atLeast225 = lib.versionAtLeast version "2.25pre";
in
{
  stdenv,
  autoconf-archive,
  autoreconfHook,
  bash,
  bison,
  boehmgc,
  boost,
  brotli,
  busybox-sandbox-shell,
  bzip2,
  callPackage,
  coreutils,
  curl,
  docbook_xsl_ns,
  docbook5,
  editline,
  flex,
  git,
  gnutar,
  gtest,
  gzip,
  jq,
  lib,
  libarchive,
  libcpuid,
  libgit2,
  libsodium,
  libxml2,
  libxslt,
  lowdown,
  lowdown-unsandboxed,
  toml11,
  man,
  mdbook,
  mdbook-linkcheck,
  nlohmann_json,
  nixosTests,
  openssl,
  perl,
  python3,
  pkg-config,
  rapidcheck,
  sqlite,
  util-linuxMinimal,
  xz,
  enableDocumentation ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
  enableStatic ? stdenv.hostPlatform.isStatic,
  withAWS ?
    lib.meta.availableOn stdenv.hostPlatform aws-c-common
    && !enableStatic
    && (stdenv.hostPlatform.isLinux || stdenv.hostPlatform.isDarwin),
  aws-c-common,
  aws-sdk-cpp,
  withLibseccomp ? lib.meta.availableOn stdenv.hostPlatform libseccomp,
  libseccomp,

  confDir,
  stateDir,
  storeDir,

  # passthru tests
  pkgsi686Linux,
  pkgsStatic,
  runCommand,
  pkgs,
}:
let
  self = stdenv.mkDerivation {
    pname = "nix";

    version = "${version}${suffix}";
    VERSION_SUFFIX = suffix;

    inherit src patches;

    outputs = [
      "out"
      "dev"
    ]
    ++ lib.optionals enableDocumentation [
      "man"
      "doc"
    ];

    hardeningEnable = lib.optionals (!stdenv.hostPlatform.isDarwin) [ "pie" ];

    hardeningDisable = [
      "shadowstack"
    ]
    ++ lib.optional stdenv.hostPlatform.isMusl "fortify";

    nativeInstallCheckInputs = lib.optionals atLeast224 [
      git
      man
    ];

    nativeBuildInputs = [
      pkg-config
      autoconf-archive
      autoreconfHook
      bison
      flex
      jq
    ]
    ++ lib.optionals enableDocumentation (
      if atLeast224 then
        [
          (lib.getBin lowdown-unsandboxed)
          mdbook
          mdbook-linkcheck
        ]
      else
        [
          libxslt
          libxml2
          docbook_xsl_ns
          docbook5
        ]
    )
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      util-linuxMinimal
    ];

    buildInputs = [
      boost
      brotli
      bzip2
      curl
      editline
      libsodium
      openssl
      sqlite
      xz
      gtest
      libarchive
      lowdown
    ]
    ++ lib.optionals atLeast224 [
      libgit2
      toml11
      rapidcheck
    ]
    ++ lib.optionals (atLeast225 && enableDocumentation) [
      python3
    ]
    ++ lib.optionals (stdenv.hostPlatform.isx86_64) [
      libcpuid
    ]
    ++ lib.optionals withLibseccomp [
      libseccomp
    ]
    ++ lib.optionals withAWS [
      aws-sdk-cpp
    ];

    propagatedBuildInputs = [
      boehmgc
    ]
    ++ lib.optionals atLeast224 [
      nlohmann_json
    ];

    postPatch = ''
      patchShebangs --build tests
    '';

    preConfigure =
      # Copy libboost_context so we don't get all of Boost in our closure.
      # https://github.com/NixOS/nixpkgs/issues/45462
      lib.optionalString (!enableStatic) ''
        mkdir -p $out/lib
        cp -pd ${boost}/lib/{libboost_context*,libboost_thread*,libboost_system*} $out/lib
        rm -f $out/lib/*.a
        ${lib.optionalString stdenv.hostPlatform.isLinux ''
          chmod u+w $out/lib/*.so.*
          patchelf --set-rpath $out/lib:${lib.getLib stdenv.cc.cc}/lib $out/lib/libboost_thread.so.*
        ''}
      ''
      +
        # On all versions before c9f51e87057652db0013289a95deffba495b35e7, which
        # removes config.nix entirely and is not present in 2.3.x, we need to
        # patch around an issue where the Nix configure step pulls in the build
        # system's bash and other utilities when cross-compiling.
        lib.optionalString (stdenv.buildPlatform != stdenv.hostPlatform && !atLeast224) ''
          mkdir tmp/
          substitute corepkgs/config.nix.in tmp/config.nix.in \
            --subst-var-by bash ${bash}/bin/bash \
            --subst-var-by coreutils ${coreutils}/bin \
            --subst-var-by bzip2 ${bzip2}/bin/bzip2 \
            --subst-var-by gzip ${gzip}/bin/gzip \
            --subst-var-by xz ${xz}/bin/xz \
            --subst-var-by tar ${gnutar}/bin/tar \
            --subst-var-by tr ${coreutils}/bin/tr
          mv tmp/config.nix.in corepkgs/config.nix.in
        '';

    configureFlags = [
      "--with-store-dir=${storeDir}"
      "--localstatedir=${stateDir}"
      "--sysconfdir=${confDir}"
      "--enable-gc"
    ]
    ++ lib.optionals (!enableDocumentation) [
      "--disable-doc-gen"
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      "--with-sandbox-shell=${busybox-sandbox-shell}/bin/busybox"
    ]
    ++ lib.optionals (atLeast224 && stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isStatic) [
      "--enable-embedded-sandbox-shell"
    ]
    ++
      lib.optionals
        (
          stdenv.hostPlatform != stdenv.buildPlatform
          && stdenv.hostPlatform ? nix
          && stdenv.hostPlatform.nix ? system
        )
        [
          "--with-system=${stdenv.hostPlatform.nix.system}"
        ]
    ++ lib.optionals (!withLibseccomp) [
      # RISC-V support in progress https://github.com/seccomp/libseccomp/pull/50
      "--disable-seccomp-sandboxing"
    ]
    ++ lib.optionals (atLeast224 && stdenv.cc.isGNU && !enableStatic) [
      "--enable-lto"
    ];

    env.CXXFLAGS = toString (
      lib.optionals (lib.versionAtLeast lowdown.version "1.4.0") [
        # Autotools based build system wasn't updated with the backport of
        # https://github.com/NixOS/nix/pull/12115, so set the define explicitly.
        "-DHAVE_LOWDOWN_1_4"
      ]
    );

    makeFlags = [
      # gcc runs multi-threaded LTO using make and does not yet detect the new fifo:/path style
      # of make jobserver. until gcc adds support for this we have to instruct make to use this
      # old style or LTO builds will run their linking on only one thread, which takes forever.
      "--jobserver-style=pipe"
      "profiledir=$(out)/etc/profile.d"
    ]
    ++ lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) "PRECOMPILE_HEADERS=0"
    ++ lib.optional (stdenv.hostPlatform.isDarwin) "PRECOMPILE_HEADERS=1";

    installFlags = [ "sysconfdir=$(out)/etc" ];

    doInstallCheck = true;
    installCheckTarget = if atLeast224 then "installcheck" else null;

    # socket path becomes too long otherwise
    preInstallCheck =
      lib.optionalString stdenv.hostPlatform.isDarwin ''
        export TMPDIR=$NIX_BUILD_TOP
      ''
      # Prevent crashes in libcurl due to invoking Objective-C `+initialize` methods after `fork`.
      # See http://sealiesoftware.com/blog/archive/2017/6/5/Objective-C_and_fork_in_macOS_1013.html.
      + lib.optionalString stdenv.hostPlatform.isDarwin ''
        export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
      ''
      # See https://github.com/NixOS/nix/issues/5687
      + lib.optionalString (atLeast224 && stdenv.hostPlatform.isDarwin) ''
        echo "exit 99" > tests/gc-non-blocking.sh
      '' # TODO: investigate why this broken
      + lib.optionalString (atLeast224 && stdenv.hostPlatform.system == "aarch64-linux") ''
        echo "exit 0" > tests/functional/flakes/show.sh
      ''
      + ''
        # nixStatic otherwise does not find its man pages in tests.
        export MANPATH=$man/share/man:$MANPATH
      '';

    separateDebugInfo = stdenv.hostPlatform.isLinux && (atLeast224 -> !enableStatic);

    enableParallelBuilding = true;

    passthru = {
      inherit aws-sdk-cpp boehmgc;

      perl-bindings = perl.pkgs.toPerlModule (
        callPackage ./nix-perl.nix {
          nix = self;
        }
      );

      tests = import ./tests.nix {
        inherit
          runCommand
          version
          src
          lib
          stdenv
          pkgs
          pkgsi686Linux
          pkgsStatic
          nixosTests
          self_attribute_name
          ;
        nix = self;
      };
    };

    # point 'nix edit' and ofborg at the file that defines the attribute,
    # not this common file.
    pos = builtins.unsafeGetAttrPos "version" args;
    meta = with lib; {
      description = "Powerful package manager that makes package management reliable and reproducible";
      longDescription = ''
        Nix is a powerful package manager for Linux and other Unix systems that
        makes package management reliable and reproducible. It provides atomic
        upgrades and rollbacks, side-by-side installation of multiple versions of
        a package, multi-user package management and easy setup of build
        environments.
      '';
      homepage = "https://nixos.org/";
      license = licenses.lgpl21Plus;
      inherit knownVulnerabilities maintainers teams;
      platforms = platforms.unix;
      outputsToInstall = [ "out" ] ++ optional enableDocumentation "man";
      mainProgram = "nix";
    };
  };
in
self
