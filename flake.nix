{
  description = "Reverse Tools: reverse-skill 的 NixOS 工具环境";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };
      tools = import ./nix/tools.nix { inherit pkgs; };
      mkShell =
        name: groups:
        let
          packages = pkgs.lib.unique (pkgs.lib.concatMap (g: tools.groups.${g}) groups);
          python = pkgs.python312.withPackages (
            ps: pkgs.lib.unique (pkgs.lib.concatMap (g: tools.pythonGroups.${g} ps) groups)
          );
          hasAndroid = builtins.elem "android" groups;
          hasWeb = builtins.elem "web" groups;
        in
        pkgs.mkShell {
          name = "reverse-tools-${name}";
          packages = packages ++ [ python ];
          JAVA_HOME = "${pkgs.jdk}";
          PYTHONNOUSERSITE = "1";
          UV_PYTHON = "${python}/bin/python3";
          UV_PYTHON_DOWNLOADS = "never";
          shellHook = ''
            export REVERSE_SKILL_ROOT="$PWD/reverse-skill"
            printf 'Reverse Tools [%s] — groups: %s\n' '${name}' '${builtins.concatStringsSep ", " groups}'
          ''
          + pkgs.lib.optionalString hasAndroid ''
            export ANDROID_HOME="${tools.androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export PATH="$ANDROID_HOME/build-tools/${tools.buildToolsVersion}:$PATH"
          ''
          + pkgs.lib.optionalString hasWeb ''
            export PLAYWRIGHT_BROWSERS_PATH="${pkgs.playwright-driver.browsers}"
            export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
            export AGENT_BROWSER_EXECUTABLE_PATH="${pkgs.chromium}/bin/chromium"
          '';
        };
      allGroups = builtins.attrNames tools.groups;
    in
    {
      packages.${system} = {
        jeb = tools.jeb;
        ida-pro = tools.ida;
        ida-pro-unpatched = tools.ida.override { withPatches = false; };
      };
      checks.${system} = {
        jeb-browser = tools.jeb.tests.browser;
        jeb-desktop = tools.jeb.tests.desktop;
      };
      apps.${system} = {
        ida = {
          type = "app";
          program = "${tools.ida}/bin/ida";
        };
        idat = {
          type = "app";
          program = "${tools.ida}/bin/idat";
        };
        jeb = {
          type = "app";
          program = "${tools.jeb}/bin/jeb";
        };
        jeb-cli = {
          type = "app";
          program = "${tools.jeb}/bin/jeb-cli";
        };
      };
      devShells.${system} = {
        default = mkShell "full" allGroups;
        full = mkShell "full" allGroups;
      }
      // builtins.listToAttrs (
        map (name: {
          inherit name;
          value = mkShell name (
            pkgs.lib.unique [
              "core"
              name
            ]
          );
        }) allGroups
      );
      formatter.${system} = pkgs.nixfmt;
    };
}
