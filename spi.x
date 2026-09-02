
import std;

const WORD_BITS: u32 = 8;
const WORD_BIT_SIZE = std::clog2(WORD_BITS);

struct State {
    buffer: u1[8],
}

proc SpiSecondary {
    miso: chan<u8> out;

    config(miso: chan<u8> out) {
        (miso,)
    }

    init { u8:0 }                          // the state's reset value (what rst_n restores)

    next(state: u8) {                      // runs once per activation ("tick")
        let tok = send(join(), out_ch, state);   // emit the count (tokens: Part 4)
        state + u8:1                       // return value = the next state
    }
}

pub fn main(ui_in: u8, uio_in: u8) -> (u8, u8, u8) {
    let switches: u1[8] = ui_in as u1[8];
    let leds: u1[8] = u8:0 as u1[8];
    let leds = update(leds, u32:0, switches[0] & switches[1]);
    (leds as u8, u8:0, u8:0)
}
