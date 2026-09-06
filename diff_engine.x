import spi;

#![feature(generics)]

// A DSLX port of the Tiny Tapeout Verilog template:
//     assign uo_out  = ui_in + uio_in;
//     assign uio_out = 0;
//     assign uio_oe  = 0;
//
// Every pin the design owns is carried on a channel, so nothing is left
// dangling for the hardening flow.

struct Inputs {
    ui_in: u8,
    uio_in: u8,
}

struct Outputs {
    uo_out: u8,
    uio_out: u8,
    uio_oe: u8,
}

pub proc Top {
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,
}

impl Top {
    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        Top { inputs: ui_in, outputs: uo_out }
    }

    fn next(self) {
        let (tok, v) = recv(join(), self.inputs);
        send(tok, self.outputs, Outputs {
            uo_out: v.ui_in + v.uio_in,
            uio_out: u8:0,
            uio_oe: u8:0,          // all bidirectionals are inputs
        });
    }
}
