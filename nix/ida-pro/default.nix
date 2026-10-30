{
  lib,
  ida-free,
  fetchurl,
  libxtst,
  python312,
  unzip,
  nodejs,
  withPatches ? true,
}:
# Reuse nixpkgs' IDA installer, Qt dependencies and ELF patching machinery.
let
  sources = import ./sources.nix { inherit lib fetchurl; };
in
ida-free.overrideAttrs (old: {
  pname = "ida-pro";
  version = "9.4";

  src = sources."ida-pro_94_x64linux.run";

  runtimeDependencies = old.runtimeDependencies ++ [
    libxtst
    python312
  ];

  postInstall =
    (old.postInstall or "")
    + lib.optionalString withPatches ''
      ${unzip}/bin/unzip -oj ${sources."linux_patched.zip"} -d "$IDADIR"
      chmod u+w "$IDADIR/libida.so" "$IDADIR/libida32.so"
      patchelf --add-needed libcrypto.so "$IDADIR/libida.so"
      cp "$IDADIR/libida.so" "$out/lib/libida.so"
    ''
    + ''
      mkdir -p "$out/share/ida-pro"
      cp ${sources."keygen.js"} "$out/share/ida-pro/keygen.js"
      ${unzip}/bin/unzip -q ${sources."idapin94.zip"} -d "$out/share/ida-pro"
      makeWrapper ${nodejs}/bin/node "$out/bin/ida-keygen" \
        --add-flags "$out/share/ida-pro/keygen.js"
      wrapProgram "$IDADIR/ida" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ python312 ]}" \
        --run "\"$IDADIR/idapyswitch\" --force-path ${python312}/lib/libpython3.12.so"
      makeWrapper "$IDADIR/idat" "$out/bin/idat" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ python312 ]}" \
        --run "\"$IDADIR/idapyswitch\" --force-path ${python312}/lib/libpython3.12.so"
    '';

  meta = old.meta // {
    description = "Interactive disassembler and debugger";
    homepage = "https://hex-rays.com/ida-pro";
    license = lib.licenses.unfree;
    maintainers = [ ];
  };
})
