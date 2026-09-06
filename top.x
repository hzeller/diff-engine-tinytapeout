import spi;

#![feature(generics)]

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
