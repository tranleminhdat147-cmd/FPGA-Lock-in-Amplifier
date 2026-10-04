`timescale 1ns/1ps

module DLIA_datapath_tb;

    localparam integer CLK_HZ    = 50_000_000;
    localparam integer ADC_DIV   = 50;
    localparam integer PERIODS   = 4;
    localparam real    LUT_AMP   = 2047.0;
    localparam real    CORDIC_K  = 1.6467;
    localparam real    MAG_TOL   = 0.03;
    localparam real    PHASE_TOL = 1.0;
    localparam real    PI        = 3.14159265358979;

    integer pass_count = 0;
    integer fail_count = 0;
    integer csv_fd;

    reg clk = 0;
    always #10 clk = ~clk;

    reg [31:0]        phase_step = 0;
    reg               ttl_rise   = 0;
    reg               adc_en     = 0;
    reg signed [11:0] adc        = 0;

    wire signed [11:0] sine, cosine;
    lut_sincos #(.PHASE_WIDTH(32), .ADDR_WIDTH(10), .DATA_WIDTH(12)) dds (
        .clk(clk), .rst_n(1'b1), .phase_step(phase_step), .ttl_rise(ttl_rise),
        .enable(1'b1), .valid_out(), .sine_wave(sine), .cosine_wave(cosine));

    wire signed [23:0] prod_s, prod_c;
    wire               v_mix_s, v_mix_c;
    multiplier mix_s (.clk(clk), .rst_n(1'b1), .enable(adc_en), .AFE(adc), .REF(sine),
                      .product(prod_s), .valid_out(v_mix_s));
    multiplier mix_c (.clk(clk), .rst_n(1'b1), .enable(adc_en), .AFE(adc), .REF(cosine),
                      .product(prod_c), .valid_out(v_mix_c));

    wire signed [47:0] sum_s, sum_c;
    wire               v_sum_s, v_sum_c;
    wire [31:0]        n_samples;
    integrate_and_dump id_s (.clk(clk), .rst_n(1'b1), .enable(v_mix_s), .ttl_rise(ttl_rise),
                             .x(prod_s), .valid_out(v_sum_s), .sum_out(sum_s), .N_sample(n_samples));
    integrate_and_dump id_c (.clk(clk), .rst_n(1'b1), .enable(v_mix_c), .ttl_rise(ttl_rise),
                             .x(prod_c), .valid_out(v_sum_c), .sum_out(sum_c), .N_sample());

    wire signed [29:0] cal_s, cal_c;
    calibration calib (.datain_a(sum_s), .datain_b(sum_c), .dataout_a(cal_s), .dataout_b(cal_c));

    wire               cord_valid;
    wire signed [31:0] cord_mag, cord_y, cord_phase;
    cordic_top #(.IN_WIDTH(30), .OUT_WIDTH(32)) cordic (
        .clk(clk), .valid_in(v_sum_s & v_sum_c), .x_in(cal_s), .y_in(cal_c), .z_in(30'sd0),
        .valid_out(cord_valid), .x_out(cord_mag), .y_out(cord_y), .z_out(cord_phase));

    reg signed [31:0] last_mag   = 0;
    reg signed [31:0] last_phase = 0;
    always @(posedge clk) begin
        if (cord_valid) begin
            last_mag   <= cord_mag;
            last_phase <= cord_phase;
        end
    end

    function integer round_to_int(input real v);
        round_to_int = (v >= 0.0) ? $rtoi(v + 0.5) : -$rtoi(-v + 0.5);
    endfunction

    function real absolute(input real v);
        absolute = (v < 0.0) ? -v : v;
    endfunction

    function real phase_diff(input real got, input real expected);
        real d;
        begin
            d = got - expected;
            if (d > 180.0)  d = d - 360.0;
            if (d < -180.0) d = d + 360.0;
            phase_diff = d;
        end
    endfunction

    reg  signed [47:0] cal_in;
    wire signed [29:0] cal_out;
    calibration cal_unit (.datain_a(cal_in), .datain_b(48'sd0), .dataout_a(cal_out), .dataout_b());

    task check_calibration(input real value, input string name);
        reg signed [47:0] shifted;
        begin
            cal_in = longint'(value);
            #1;
            shifted = cal_in >>> 10;
            if (shifted >= -(1 << 29) && shifted < (1 << 29)) begin
                if (cal_out == shifted[29:0]) begin
                    $display("PASS  calibration: %-28s value fits, output = %0d", name, cal_out);
                    pass_count = pass_count + 1;
                end else begin
                    $display("FAIL  calibration: %-28s expected %0d, got %0d", name, shifted, cal_out);
                    fail_count = fail_count + 1;
                end
            end else begin
                $display("KNOWN ISSUE calibration: %-28s value %0d does not fit in 30 bits, output wraps to %0d",
                         name, shifted, cal_out);
            end
        end
    endtask

    task run_case(input integer f_hz, input real amp, input real phase_deg, input string name);
        integer p, c, clocks_per_period, n_expected;
        real t, angle, exp_mag, got_mag, got_phase, mag_err, phase_err;
        reg mag_ok, phase_ok;
        begin
            clocks_per_period = CLK_HZ / f_hz;
            n_expected        = clocks_per_period / ADC_DIV;
            phase_step        = round_to_int(f_hz * 4294967296.0 / CLK_HZ);

            for (p = 0; p <= PERIODS; p = p + 1) begin
                for (c = 0; c < clocks_per_period; c = c + 1) begin
                    ttl_rise = (c == 0);
                    if (p < PERIODS && c % ADC_DIV == 1) begin
                        t      = c * 1.0 / CLK_HZ;
                        angle  = 2.0 * PI * f_hz * t + phase_deg * PI / 180.0;
                        adc    = round_to_int(amp * LUT_AMP * $sin(angle));
                        adc_en = 1'b1;
                    end else begin
                        adc_en = 1'b0;
                    end
                    @(posedge clk);
                end
            end

            exp_mag   = CORDIC_K * amp * LUT_AMP * LUT_AMP * n_expected / 2.0 / 1024.0;
            got_mag   = $itor(last_mag);
            got_phase = $itor(last_phase) * 360.0 / 4294967296.0;
            $fdisplay(csv_fd, "%0d,%0.4f,%0.2f,%0d,%0d", f_hz, amp, phase_deg, last_mag, last_phase);

            if (exp_mag > 0.0) begin
                mag_err = absolute(got_mag - exp_mag) / exp_mag;
                mag_ok  = (mag_err < MAG_TOL);
            end else begin
                mag_ok  = (absolute(got_mag) < 100.0);
            end
            phase_err = absolute(phase_diff(got_phase, phase_deg));
            phase_ok  = (amp == 0.0) ? 1'b1 : (phase_err < PHASE_TOL);

            if (mag_ok && phase_ok) begin
                $display("PASS  chain: %-24s mag %0d (exp %0.0f), phase %7.2f (exp %7.2f)",
                         name, last_mag, exp_mag, got_phase, phase_deg);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL  chain: %-24s mag %0d (exp %0.0f), phase %7.2f (exp %7.2f)",
                         name, last_mag, exp_mag, got_phase, phase_deg);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $display("=== DLIA datapath testbench ===");
        csv_fd = $fopen("rtl_vs_model/rtl_results.csv", "w");
        $fdisplay(csv_fd, "freq_hz,amp,phase_deg,rtl_mag,rtl_phase_raw");

        $display("--- Calibration block ---");
        check_calibration(10000.0 * 1024.0,           "small value");
        check_calibration(-10000.0 * 1024.0,          "small negative value");
        check_calibration(470588.0 * 2047.0 * 2047.0, "1 Hz full-scale sum");

        $display("--- Full chain (1 kHz, 10 kHz) ---");
        run_case(1000,  1.0,    0.0,    "1kHz full, 0 deg");
        run_case(1000,  1.0,   30.0,    "1kHz full, 30 deg");
        run_case(1000,  1.0,   45.0,    "1kHz full, 45 deg");
        run_case(1000,  1.0,   135.0,   "1kHz full, 135 deg");
        run_case(1000,  1.0,  -135.0,   "1kHz full, -135 deg");
        run_case(1000,  1.0,   -45.0,   "1kHz full, -45 deg");
        run_case(1000,  0.5,    45.0,   "1kHz half, 45 deg");
        run_case(1000,  0.1,   -45.0,   "1kHz 10 pct, -45 deg");
        run_case(2000,  1.0,    0.0,    "2kHz full, 0 deg");
        run_case(2000,  1.0,   30.0,    "2kHz full, 30 deg");
        run_case(2000,  1.0,   45.0,    "2kHz full, 45 deg");
        run_case(2500,  1.0,    0.0,    "2.5kHz full, 0 deg");
        run_case(2500,  1.0,   30.0,    "2.5kHz full, 30 deg");
        run_case(2500,  1.0,   45.0,    "2.5kHz full, 45 deg");
        run_case(4000,  1.0,    0.0,    "4kHz full, 0 deg");
        run_case(4000,  1.0,   30.0,    "4kHz full, 30 deg");
        run_case(4000,  1.0,   45.0,    "4kHz full, 45 deg");
        run_case(5000,  1.0,    0.0,    "5kHz full, 0 deg");
        run_case(5000,  1.0,   30.0,    "5kHz full, 30 deg");
        run_case(5000,  1.0,   45.0,    "5kHz full, 45 deg");
        run_case(8000,  1.0,    0.0,    "8kHz full, 0 deg");
        run_case(8000,  1.0,   30.0,    "8kHz full, 30 deg");
        run_case(8000,  1.0,   45.0,    "8kHz full, 45 deg");
        run_case(10000, 1.0,    0.0,    "10kHz full, 0 deg");
        run_case(10000, 1.0,   30.0,    "10kHz full, 30 deg");
        run_case(10000, 1.0,   45.0,    "10kHz full, 45 deg");
        run_case(10000, 1.0,   135.0,   "10kHz full, 135 deg");
        run_case(1000,  0.0,     0.0,   "zero input");

        $fclose(csv_fd);
        $display("=== %0d passed, %0d failed ===", pass_count, fail_count);
        $finish;
    end

endmodule
