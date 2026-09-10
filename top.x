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

type PolynomialNumber = s15;
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

struct RelevantInputState {
    // SPI state
    spi_cs: u1,
    spi_clk: u1,

    // polynomial clock.
    poly_clk: u1,
}

pub proc Top {
    // Ports to the external world.
    inputs: chan<Inputs> in,
    outputs: chan<Outputs> out,

    // Internal stuff.
    spi_source: chan<spi::SpiInput> out,

    want_poly_sample:    chan<()> out,
    sample_value_result: chan<(PolynomialNumber, u1)> in,
    last_stepdir:         StepDir,

    // Implement a 64 cycles delay for step.
    rising_delay_counter: u6,

    last: RelevantInputState,
}

impl Top {
    const W = bit_count<PolynomialNumber>();

    fn new(ui_in: chan<Inputs> in, uo_out: chan<Outputs> out) -> Self {
        // Spi ports and internal channels coupling.
        // We drive these channels through the top proc.
        let (spi_source_s, spi_source_r) = chan<spi::SpiInput, 1>("spi-di");

        // Spi consumer is the polynomial sampler
        let (poly_req_s, poly_req_r) = chan<PolyRequest, 0>("poly-request");

        // Instantiate the spi proc.
        // If this assert failes, ensure you udpate the type below. Quirk of xls.
        let sipo = spi::SerialInParallelOut<PolyRequest, SPI_WORD_BITS>::new(spi_source_r, poly_req_s);
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
            spi_source: spi_source_s,

            // Polynomial sampling stuff.
            want_poly_sample: poly_want_s,
            sample_value_result: poly_sample_result_r,
            last_stepdir: StepDir{  ..zero!<StepDir>() },
            rising_delay_counter: u6:0,

            last: RelevantInputState{ ..zero!<RelevantInputState>() },
        }
    }

    fn next(self) {
        let (tok, input) = recv(join(), self.inputs);
        let last = read(self.last);
        // Fish inputs from the corresponding input bits.
        let current = RelevantInputState {
            spi_cs:   input.ui_in[I_SPI_CS_BIT +: u1],
            spi_clk:  input.ui_in[I_SPI_CLK_BIT +: u1],

            poly_clk: input.ui_in[I_POLY_CLK_BIT +: u1],
        };

        // --- Handling diff engine.
        // Check if we want a new sample, and tell
        let tok = if current.poly_clk && current.poly_clk != last.poly_clk {
            send(tok, self.want_poly_sample, ())
        } else {
            tok
        };

        // Maybe we got a result, so attempt to receive one.
        let last_stepdir = read(self.last_stepdir);
        let (tok, (new_sample, new_dir), got) = recv_non_blocking(tok, self.sample_value_result, (0, u1:0));

        let new_step = if got { (new_sample as uN[W])[W - 2 +: u1] } else { last_stepdir.step };

        // We only change the direction when steps does.
        let rising = new_step == u1:1 && last_stepdir.step == u1:0;
        let new_dir = if rising { new_dir } else { last_stepdir.dir };
        let dir_change = new_dir != last_stepdir.dir;

        write(self.last_stepdir, StepDir{
            step: new_step,
            dir: new_dir,
        });

        // What to output now?
        // If it's rising we are not expecting the bit to rise more frequently than counter cycles.
        // Hence, rising and counter != 0 must never be true at the same time.
        let rising_delay_counter = read(self.rising_delay_counter);
        let step_out = if (rising && dir_change) || (rising_delay_counter != 0) {
            // Increment until we overflow and go back to 0.
            write(self.rising_delay_counter, rising_delay_counter + 1);
            u1:0
        } else { last_stepdir.step };
        let dir_out = new_dir;

        // --- Handling SPI.
        let spi_clk_rising = last.spi_clk == 0 && current.spi_clk == 1;
        let spi_active = current.spi_cs == 0;
        let transfer_finished = last.spi_cs == 0 && current.spi_cs == 1;

        // Either we got a clock while active, or notice transfer to be finished.
        let tok = if (spi_active && spi_clk_rising) | transfer_finished {
            let spi_di_bit = input.ui_in[I_SPI_DI_BIT +: u1];
            send(tok, self.spi_source, spi::SpiInput {
                data_bit: spi_di_bit,
                send_to_sink: transfer_finished,
            })
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

        // Remember state to compare and detect edges.
        write(self.last, current);
    }
}
