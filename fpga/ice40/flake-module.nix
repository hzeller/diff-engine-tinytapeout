# iCE40 leg: build the TT harness for the TinyFPGA BX (icestorm flow) and the
# experimental VPR architecture model. Enter with `nix develop .#ice40`, then `make` here.
{ ... }:
{
  perSystem =
    { self', pkgs, ... }:
    {
      devShells.ice40 = pkgs.mkShell {
        packages = [
          self'.packages.vtr
          pkgs.icestorm
          pkgs.python3
          pkgs.yosys
          # Real bitstreams for the TinyFPGA BX: place & route and USB upload.
          pkgs.nextpnr
          pkgs.tinyprog
        ];
        ICESTORM = "${pkgs.icestorm}";
      };
    };
}
