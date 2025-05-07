{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib legacyPackages;
      perSystem = f: lib.genAttrs lib.systems.flakeExposed (s: f legacyPackages.${s});
    in
    {
      devShells = perSystem (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            nil
            nixfmt-rfc-style
            zig
            zls
            pkg-config
            glib
            gtk4
            gtk4-layer-shell
            libadwaita
            libpulseaudio
            blueprint-compiler
          ];
        };
      });
    };
}
