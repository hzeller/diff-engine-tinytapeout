# FPGA area of the repo: one flake module per target family.
{ ... }:
{
  imports = [
    ./xc7/flake-module.nix
    ./ice40/flake-module.nix
  ];
}
