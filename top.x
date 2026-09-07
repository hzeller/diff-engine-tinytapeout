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

type PolynomialNumber = s12;
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

struct StepDir {
    step: u1,
    dir: u1,
}

pub proc Top {
    // Ports to the external world.
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,

    // Internal stuff.
    spi_di: chan<u1> out,

    want_poly_sample:    chan<()> out,
    sample_value_result: chan<(PolynomialNumber, u1)> in,
    last_stepdir:         StepDir,
    step_out: u1,

    last_input: Inputs,
}

impl Top {
    const W = bit_count<PolynomialNumber>();

    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        // Spi ports and internal channels coupling.
        // We drive these channels through the top proc.
        let (spi_di_s, spi_di_r) = chan<u1, 1>("spi-di");

        // Spi consumer is the polynomial sampler
        let (poly_req_s, poly_req_r) = chan<PolyRequest, 0>("poly-request");

        // Instantiate the spi proc.
        // If this assert failes, ensure you udpate the type below. Quirk of xls.
        let sipo = spi::SerialInParallelOut<PolyRequest, SPI_WORD_BITS>::new(spi_di_r, poly_req_s);
        sipo.spawn();

        // Wire up polynomial sampler
        let (poly_want_s, poly_want_r) = chan<(), 0>("poly-want-next-sample");
        let (poly_sample_result_s, poly_sample_result_r) = chan<(PolynomialNumber, u1), 0>("poly-result");
        let sampler = ps::IterativePolynomialSampler<PolynomialNumber, POLY_DEGREE>
            ::new(poly_req_r, poly_want_r, poly_sample_result_s);
        sampler.spawn();


        Top {
            // I/O ports.
            inputs: ui_in, outputs: uo_out,

            // Spi.
            spi_di: spi_di_s,

            // Polynomial sampling stuff.
            want_poly_sample: poly_want_s,
            sample_value_result: poly_sample_result_r,
            last_stepdir: StepDir{  ..zero!<StepDir>() },
            step_out: u1:0,

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
        let last_stepdir = read(self.last_stepdir);
        let (tok, (new_sample, new_dir), _) = recv_non_blocking(tok, self.sample_value_result, (0, u1:0));

        let new_step = (new_sample as uN[W])[W - 2+: u1];

        // We only change the direction when steps does.
        let rising = new_step == u1:1 && last_stepdir.step == u1:0;
        let falling = new_step == u1:0 && last_stepdir.step == u1:1;

        let new_dir = if rising { new_dir } else { last_stepdir.dir };

        write(self.last_stepdir, StepDir{
            step: new_step,
            dir: new_dir,
        });

        if falling {
            write(self.step_out, u1:1);
        };
        if rising {
            write(self.step_out, u1:0);
        };

        let dir_out = if rising { new_dir } else { last_stepdir.dir };
        let step_out = read(self.step_out);

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
        let tok = if active && rising {
            send(tok, self.spi_di, spi_di)
        } else {
            tok
        };

        // For now we ignore the spi output.
        let spi_do = u1:0b0;

        // --- Output.
        let uo_out = u8:0;
        let uo_out = bit_slice_update(uo_out, O_SPI_DO_BIT, spi_do);
        let uo_out = bit_slice_update(uo_out, O_POLY_DO_VALUE_BIT, step_out);
        let uo_out = bit_slice_update(uo_out, O_POLY_DO_SIGN_BIT, dir_out);

        send(tok, self.outputs, Outputs {
            uo_out: uo_out,
            uio_out: u8:0,
            uio_oe: u8:0,          // all bidirectionals are inputs
        });

        // Update new state.
        write(self.last_input, input);

    }

}
