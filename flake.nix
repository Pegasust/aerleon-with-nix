{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix/master";
  outputs = {
    self,
    nixpkgs,
    poetry2nix,
    ...
  }: let
    nixlib = nixpkgs.lib;
    eachSystem = systems: f: nixlib.foldAttrs nixlib.mergeAttrs {} (map (s: nixlib.mapAttrs (_: v: {${s} = v;}) (f s)) systems);
    pkgs-of = sys: (import nixpkgs {
      system = sys;
      overlays = [poetry2nix.overlays.default];
    });
    poetry2nix-of = sys: (poetry2nix.lib.mkPoetry2Nix {pkgs = pkgs-of sys;});

    python-pkg-of = sys: inject:
      (poetry2nix-of sys).mkPoetryApplication ({
          projectDir = ./.;
        }
        // inject);
    prod-pkg-of = sys:
      python-pkg-of sys {
        groups = [];
        extras = [];
      };

    supported-sys = ["aarch64-darwin" "x86_64-linux"];
  in
    eachSystem supported-sys (sys: {
      packages.aerleon = prod-pkg-of sys;
      packages.poetry = (pkgs-of sys).poetry;
      apps =
        {}
        // (builtins.listToAttrs (
          builtins.map (k: {
            name = k;
            value = {
              type = "app";
              program = "${prod-pkg-of sys}/bin/${k}";
            };
          }) ["aclgen" "cgrep" "aclcheck"]
        ));
      devShells.default = (pkgs-of sys).mkShell {
        packages = [
          (python-pkg-of sys {
            extras = ["devtools"];
          })
        ];
      };
    });
}
