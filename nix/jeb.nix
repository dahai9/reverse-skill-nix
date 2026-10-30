{ pkgs }:
let
  version = "5.38.0.202603112011";
  libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    gtk3
    webkitgtk_4_1
    libsoup_3
    pango
    cairo
    atk
    gdk-pixbuf
    libGL
    libX11
    libXext
    libXrender
    libXtst
    libXi
    libXcursor
    libXrandr
  ];
  libraryPath = pkgs.lib.makeLibraryPath libraries;
  gioModules = "${pkgs.glib-networking}/lib/gio/modules";
  pixbufModules = "${pkgs.lib.getLib pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
  dataDirs = pkgs.lib.makeSearchPath "share" [
    pkgs.shared-mime-info
    pkgs.adwaita-icon-theme
    pkgs.hicolor-icon-theme
  ];
  payload = pkgs.stdenvNoCC.mkDerivation {
    pname = "jeb-pro-data";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/dahai9/reverse-tools-assets/releases/download/jeb-5.38.0/jeb-5.38.0.202603112011.7z";
      hash = "sha256-cVi9oagCh0g7vdVHm4xkSqMVnBk9j4/9G/0GI4uyHuk=";
    };
    nativeBuildInputs = [ pkgs._7zz ];
    unpackPhase = ''
      runHook preUnpack
      mkdir source
      7zz x -y "$src" -osource > /dev/null
      runHook postUnpack
    '';
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/jeb"
      cp -R source/. "$out/share/jeb/"
      cp "$out/share/jeb/bin/app/.swt/lin64/swt.jar" "$out/share/jeb/bin/app/swt.jar"
      test -s "$out/share/jeb/bin/app/jeb.jar"
      test -s "$out/share/jeb/bin/app/jebc.jar"
      runHook postInstall
    '';
    dontFixup = true;
  };
  launcher = pkgs.writeShellApplication {
    name = "jeb";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      if [[ "''${1-}" == --version ]]; then
        printf 'JEB ${version}\n'
        exit 0
      fi
      app=jebc.jar
      if [[ "''${1-}" == --console ]]; then
        app=jeb.jar
        shift
      fi
      data_root="''${XDG_DATA_HOME:-$HOME/.local/share}/reverse-tools/jeb"
      install_dir="$data_root/${version}"
      mkdir -p "$data_root"
      # Only initialization is locked; separate GUI/CLI launches may run together.
      exec 9>"$data_root/.${version}.lock"
      flock 9
      if [[ ! -f "$install_dir/.nix-initialized" ]]; then
        if [[ -e "$install_dir" ]]; then
          printf 'Incomplete JEB installation: %s. Move it aside before retrying.\n' "$install_dir" >&2
          exit 1
        fi
        staging=$(mktemp -d "$data_root/.${version}.XXXXXXXX")
        trap 'rm -rf -- "$staging"' EXIT
        cp -R --reflink=auto ${payload}/share/jeb/. "$staging/"
        chmod -R u+w "$staging"
        touch "$staging/.nix-initialized"
        mv "$staging" "$install_dir"
        trap - EXIT
      fi
      flock -u 9
      exec 9>&-
      export JAVA_HOME=${pkgs.jdk17}
      export LD_LIBRARY_PATH="${libraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      export GIO_EXTRA_MODULES="${gioModules}''${GIO_EXTRA_MODULES:+:$GIO_EXTRA_MODULES}"
      export GDK_PIXBUF_MODULE_FILE="${pixbufModules}"
      export XDG_DATA_DIRS="${dataDirs}:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
      export SWT_GTK3=1
      jvm_options=(-Xmx8G -Djava.security.manager=allow --add-opens=java.base/java.lang=ALL-UNNAMED)
      if [[ -n "''${JEB_JAVA_OPTS:-}" ]]; then
        read -r -a extra_options <<< "$JEB_JAVA_OPTS"
        jvm_options+=("''${extra_options[@]}")
      fi
      # Match the shipped Java entry points without running the self-updater.
      # Preserve the caller's working directory, including relative input paths.
      exec ${pkgs.jdk17}/bin/java "''${jvm_options[@]}" -jar "$install_dir/bin/app/$app" "$@"
    '';
  };
  console = pkgs.writeShellApplication {
    name = "jeb-cli";
    text = ''exec ${launcher}/bin/jeb --console "$@"'';
  };
  icons = pkgs.runCommand "jeb-icons-${version}" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    for size in 16 32 48 128 256; do
      target="$out/share/icons/hicolor/''${size}x''${size}/apps"
      mkdir -p "$target"
      unzip -p ${payload}/share/jeb/bin/app/jebc.jar "icons/program/jeb_''${size}px.png" > "$target/jeb.png"
      test -s "$target/jeb.png"
    done
  '';
  desktop = pkgs.makeDesktopItem {
    name = "JEB";
    desktopName = "JEB Pro";
    comment = "JEB decompiler";
    exec = "${launcher}/bin/jeb %F";
    icon = "${icons}/share/icons/hicolor/256x256/apps/jeb.png";
    startupWMClass = "JEB";
    startupNotify = true;
    categories = [ "Development" ];
    extraConfig.X-ReverseTools-Managed = "true";
  };
  installDesktop = pkgs.writeShellApplication {
    name = "jeb-install-desktop";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    text = ''
      target="''${XDG_DATA_HOME:-$HOME/.local/share}/applications/JEB.desktop"
      if [[ -e "$target" ]] && ! grep -q '^X-ReverseTools-Managed=true$' "$target"; then
        printf 'Existing unmanaged desktop entry left unchanged: %s\n' "$target" >&2
        exit 0
      fi
      install -Dm644 ${desktop}/share/applications/JEB.desktop "$target"
    '';
  };
  desktopLauncher = pkgs.writeShellApplication {
    name = "jeb";
    text = ''
      if [[ "''${1-}" != --version && "''${1-}" != --console ]]; then
        ${installDesktop}/bin/jeb-install-desktop
      fi
      exec ${launcher}/bin/jeb "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "jeb-pro-${version}";
  paths = [
    desktopLauncher
    console
    icons
    desktop
    installDesktop
  ];
  passthru = {
    inherit payload version;
    tests.desktop =
      pkgs.runCommand "jeb-desktop-smoke"
        {
          nativeBuildInputs = [ pkgs.desktop-file-utils ];
        }
        ''
          desktop-file-validate ${desktop}/share/applications/JEB.desktop
          export XDG_DATA_HOME="$TMPDIR/data"
          ${installDesktop}/bin/jeb-install-desktop
          cmp ${desktop}/share/applications/JEB.desktop "$XDG_DATA_HOME/applications/JEB.desktop"
          # Re-registration must preserve a desktop entry managed by the user.
          printf '[Desktop Entry]\nName=Custom JEB\n' > "$XDG_DATA_HOME/applications/JEB.desktop"
          ${installDesktop}/bin/jeb-install-desktop
          grep -q '^Name=Custom JEB$' "$XDG_DATA_HOME/applications/JEB.desktop"
          touch "$out"
        '';
    tests.browser =
      pkgs.runCommand "jeb-swt-browser-smoke"
        {
          nativeBuildInputs = [
            pkgs.jdk17
            pkgs.xvfb-run
            pkgs.stdenv.cc
            pkgs.pkg-config
          ];
          buildInputs = [ pkgs.gtk3 ];
          LD_LIBRARY_PATH = libraryPath;
          GIO_EXTRA_MODULES = gioModules;
          GDK_PIXBUF_MODULE_FILE = pixbufModules;
          XDG_DATA_DIRS = dataDirs;
        }
        ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          # The build sandbox already isolates this local-HTML test. Nested WebKit
          # namespace sandboxing is unavailable inside Nix's build sandbox.
          export WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS=1
          export LIBGL_ALWAYS_SOFTWARE=1
          export WEBKIT_DISABLE_DMABUF_RENDERER=1
          swt=${payload}/share/jeb/bin/app/swt.jar
          cc ${../tests/GtkResourcesSmoke.c} -o gtk-resources-smoke $(pkg-config --cflags --libs gtk+-3.0)
          G_DEBUG=fatal-warnings timeout 20 xvfb-run -a ./gtk-resources-smoke
          cp ${../tests/SwtBrowserSmoke.java} SwtBrowserSmoke.java
          javac -cp "$swt" -d . SwtBrowserSmoke.java
          timeout 45 xvfb-run -a java -cp ".:$swt" SwtBrowserSmoke
          touch "$out"
        '';
  };
  meta = {
    description = "JEB decompiler with Linux GUI and console launchers";
    homepage = "https://www.pnfsoftware.com/jeb/";
    license = pkgs.lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "jeb";
  };
}
