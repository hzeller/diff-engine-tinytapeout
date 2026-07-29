
// Placeholder design: sum of the two ui_in nibbles, 8-bit result.
// The full Tiny Tapeout interface flows through here; the Verilog wrapper
// is a dumb adapter. Replace with the real design.
pub fn main(ui_in: u8, uio_in: u8) -> (u8, u8, u8) {
    let uo_out = (ui_in[0+:u4] as u8) + (ui_in[4+:u4] as u8);
    let uio_out = u8:0;
    let uio_oe = u8:0;
    (uo_out, uio_out, uio_oe)
}

#[test]
fn main_test() {
    assert_eq(main(u8:0x43, u8:0), (u8:7, u8:0, u8:0));
    assert_eq(main(u8:0x00, u8:0), (u8:0, u8:0, u8:0));
    assert_eq(main(u8:0xff, u8:0), (u8:30, u8:0, u8:0));
}
