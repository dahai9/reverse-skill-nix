{
  lib,
  fetchurl,
}:
lib.mapAttrs (
  name: sha256:
  fetchurl {
    url = "https://vaclive.party/software/ida-pro/releases/download/9.4.260714/${name}";
    inherit name sha256;
  }
) (builtins.fromJSON (builtins.readFile ./sources.json))
