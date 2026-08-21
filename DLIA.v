module DLIA (input clk,
           input rst_n,
          
          // TTL
          input ttl_in,
        
          //spi interface
          input dout,
          output sclk,
          output din,
          output cs,
          output clock_out, 
          output [11:0] afe_data,
          
          //cordic
          output [31:0] N_sample_out,
          output [31:0] phase,
          output [31:0] magnitude,
			 output valid_cordic,
			 
			 //uart
			 output UART_TX_PIN
          ); 
// Phase sync and frequency tracker
wire [31:0] phase_step;
wire ttl_rise_out;

frequency_tracker_sync (.clk(clk), .rst_n(1'b1), .ttl_in(ttl_in), .phase_step(phase_step), .ttl_rise_out(ttl_rise_out));
          
// spi
wire SPI_sclk;
wire [11:0] spi_dataout;
wire data_valid_spi;
phase_locked_loop p_ll (.inclk0(clk), .c0(SPI_sclk));
spi_interface afe (.clk(SPI_sclk), .clk_50m(clk), .rst_n(1'b1), .dout(dout), .sclk(sclk), .din(din), .cs(cs), .dataout(spi_dataout), .data_valid(data_valid_spi), .clock_out(clock_out));

// delay data from spi
wire [11:0]spi_delayed_data;
wire delayed_data_valid_spi;
assign afe_data = spi_delayed_data;
data_delay_block delay (.clk(clk), .rst_n(1'b1), .data_in(spi_dataout), .data_out(spi_delayed_data), .data_valid_spi_in(data_valid_spi), .data_valid_spi_out(delayed_data_valid_spi));

//dds 
wire data_valid_dds;
wire [11:0] sine;
wire [11:0] cosine;

lut_sincos dds (.clk(clk), 
                .rst_n(1'b1),
                .phase_step(phase_step), 
                .ttl_rise(ttl_rise_out), 
                .enable(1'b1), 
                .valid_out(data_valid_dds), 
                .sine_wave(sine), 
                .cosine_wave(cosine));


// mixer
wire data_valid_sine_mixer;
wire data_valid_cosine_mixer;
wire [23:0] sine_mixer_product;
wire [23:0] cosine_mixer_product;

multiplier sine_mix (.clk(clk),
                   .rst_n(1'b1),
                   .enable(delayed_data_valid_spi),
                   .AFE(spi_delayed_data),
                   .REF(sine),
                   .product(sine_mixer_product),
                   .valid_out(data_valid_sine_mixer));
                 
multiplier cosine_mix (.clk(clk),
                   .rst_n(1'b1),
                   .enable(delayed_data_valid_spi),
                   .AFE(spi_delayed_data),
                   .REF(cosine),
                   .product(cosine_mixer_product),
                   .valid_out(data_valid_cosine_mixer));
                 
// integrate and dump
wire signed [47:0] sine_filtered;
wire signed[47:0] cosine_filtered;
wire data_valid_sine_sma;
wire data_valid_cosine_sma;

integrate_and_dump sine_filter (.clk(clk),
                        .rst_n(1'b1),
                        .ttl_rise(ttl_rise_out), 
                        .enable(data_valid_sine_mixer),
                        .x(sine_mixer_product),
                        .sum_out(sine_filtered),
                        .valid_out(data_valid_sine_sma),
								.N_sample(N_sample_out));
                        
integrate_and_dump cosine_filter (.clk(clk),
                        .rst_n(1'b1),
                        .ttl_rise(ttl_rise_out), 
                        .enable(data_valid_cosine_mixer),
                        .x(cosine_mixer_product),
                        .sum_out(cosine_filtered),
                        .valid_out(data_valid_cosine_sma));

// CORDIC
wire enable_cordic; 
wire [29:0] sine_filtered_calibrated; 
wire [29:0] cosine_filtered_calibrated;

assign enable_cordic = data_valid_sine_sma & data_valid_cosine_sma;
wire data_valid_cordic;
assign valid_cordic = data_valid_cordic;
// After mixing, the signal amplitude is increased by a factor of 1024. Therefore, the data is right-shifted by 10 bits before being processed by the CORDIC block.;
calibration calibrate (.datain_a(sine_filtered), .datain_b(cosine_filtered), .dataout_a(sine_filtered_calibrated), .dataout_b(cosine_filtered_calibrated));

cordic_top #(.IN_WIDTH(30), .OUT_WIDTH(32)) CORDIC (.clk(clk),
                                                    .valid_in(enable_cordic),
													.valid_out(data_valid_cordic),
                                                    .x_in(sine_filtered_calibrated),
                                                    .y_in(cosine_filtered_calibrated),
                                                    .z_in(30'b0),
                                                    .x_out(magnitude),
                                                    .z_out(phase));
																	 
// Communication - UART FIFO;
wire fifo_empty, fifo_rdreq; 
wire [95:0] fifo_data;
wire tx_ready, tx_start, tx_active;
assign tx_ready = ~tx_active;
wire [7:0] tx_data;

Fifo fifo_inst (.clock(clk),
                .data({magnitude, phase, N_sample_out}),
					 .rdreq(fifo_rdreq),
					 .wrreq (data_valid_cordic),
					 .empty(fifo_empty),
					 .q(fifo_data));

				 
uart_packetizer  uart_packetizer_inst (.clk(clk),
                                    .rst_n(1'b1),
									.fifo_empty(fifo_empty),
									.fifo_data(fifo_data),
									.fifo_rdreq(fifo_rdreq),
									.tx_ready(tx_ready),
									.tx_start(tx_start),
									.tx_data(tx_data));


UART_TX #(
    .CLKS_PER_BIT(434)  
) u_uart_tx_inst (
    .Rst_L      (1'b1),         
    .Clock      (clk),            
    
    
    .TX_DV      (tx_start),   
    .TX_Byte    (tx_data),    
    
   
    .TX_Active  (tx_active),  
    .TX_Serial  (UART_TX_PIN)     
);			

endmodule
