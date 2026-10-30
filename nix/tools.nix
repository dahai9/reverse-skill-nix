{ pkgs }:
let
  jeb = import ./jeb.nix { inherit pkgs; };
  ida = pkgs.callPackage ./ida-pro { };
  buildToolsVersion = "35.0.0";
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      buildToolsVersions = [ buildToolsVersion ];
      platformVersions = [ ];
      includeEmulator = false;
      includeSystemImages = false;
      includeSources = false;
      includeNDK = false;
    }).androidsdk;
in
{
  inherit
    androidSdk
    buildToolsVersion
    jeb
    ida
    ;

  # No missing package is silently skipped: evaluation fails if coverage drifts.
  groups = with pkgs; {
    core = [
      bashInteractive
      git
      curl
      wget
      cacert
      unzip
      zip
      gnutar
      jq
      ripgrep
      file
      which
      coreutils
      findutils
      gnused
      gawk
      jdk
      nodejs_24
      pnpm
      uv
      go
      rustc
      cargo
    ];
    android = [
      jeb
      androidSdk
      jadx
      apktool
      frida-tools
      objection
    ];
    binary = [
      ida
      radare2
      ghidra
      gdb
      binutils
      gcc
      gnumake
      cmake
      pkg-config
      strace
      ltrace
      patchelf
    ];
    web = [
      agent-browser
      playwright-driver
      chromium
      mitmproxy
      burpsuite
      wireshark
      tcpdump
      docker-client
    ];
    pentest = [
      nmap
      nuclei
      sqlmap
      ffuf
      hashcat
      seclists
    ];
    analysis = [
      binwalk
      yara
      bkcrack
    ];
    reports = [
      graphviz
      plantuml
      mermaid-cli
      pandoc
    ];
  };

  # One interpreter per shell prevents competing Python environments on PATH.
  pythonGroups = {
    core =
      ps: with ps; [
        requests
        beautifulsoup4
        lxml
      ];
    android = ps: with ps; [ frida-python ];
    binary =
      ps: with ps; [
        capstone
        unicorn
        lief
        pefile
        pyelftools
      ];
    web = ps: with ps; [ playwright ];
    pentest = ps: [ ];
    analysis =
      ps: with ps; [
        pwntools
        angr
        yara-python
      ];
    reports =
      ps: with ps; [
        python-docx
        openpyxl
        reportlab
        pillow
      ];
  };
}
