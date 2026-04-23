{
  stdenv,
  lib,

  # gleam
  gleam,
  erlang,
  beamPackages,

  # lustre
  bun,
  tailwindcss_4,

  ...
}:
let
  # Create a file containing the contents of build/packages as created by Gleam
  # This includes any dependencies specified in manifest.toml.
  mkGleamDeps =
    name: src: hash:
    stdenv.mkDerivation {
      name = "${name}-gleam-deps";

      nativeBuildInputs = [
        gleam
        bun
      ];

      src = src;

      buildPhase = ''
        runHook preBuild

        # gleam deps download fails if it can't write to $HOME/.cache
        mkdir fake_home
        HOME=fake_home

        gleam deps download

        # packages.toml is randomly ordered with a header row
        awk 'NR == 1; NR > 1 {print $0 | "sort -n"}' build/packages/packages.toml > packages_sorted.toml
        cp packages_sorted.toml build/packages/packages.toml

        rm build/packages/gleam.lock

        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall

        mkdir $out
        cp -r build/packages/** $out

        runHook postInstall
      '';

      outputHashMode = "recursive";
      outputHashAlgo = if hash == "" then "sha256" else null;
      outputHash = hash;
    };

  gleamToml = builtins.fromTOML (builtins.readFile ./gleam.toml);
in
stdenv.mkDerivation (finalAttrs: {
  pname = gleamToml.name;
  version = gleamToml.version;

  src = lib.cleanSource ./.;

  gleamDeps =
    mkGleamDeps "${finalAttrs.pname}-${finalAttrs.version}" finalAttrs.src
      finalAttrs.gleamDepsHash;
  gleamDepsHash = "sha256-msx9xgUtnfiR69wmfrA/q6q4guDSS8WI0Hm3FeSF0xA=";

  nativeBuildInputs = [
    # gleam
    gleam
    erlang
    beamPackages.rebar3

    # lustre
    bun
    tailwindcss_4

    # gleam dependencies
    finalAttrs.gleamDeps
  ];

  buildPhase = ''
    mkdir -p build/packages

    # gleam expects to be able to write to build/packages so we copy and chmod
    cp -r ${finalAttrs.gleamDeps}/** build/packages
    chmod -R u+w build/packages

    gleam run -m lustre/dev build --minify --outdir=dist
  '';

  doCheck = true;

  checkPhase = ''
    runHook preCheck

    gleam test

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist/** $out

    runHook postInstall
  '';
})
