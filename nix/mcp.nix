{ pkgs, jadxPackage }:
let
  inherit (pkgs) lib;
  idaSource = pkgs.fetchzip {
    url = "https://github.com/mrexodia/ida-pro-mcp/archive/f82e6e2517a161b77e738951c3071cd446480ba0.tar.gz";
    sha256 = "0k3hj8i99kmvyzs92z1gx7rf0b1lr2ax7k7n7xy0xzib66w8yacx";
  };
  idaPython = pkgs.python312.withPackages (ps: [ ps.tomli-w ]);
  # The bridge only uses local stdio. Validate that surface with our smoke check;
  # do not pull cloud SDKs and service emulators solely for FastMCP's tests.
  keyValueRuntime = pkgs.python312Packages.py-key-value-aio.overridePythonAttrs {
    doCheck = false;
    nativeCheckInputs = [ ];
  };
  fastmcpRuntime =
    (pkgs.python312Packages.fastmcp.override {
      py-key-value-aio = keyValueRuntime;
    }).overridePythonAttrs
      {
        doCheck = false;
        nativeCheckInputs = [ ];
      };
  # The GUI plugin and stdio proxy do not require the separate idalib SDK.
  idapro = pkgs.stdenvNoCC.mkDerivation {
    pname = "ida-pro-mcp";
    version = "2.0.0-f82e6e2";
    src = idaSource;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/ida-pro-mcp" "$out/bin"
      cp -r src/ida_pro_mcp "$out/share/ida-pro-mcp/"
      cp LICENSE "$out/share/ida-pro-mcp/"
      makeWrapper ${idaPython}/bin/python3 "$out/bin/ida-pro-mcp" \
        --add-flags "$out/share/ida-pro-mcp/ida_pro_mcp/server.py"
      runHook postInstall
    '';
    meta = {
      description = "IDA Pro GUI MCP plugin and stdio proxy";
      homepage = "https://github.com/mrexodia/ida-pro-mcp";
      license = lib.licenses.mit;
      mainProgram = "ida-pro-mcp";
      platforms = [ "x86_64-linux" ];
    };
  };
  jadx = pkgs.python312Packages.buildPythonApplication {
    pname = "jadx-mcp-server";
    version = "6.5.0-a8e5b7d";
    pyproject = true;
    src = pkgs.fetchzip {
      url = "https://github.com/zinja-coder/jadx-mcp-server/archive/a8e5b7de4f7d7f9ef0ccea9d063631133105bd34.tar.gz";
      sha256 = "04knb42g4nr4g0y8d06lzp403jvw34vbcq1lsnawfnk00inly7z7";
    };
    build-system = [ pkgs.python312Packages.setuptools ];
    dependencies = with pkgs.python312Packages; [
      fastmcpRuntime
      httpx
      requests
    ];
    pythonImportsCheck = [
      "jadx_mcp_server"
      "src.server.config"
    ];
    makeWrapperArgs = [ "--set-default FASTMCP_CHECK_FOR_UPDATES off" ];
    meta = {
      description = "MCP stdio bridge for the JADX AI plugin";
      homepage = "https://github.com/zinja-coder/jadx-mcp-server";
      license = lib.licenses.asl20;
      mainProgram = "jadx_mcp_server";
      platforms = [ "x86_64-linux" ];
    };
  };
  jadxPluginSource = pkgs.fetchurl {
    url = "https://github.com/zinja-coder/jadx-ai-mcp/releases/download/v6.5.0/jadx-ai-mcp-6.5.0.jar";
    sha256 = "adff61083c63b6cd45bf828ed34b00ae212ba2ac35785593645504955f1cbcca";
  };
  jadxPlugin =
    pkgs.runCommand "jadx-ai-mcp-6.5.0-loopback.jar"
      {
        nativeBuildInputs = [
          pkgs.jdk17
          pkgs.unzip
        ];
      }
      ''
        cp ${./PatchJadxLoopback.java} PatchJadxLoopback.java
        exports=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED
        javac --add-exports "$exports" PatchJadxLoopback.java
        class=com/zin/jadxaimcp/server/PluginServer.class
        mkdir -p patched/com/zin/jadxaimcp/server
        unzip -p ${jadxPluginSource} "$class" > original.class
        java --add-exports "$exports" PatchJadxLoopback original.class "patched/$class"
        cp ${jadxPluginSource} "$out"
        chmod u+w "$out"
        jar --update --file "$out" -C patched "$class"
      '';
  install = pkgs.writeShellApplication {
    name = "install-reverse-mcp";
    runtimeInputs = [
      pkgs.coreutils
      jadxPackage
    ];
    text = ''
      command -v codex >/dev/null || { echo 'codex must be on PATH' >&2; exit 1; }
      command -v nix-store >/dev/null || { echo 'nix-store must be on PATH' >&2; exit 1; }
      roots="''${XDG_DATA_HOME:-$HOME/.local/share}/reverse-tools/mcp/nix-roots"
      mkdir -p "$roots"
      nix-store --add-root "$roots/idapro" --realise ${idapro} >/dev/null
      nix-store --add-root "$roots/jadx" --realise ${jadx} >/dev/null
      plugin_dir="''${IDAUSR:-$HOME/.idapro}/plugins"
      mkdir -p "$plugin_dir"
      for item in ida_mcp.py ida_mcp; do
        target="${idapro}/share/ida-pro-mcp/ida_pro_mcp/$item"
        destination="$plugin_dir/$item"
        if [[ -e "$destination" || -L "$destination" ]]; then
          if [[ "$(readlink -f "$destination")" == "$target" ]]; then
            continue
          fi
          mv -- "$destination" "$destination.backup.$(date +%s%N)"
        fi
        ln -s -- "$target" "$destination"
      done
      jadx plugins --install-jar ${jadxPlugin}
      config="''${CODEX_HOME:-$HOME/.codex}/config.toml"
      if [[ -f "$config" ]]; then
        cp -p -- "$config" "$config.backup.$(date +%s%N)"
      fi
      codex mcp add idapro -- ${idapro}/bin/ida-pro-mcp
      codex mcp add jadx -- ${jadx}/bin/jadx_mcp_server
      codex mcp add jeb --url http://localhost:8425/mcp
      echo 'Installed IDA/JADX plugins and registered idapro + jadx + jeb in Codex.'
      echo 'Restart IDA, open an APK in jadx-gui, then start a new Codex session.'
      echo 'For JEB, start its built-in MCP server from the GUI before connecting.'
    '';
  };
  smoke =
    pkgs.runCommand "reverse-mcp-stdio-smoke"
      {
        nativeBuildInputs = [ pkgs.python312 ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        export FASTMCP_CHECK_FOR_UPDATES=off
        python3 ${../tests/McpSmoke.py} ${idapro}/bin/ida-pro-mcp ${jadx}/bin/jadx_mcp_server
        touch "$out"
      '';
  pluginSmoke =
    pkgs.runCommand "jadx-mcp-plugin-smoke"
      {
        nativeBuildInputs = [ pkgs.jdk17 ];
      }
      ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        # Match JADX's parent-first plugin classloader: host libraries precede JAR.
        classpath="${jadxPackage}/share/jadx/lib/*:${jadxPlugin}"
        cp ${../tests/JadxPluginSmoke.java} JadxPluginSmoke.java
        javac -cp "$classpath" -d . JadxPluginSmoke.java
        timeout 30 java -cp ".:$classpath" JadxPluginSmoke
        touch "$out"
      '';
in
{
  inherit
    idapro
    jadx
    jadxPlugin
    install
    smoke
    pluginSmoke
    ;
}
