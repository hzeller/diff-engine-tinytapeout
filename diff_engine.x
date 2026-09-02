
struct SpiInput {
    clk: u1,
    mosi: u1,
    cs: u1,
}

struct SpiOutput {
    miso: u1,
}

pub fn main(spi: SpiInput) -> SpiOutput {
    // let switches: u1[8] = ui_in as u1[8];
    // let leds: u1[8] = u8:0 as u1[8];
    //let leds = update(leds, u32:0, switches[0] & switches[1]);
    SpiOutput{ miso: u1:0 }
}
