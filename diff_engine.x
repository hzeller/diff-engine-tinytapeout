import spi;

#![feature(generics)]
#![feature(explicit_state_access)]

struct Inputs { ui_in: u1[8] }
struct Outputs { uo_out: u1[8] }

pub proc Top {
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,
    // Two-stage synchroniser: ui_in is asynchronous to clk.
    sync0: u8,
    sync1: u8,
}

impl Top {
    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        Top { inputs: ui_in, outputs: uo_out, sync0: 0, sync1: 0 }
    }

    fn next(self) {
        let stage0 = read(self.sync0);
        let stage1 = read(self.sync1);
        let (tok, v) = recv(join(), self.inputs);
        send(tok, self.outputs, Outputs { uo_out: stage1 as u1[8] });
        write(self.sync0, v.ui_in as u8);
        write(self.sync1, stage0);
    }
}
