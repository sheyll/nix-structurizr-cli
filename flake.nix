{
  description = "Nix-ify struturizr-cli";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    devenv.url = "github:cachix/devenv";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    devenv,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        overlays = [(final: prev: {
          structurizr-cli = self.packages.${system}.structurizr-cli;
        })];
        packages = rec {
          structurizr-cli = pkgs.callPackage ./default.nix {};
          default = structurizr-cli;
        };
        apps = rec {
          structurizr-cli = flake-utils.lib.mkApp {
            drv = self.packages.${system}.structurizr-cli;
          };
          default = structurizr-cli;
        };
      }
    );
}
