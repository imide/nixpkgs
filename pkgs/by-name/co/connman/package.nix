{
  lib,
  stdenv,
  fetchurl,
  fetchpatch,
  autoreconfHook,
  dbus,
  file,
  glib,
  gnutls,
  iptables,
  libmnl,
  libnftnl, # for nftables
  nixosTests,
  openconnect,
  openvpn,
  pkg-config,
  polkit,
  ppp,
  pptp,
  readline,
  vpnc,
  dnsType ? "internal", # or "systemd-resolved"
  enableBluetooth ? true,
  enableClient ? true,
  enableDatafiles ? true,
  enableDundee ? true,
  enableEthernet ? true,
  enableGadget ? true,
  enableHh2serialGps ? false,
  enableIospm ? false,
  enableL2tp ? false,
  enableLoopback ? true,
  enableNeard ? true,
  enableNetworkManager ? null,
  enableNetworkManagerCompatibility ?
    if enableNetworkManager == null then
      false
    else
      lib.warn "enableNetworkManager option is deprecated; use enableNetworkManagerCompatibility instead" enableNetworkManager,
  enableOfono ? true,
  enableOpenconnect ? true,
  enableOpenvpn ? true,
  enablePacrunner ? true,
  enablePolkit ? true,
  enablePptp ? true,
  enableStats ? true,
  enableTist ? false,
  enableTools ? true,
  enableVpnc ? true,
  enableWifi ? true,
  enableWireguard ? true,
  enableWispr ? true,
  firewallType ? "iptables", # or "nftables"
}:

let
  inherit (lib)
    enableFeature
    enableFeatureAs
    optionals
    withFeatureAs
    ;
in
assert lib.asserts.assertOneOf "firewallType" firewallType [
  "iptables"
  "nftables"
];
assert lib.asserts.assertOneOf "dnsType" dnsType [
  "internal"
  "systemd-resolved"
];
stdenv.mkDerivation (finalAttrs: {
  pname = "connman";
  version = "1.43";

  src = fetchurl {
    url = "mirror://kernel/linux/network/connman/connman-${finalAttrs.version}.tar.xz";
    hash = "sha256-ElfOvjJ+eQC34rhMD7MwqpCBXkVYmM0vlB9DCO0r47w=";
  };

  patches = [
    (fetchpatch {
      name = "CVE-2025-32366.patch";
      url = "https://git.kernel.org/pub/scm/network/connman/connman.git/patch/?id=8d3be0285f1d4667bfe85dba555c663eb3d704b4";
      hash = "sha256-kPb4pZVWvnvTUcpc4wRc8x/pMUTXGIywj3w8IYKRTBs=";
    })
    (fetchpatch {
      name = "CVE-2025-32743.patch";
      url = "https://git.kernel.org/pub/scm/network/connman/connman.git/patch/?id=d90b911f6760959bdf1393c39fe8d1118315490f";
      hash = "sha256-odkjYC/iM6dTIJx2WM/KKotXdTtgv8NMFNJMzx5+YU4=";
    })
  ]
  ++ optionals stdenv.hostPlatform.isMusl [
    # Fix Musl build by avoiding a Glibc-only API.
    (fetchurl {
      url = "https://git.alpinelinux.org/aports/plain/community/connman/libresolv.patch?id=e393ea84386878cbde3cccadd36a30396e357d1e";
      hash = "sha256-7Q1bp8rD/gGVYUqnIXqjr9vypR8jlC926p3KYWl9kLw=";
    })
  ];

  nativeBuildInputs = [
    autoreconfHook
    file
    pkg-config
  ];

  buildInputs = [
    glib
    dbus
    libmnl
    gnutls
    readline
  ]
  ++ optionals (firewallType == "iptables") [ iptables ]
  ++ optionals (firewallType == "nftables") [ libnftnl ]
  ++ optionals (enableOpenconnect) [ openconnect ]
  ++ optionals (enablePolkit) [ polkit ]
  ++ optionals (enablePptp) [
    pptp
    ppp
  ];

  postPatch = ''
    sed -i "s@/usr/bin/file@file@g" ./configure
  '';

  configureFlags = [
    # directories flags
    "--sysconfdir=/etc"
    "--localstatedir=/var"
  ]
  ++ [
    # production build flags
    (enableFeature false "maintainer-mode")
    (enableFeatureAs true "session-policy-local" "builtin")
    # for building and running tests
    # (enableFeature true "tests") # installs the tests, we don't want that
    (enableFeature true "tools")
    (enableFeature enableLoopback "loopback")
    (enableFeature enableEthernet "ethernet")
    (enableFeature enableWireguard "wireguard")
    (enableFeature enableGadget "gadget")
    (enableFeature enableWifi "wifi")
    # enable IWD support for wifi as it doesn't require any new dependencies and
    # it's easier for the NixOS module to use only one connman package when IWD
    # is requested
    (enableFeature enableWifi "iwd")
    (enableFeature enableBluetooth "bluetooth")
    (enableFeature enableOfono "ofono")
    (enableFeature enableDundee "dundee")
    (enableFeature enablePacrunner "pacrunner")
    (enableFeature enableNeard "neard")
    (enableFeature enableWispr "wispr")
    (enableFeature enableTools "tools")
    (enableFeature enableStats "stats")
    (enableFeature enableClient "client")
    (enableFeature enableDatafiles "datafiles")
    (enableFeature enablePolkit "polkit")
    (enableFeature enablePptp "pptp")
    (enableFeature enableWireguard "wireguard")
    (enableFeature enableNetworkManagerCompatibility "nmcompat")
    (enableFeature enableHh2serialGps "hh2serial-gps")
    (enableFeature enableL2tp "l2tp")
    (enableFeature enableIospm "iospm")
    (enableFeature enableTist "tist")
  ]
  ++ [
    (enableFeatureAs enableOpenconnect "openconnect" "builtin")
    (enableFeatureAs enableOpenvpn "openvpn" "builtin")
    (enableFeatureAs enableVpnc "vpnc" "builtin")
  ]
  ++ [
    (withFeatureAs true "dbusconfdir" "${placeholder "out"}/share")
    (withFeatureAs true "dbusdatadir" "${placeholder "out"}/share")
    (withFeatureAs true "tmpfilesdir" "${placeholder "out"}/tmpfiles.d")
    (withFeatureAs true "systemdunitdir" "${placeholder "out"}/systemd/system")
    (withFeatureAs true "dns-backend" "${dnsType}")
    (withFeatureAs true "firewall" "${firewallType}")
    (withFeatureAs enableOpenconnect "openconnect" "${openconnect}/sbin/openconnect")
    (withFeatureAs enableOpenvpn "openvpn" "${openvpn}/sbin/openvpn")
    (withFeatureAs enableVpnc "vpnc" "${vpnc}/sbin/vpnc")
    (withFeatureAs enablePptp "pptp" "${pptp}/sbin/pptp")
  ];

  doCheck = true;

  passthru.tests.connman = nixosTests.connman;

  meta = {
    description = "Daemon for managing internet connections";
    homepage = "https://git.kernel.org/pub/scm/network/connman/connman.git/about/";
    license = lib.licenses.gpl2Only;
    mainProgram = "connmanctl";
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
  };
})
