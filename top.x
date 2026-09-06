import spi;
import iterative_polynomial_sampler as ps;

#![feature(generics)]
#![feature(explicit_state_access)]

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
    spi_clk: chan<()> out,
    spi_cs: chan<u1> out,
    spi_di: chan<u1> out,
    spi_do: chan<u1> in,
}

type PolynomialNumber = s64;
const POLY_DEGREE = u32:3;
type PolyRequest = ps::IterationRequest<PolynomialNumber, POLY_DEGREE>;

const POLY_CLK_BIT = u32:1;    // TBD which bit we want

const SPI_WORD_BITS = bit_count<PolyRequest>();

pub proc Top {
    // Ports to the external world.
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,

    // Internal stuff.
    spi_clk: chan<()> out,
    spi_cs: chan<u1> out,
    spi_di: chan<u1> out,
    spi_do: chan<u1> in,

    want_poly_sample:    chan<()> out,
    sample_value_result: chan<PolynomialNumber> in,
    last_sample:         PolynomialNumber,

    last_input: Inputs,
}

impl Top {
    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        // Spi ports and internal channels coupling.
        // We drive these channels through the top proc.
        let (spi_clk_s, spi_clk_r) = chan<(), u32:1>("spi-clk");
        let (spi_cs_s, spi_cs_r) = chan<u1, u32:1>("spi-cs");
        let (spi_di_s, spi_di_r) = chan<u1, u32:1>("spi-di");
        let (spi_do_s, spi_do_r) = chan<u1, u32:1>("spi-do");

        // Channels driven by the ports.
        let spi_source = SpiSource {
            spi_clk: spi_clk_s,
            spi_cs: spi_cs_s,
            spi_di: spi_di_s,
            spi_do: spi_do_r,
        };

        // Spi consumer is the polynomial sampler
	let (poly_req_s, poly_req_r) = chan<PolyRequest, 0>("poly-request");

        // Instantiate the spi proc. (assuming it accepts a PolyRequest type)
        //let sipo = spi::SerialInParallelOut<PolyRequest>::new(spi_clk_r, spi_di_r, poly_req_s)
        // let sipo = spi.SerialInParallelOut<SPI_WORD_BITS>::new(spi_clk_r, spi_di_r, spi_word_sink_s);
        //sipo.spawn();

	// Wire up polynomial sampler
	let (poly_want_s, poly_want_r) = chan<(), 0>("poly-want-next-sample");
	let (poly_sample_result_s, poly_sample_result_r) = chan<PolynomialNumber, 0>("poly-result");
        let sampler = ps::IterativePolynomialSampler<PolynomialNumber, POLY_DEGREE>
	    ::new(poly_req_r, poly_want_r, poly_sample_result_s);
	sampler.spawn();

        Top {
            inputs: ui_in, outputs: uo_out,
            spi_clk: spi_clk_s, spi_cs: spi_cs_s, spi_di: spi_di_s, spi_do: spi_do_r,

	    // polynomial sampling stuff
	    want_poly_sample: poly_want_s,
	    sample_value_result: poly_sample_result_r,
	    last_sample: 0,

	    last_input: Inputs { ..zero!<Inputs>() },
        }
    }

    fn next(self) {
        let (tok, input) = recv(join(), self.inputs);
	let last_input = read(self.last_input);

	// --- handling diff engine.
	// Check if we want a new sample, and tell
	let poly_clk_bit = input.ui_in[POLY_CLK_BIT +: u1];
	let tok = if (poly_clk_bit && poly_clk_bit != last_input.ui_in[POLY_CLK_BIT +: u1]) {
	    send(tok, self.want_poly_sample, ())
	} else {
	    tok
	};

	// Maybe we got a result, so attempt to receive one.
	let last_sample = read(self.last_sample);
	let (tok, new_sample, _) = recv_non_blocking(tok, self.sample_value_result, last_sample);
	write(self.last_sample, new_sample);

        send(tok, self.outputs, Outputs {
	    // TODO: fish out the right bits from new_sample and set here
            uo_out: input.ui_in + input.uio_in,
            uio_out: u8:0,
            uio_oe: u8:0,          // all bidirectionals are inputs
        });
	write(self.last_input, input);
    }
}
