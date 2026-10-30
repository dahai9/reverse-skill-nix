{ pkgs }:
pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "jadx";
  version = "1.5.6";
  src = pkgs.fetchurl {
    url = "https://github.com/skylot/jadx/releases/download/v${finalAttrs.version}/jadx-${finalAttrs.version}.zip";
    sha256 = "545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974";
  };
  nativeBuildInputs = [
    pkgs.unzip
    pkgs.makeWrapper
  ];
  sourceRoot = ".";
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/jadx" "$out/bin"
    cp -r bin lib "$out/share/jadx/"
    for program in jadx jadx-gui; do
      chmod +x "$out/share/jadx/bin/$program"
      patchShebangs "$out/share/jadx/bin/$program"
      makeWrapper "$out/share/jadx/bin/$program" "$out/bin/$program" \
        --set JAVA_HOME ${pkgs.jdk17.home}
    done
    runHook postInstall
  '';
  meta = {
    description = "DEX to Java decompiler, official JVM distribution";
    homepage = "https://github.com/skylot/jadx";
    license = pkgs.lib.licenses.asl20;
    sourceProvenance = [ pkgs.lib.sourceTypes.binaryBytecode ];
    mainProgram = "jadx-gui";
    platforms = [ "x86_64-linux" ];
  };
})
