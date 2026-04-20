{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems =
        function:
        nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed (
          system: function nixpkgs.legacyPackages.${system}
        );
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            gleam

            # vscode appreciates this
            bashInteractive

            # lustre dev tools
            erlang
            beamPackages.rebar3
            inotify-tools
            bun
            tailwindcss_4

            # we literally only use this for maintaining the dependencies
            # because nixpkgs doesn't support bun yet
            nodejs
          ];
        };
      });

      packages = forAllSystems (pkgs: {
        default = pkgs.callPackage ./package.nix { };
      });
    };
}
