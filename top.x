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

struct SpiSource {
    spi_clk: chan<u1> out,
    spi_cs: chan<u1> out,
    spi_di: chan<u1> out,
    spi_do: chan<u1> in,
}

const SPI_WORD_BITS = u32:8;

pub proc Top {
    // Ports to the external world.
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,

    // Internal stuff.
    spi: SpiSource,

    spi_word_sink: chan<u1[SPI_WORD_BITS]> in,
}

impl Top {
    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        // Spi ports and internal channels coupling.
        // We drive these channels through the top proc.
        let (spi_clk_s, spi_clk_r) = chan<u1>("spi-clk");
        let (spi_cs_s, spi_cs_r) = chan<u1>("spi-cs");
        let (spi_di_s, spi_di_r) = chan<u1>("spi-di");
        let (spi_do_s, spi_do_r) = chan<u1>("spi-do");

        // Channels driven by the ports.
        let spi = SpiSource {
            spi_clk: spi_clk_s,
            spi_cs: spi_cs_s,
            spi_di: spi_di_s,
            spi_do: spi_do_r,
        };

        // Spi consumer.
        let (spi_word_sink_s, spi_word_sink_r) = chan<u1[SPI_WORD_BITS]>("spi-word-sink");

        // Instantiate the spi proc.
        let sipo = spi.SerialInParallelOut<SPI_WORD_BITS>::new(spi_clk_r, spi_di_r, spi_word_sink_s);
        // let sipo = spi.SerialInParallelOut<SPI_WORD_BITS>::new(spi_clk_r, spi_di_r, spi_word_sink_s);
        sipo.spawn();

        Top { inputs: ui_in, outputs: uo_out, spi: spi, spi_word_sink: spi_word_sink_r }
    }

    fn next(self) {
        let (tok, v) = recv(join(), self.inputs);
        send(tok, self.outputs, Outputs {
            uo_out: v.ui_in + v.uio_in,
            uio_out: u8:0,
            uio_oe: u8:0,          // all bidirectionals are inputs
        });
    }

    // fn spi_next(next) {
    // }
}

