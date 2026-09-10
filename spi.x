//usr/bin/env -S make spi.test; exit

import std;

#![feature(generics)]
#![feature(explicit_state_access)]

struct FifoBuffer<WORD_BITS: u32> {
    buffer: uN[WORD_BITS],
}

impl FifoBuffer<WORD_BITS> {
    fn default() -> Self {
        FifoBuffer<WORD_BITS> { ..zero!<FifoBuffer<WORD_BITS>>() }
    }
}

// TODO: better model the _either_ data _or_ done situation
pub struct SpiInput {
    data_bit: u1,       // a data bit if active transmission.
    send_to_sink: u1,   // 'true' when done otherwise data is valid.
}

// Model a simple shift register.
pub proc SerialInParallelOut<T: type, WORD_BITS: u32> {
    // We expect this channel to be filled whenever there is a new bit or
    // transmission ends.
    source: chan<SpiInput> in,

    // Channel used by the consumer to receive parallel data.
    sink: chan<T> out,

    // Internal state.
    state: FifoBuffer<WORD_BITS>,
}

impl SerialInParallelOut<T, WORD_BITS> {
    pub fn new(source: chan<SpiInput> in, sink: chan<T> out) -> Self {
        SerialInParallelOut {
            source: source,
            sink: sink,
            state: FifoBuffer<WORD_BITS>::default(),
        }
    }

    fn next(self) {
        let state = read(self.state);
        let (tok, input) = recv(join(), self.source);
        if input.send_to_sink {
            send(tok, self.sink, T::from_bits(state.buffer));
        } else {
            // Shift in from the LSB end: the first bit received ends up in the MSB,
            write(self.state, FifoBuffer { buffer: (state.buffer << 1)[1:] ++ input.data_bit });
        }
    }
}

struct Word8 { v: u8 }

impl Word8 {
    pub fn from_bits(x: u8) -> Self { Word8 { v: x } }
}

#[test]
proc SerialInParallelOutTest {
    // Mock serial data sent to our SIPO.
    serial_in: chan<SpiInput> out,

    // Parallel data received from the test proc perspective.
    parallel_out: chan<Word8> in,

    sent_bits_count: u32,
    received_words_count: u32,

    // End of test channel.
    done: chan<bool> out,  // tell test harness that we're done.
}


impl SerialInParallelOutTest {
    type T = Word8;
    const WORD_BITS = u32:8;
    const SAMPLE_DATA: u1[32] = u32:0xdeadbeef as u1[32];
    const SAMPLE_BITS_COUNT = u32:32;

    fn new(done: chan<bool> out) -> Self {
        let (serial_in_s, serial_in_r) = chan<SpiInput>("serial-in");
        let (parallel_out_s, parallel_out_r) = chan<Word8>("parallel-out");
        let sipo = SerialInParallelOut<Word8, WORD_BITS>::new(serial_in_r, parallel_out_s);
        sipo.spawn();

        SerialInParallelOutTest {
            serial_in: serial_in_s,
            parallel_out: parallel_out_r,
            sent_bits_count: 0,
            received_words_count: 0,
            done: done,
        }
    }

    fn next(self) {
        let tok = join();
        let sent_bits_count = read(self.sent_bits_count);
        let received_words_count = read(self.received_words_count);
        let sent_all = sent_bits_count == 32;

        let is_starting = sent_bits_count == u32:0;
        if is_starting {
            trace_fmt!("start: sending serial data");
        };

        const EXPECTED_WORDS: u8[4] = [
            u8:0xde,
            u8:0xad,
            u8:0xbe,
            u8:0xef,
        ];

        // Receive data.
        let (tok, v, got_word) = recv_non_blocking(join(), self.parallel_out, Word8 { v: u8:0 });
        if got_word {
            trace_fmt!("received word: {:#x} (0b{:0b})", v.v, v.v);
            assert_eq(v.v, EXPECTED_WORDS[received_words_count]);
            write(self.received_words_count, received_words_count + u32:1);
            if sent_all {
                assert_eq(received_words_count, 3);
                send(tok, self.done, true);
            }
        };

        if !sent_all {
            // Send data.
            let serial_value = SAMPLE_DATA[sent_bits_count];
            let tok = send(tok, self.serial_in, SpiInput {
                data_bit: serial_value,
                send_to_sink: false,
            });
            let sent_bits_count = sent_bits_count + 1;
            write(self.sent_bits_count, sent_bits_count);
            if (sent_bits_count % WORD_BITS == 0) {
                send(tok, self.serial_in, SpiInput {
                    data_bit: 0,
                    send_to_sink: true,
                });
            };
        };
    }
}

// Local Variables:
// mode: rust
// indent-tabs-mode: nil
// End:
