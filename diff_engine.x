import spi;

#![feature(generics)]
#![feature(explicit_state_access)]

struct Inputs { ui_in: u1[8] }
struct Outputs { uo_out: u1[8] }

pub proc Top {
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,
}

impl Top {
    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        Top { inputs: ui_in, outputs: uo_out }
    }

    fn next(self) {
        send(join(), self.outputs, Outputs { uo_out: u8:7 as u1[8] });
    }
}
