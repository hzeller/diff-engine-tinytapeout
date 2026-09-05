import std;

#![feature(generics)]
#![feature(explicit_state_access)]

struct FifoBuffer<WORD_BITS: u32> {
    buffer: u1[WORD_BITS],
    count: u1[std::clog2(WORD_BITS) + 1],
}

impl FifoBuffer<WORD_BITS> {
    fn default() -> Self {
        FifoBuffer<WORD_BITS> { ..zero!<FifoBuffer<WORD_BITS>>() }
    }
}

// Model a simple shift register.
pub proc SerialInParallelOut<WORD_BITS: u32> {
    // Pace at which we receive the serial data.
    clk: chan<()> in,

    // Pace at which we receive the serial data.
    source: chan<u1> in,

    // Reset the buffer state, discards anything in the buffer.
    rst: chan<()> in,

    // Channel used by the consumer to receive parallel data.
    sink: chan<u1[WORD_BITS]> out,

    // Internal state.
    state: FifoBuffer<WORD_BITS>,
}

impl SerialInParallelOut<WORD_BITS> {
    const WORD_BITS_SIZE = std::clog2(WORD_BITS);

    pub fn new(clk: chan<()> in , source: chan<u1> in, rst: chan<()> in, sink: chan<u1[WORD_BITS]> out) -> Self {
        SerialInParallelOut {
            clk: clk,
            source: source,
            rst: rst,
            sink: sink,
            state: FifoBuffer<WORD_BITS>::default(),
        }
    }

    fn next(self) {
        let state = read(self.state);
        let tok = join();

        // Wait for a clock event.
        recv(tok, self.clk);

        // Did we just receive a full word?
        let (tok, v) = recv(tok, self.source);
        let new_buffer = update(state.buffer, state.count as uN[WORD_BITS_SIZE + 1], v as u1);
        let new_count = ((state.count as uN[WORD_BITS_SIZE + 1]) + 1) as u1[WORD_BITS_SIZE + 1];
        if new_count[0] == 1 {
            send(join(), self.sink, new_buffer);
            write(self.state, FifoBuffer<WORD_BITS>::default());
        } else {
            write(self.state, FifoBuffer{
                buffer: new_buffer,
                count: new_count,
            });
        }
    }
}

#[test]
proc SerialInParallelOutTest {
    // Sample clock for the SIPO.
    sample_clk: chan<()> out,

    // Mock serial data sent to our SIPO.
    serial_in: chan<u1> out,

    // Parallel data received from the test proc perspective.
    parallel_out: chan<u1[8]> in,

    sent_bits_count: u32,
    received_words_count: u32,

    // End of test channel.
    done: chan<bool> out,  // tell test harness that we're done.
}

impl SerialInParallelOutTest {
    const WORD_BITS = u32:8;
    const SAMPLE_DATA: u1[32] = u32:0xdeadbeef as u1[32];
    const SAMPLE_BITS_COUNT = u32:32;

    fn new(done: chan<bool> out) -> Self {
        let (clk_s, clk_r) = chan<()>("sample-clk");
        let (serial_in_s, serial_in_r) = chan<u1>("serial-in");
        let (rst_s, rst_r) = chan<()>("rst");
        let (parallel_out_s, parallel_out_r) = chan<u1[WORD_BITS]>("parallel-out");
        let sipo = SerialInParallelOut<WORD_BITS>::new(clk_r, serial_in_r, rst_r, parallel_out_s);
        sipo.spawn();

        SerialInParallelOutTest {
            sample_clk: clk_s,
            serial_in: serial_in_s,
            parallel_out: parallel_out_r,
            sent_bits_count: u32:0,
            received_words_count: u32:0,
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
        let (_, v, got_word) = recv_non_blocking(join(), self.parallel_out, u8:0 as u1[8]);
        if got_word {
            trace_fmt!("received word: 0x{:x}", v as u8);
            assert_eq(v, EXPECTED_WORDS[received_words_count] as u1[8]);
            write(self.received_words_count, received_words_count + u32:1);
            if sent_all {
                assert_eq(received_words_count, 3);
                send(tok, self.done, true);
            }
        };

        if !sent_all {
            // Send data.
            let serial_value = SAMPLE_DATA[sent_bits_count];
            send(tok, self.serial_in, serial_value);
            send(tok, self.sample_clk, ());
            write(self.sent_bits_count, sent_bits_count + 1);
        };
    }
}
