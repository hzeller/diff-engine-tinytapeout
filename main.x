
// Placeholder design: sum of two 4-bit inputs, 8-bit result.
// Replace with the real Tiny Tapeout design.
pub fn main(a: u4, b: u4) -> u8 {
    (a as u8) + (b as u8)
}

#[test]
fn main_test() {
    assert_eq(main(u4:3, u4:4), u8:7);
    assert_eq(main(u4:0, u4:0), u8:0);
    assert_eq(main(u4:15, u4:15), u8:30);
}
