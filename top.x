// -*- mode: rust; indent-tabs-mode: nil; -*-

import spi;
import iterative_polynomial_sampler as ps;
import std;

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

type PolynomialNumber = s16;
const POLY_DEGREE = u32:3;
type PolyRequest = ps::IterationRequest<PolynomialNumber, POLY_DEGREE>;

// Input bits map.
const I_SPI_CLK_BIT = u32:0;
const I_SPI_CS_BIT = u32:1;
const I_SPI_DI_BIT = u32:2;
const I_POLY_CLK_BIT = u32:3;

// Outputs bit map.
const O_SPI_DO_BIT = u32:0;
const O_POLY_DO_VALUE_BIT = u32:1;
const O_POLY_DO_SIGN_BIT = u32:2;

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
        let (spi_clk_s, spi_clk_r) = chan<(), 0>("spi-clk");
        let (spi_cs_s, spi_cs_r) = chan<u1, 0>("spi-cs");
        let (spi_di_s, spi_di_r) = chan<u1, 0>("spi-di");
        let (spi_do_s, spi_do_r) = chan<u1, 0>("spi-do");

        // Spi consumer is the polynomial sampler
        let (poly_req_s, poly_req_r) = chan<PolyRequest, 0>("poly-request");

        // Instantiate the spi proc.
        // If this assert failes, ensure you udpate the type below. Quirk of xls.
        let sipo = spi::SerialInParallelOut<PolyRequest, SPI_WORD_BITS>::new(spi_clk_r, spi_di_r, poly_req_s);
        sipo.spawn();

        // Wire up polynomial sampler
        let (poly_want_s, poly_want_r) = chan<(), 0>("poly-want-next-sample");
        let (poly_sample_result_s, poly_sample_result_r) = chan<PolynomialNumber, 0>("poly-result");
        let sampler = ps::IterativePolynomialSampler<PolynomialNumber, POLY_DEGREE>
            ::new(poly_req_r, poly_want_r, poly_sample_result_s);
        sampler.spawn();


        Top {
            // I/O ports.
            inputs: ui_in, outputs: uo_out,

            // Spi.
            spi_clk: spi_clk_s,
            spi_cs: spi_cs_s,
            spi_di: spi_di_s,
            spi_do: spi_do_r,

            // Polynomial sampling stuff.
            want_poly_sample: poly_want_s,
            sample_value_result: poly_sample_result_r,
            last_sample: 0,

            last_input: Inputs { ..zero!<Inputs>() },
        }
    }

    fn next(self) {
        let (tok, input) = recv(join(), self.inputs);
        let last_input = read(self.last_input);

        // --- Handling diff engine.
        // Check if we want a new sample, and tell
        let poly_clk_bit = input.ui_in[I_POLY_CLK_BIT +: u1];
        let tok = if (poly_clk_bit && poly_clk_bit != last_input.ui_in[I_POLY_CLK_BIT +: u1]) {
            send(tok, self.want_poly_sample, ())
        } else {
            tok
        };

        // Maybe we got a result, so attempt to receive one.
        let last_sample = read(self.last_sample);
        let (tok, new_sample, _) = recv_non_blocking(tok, self.sample_value_result, last_sample);
        write(self.last_sample, new_sample);

        // --- Handling off SPI.
        // Get previous clk state recorded.
        let spi_clk = input.ui_in[I_SPI_CLK_BIT +: u1];
        let spi_cs = input.ui_in[I_SPI_CS_BIT +: u1];
        let spi_di = input.ui_in[I_SPI_DI_BIT +: u1];

        let last_spi_clk = last_input.ui_in[I_SPI_CLK_BIT +: u1];
        let last_spi_cs = last_input.ui_in[I_SPI_CS_BIT +: u1];

        let rising = last_spi_clk == 0 && spi_clk == 1;

        // Previous and current tick are all zero. We are in a correct active state.
        let active = spi_cs == 0 && last_spi_cs == 0;

        // Chip select high, nothing to do here, keep the clock state high.
        // We follow CPHA 1.
        if active {
            if rising {
                // Submit the SIPO.
                send(tok, self.spi_clk, ());
                send(tok, self.spi_di, spi_di);
            };
        };
        // For now we ignore the spi output.
        let spi_do = u1:0b0;

        // --- Output.
        let uo_out = u8:0;
        let uo_out = bit_slice_update(uo_out, O_SPI_DO_BIT, spi_do);
        let uo_out = bit_slice_update(uo_out, O_POLY_DO_VALUE_BIT, std::lsb(last_sample));
        let uo_out = bit_slice_update(uo_out, O_POLY_DO_SIGN_BIT, std::msb(last_sample));

        send(tok, self.outputs, Outputs {
            uo_out: uo_out,
            uio_out: u8:0,
            uio_oe: u8:0,          // all bidirectionals are inputs
        });

        // Update new state.
        write(self.last_input, input);

    }

}
