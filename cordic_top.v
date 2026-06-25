module cordic_top # (
    parameter IN_WIDTH  = 12, 
    parameter OUT_WIDTH = 16  
)(
    input  wire clk,
    input  wire valid_in,                 // the signal is from the I&D filter
    input  wire signed [IN_WIDTH-1:0]  x_in, y_in, z_in,
    output wire valid_out,                // a flag for when CORDIC is finished
    output wire signed [OUT_WIDTH-1:0] x_out, y_out, z_out
);

    // wires connecting each of stages of CORDIC
    wire signed [OUT_WIDTH-1:0] x [0:IN_WIDTH-1];
    wire signed [OUT_WIDTH-1:0] y [0:IN_WIDTH-1];
    wire signed [OUT_WIDTH-1:0] z [0:IN_WIDTH-1];
    
    // valid wires for each stages
    wire [IN_WIDTH-1:0] valid_chain;

    // stage 0
    cordic_stage #(
        .IN_WIDTH(IN_WIDTH), 
        .OUT_WIDTH(OUT_WIDTH), 
        .i(0) 
    ) stage1 (
        .clk(clk),
        .valid_in(valid_in),         
        .x_in(x_in), 
        .y_in(y_in), 
        .z_in(z_in),
        .valid_out(valid_chain[0]),  
        .x_out(x[0]), 
        .y_out(y[0]), 
        .z_out(z[0])
    );

    // genrate the hardware for the remaining stages using "generate"
    genvar k;
    generate 
       for(k = 0; k < IN_WIDTH-1; k = k + 1) begin : pipeline_gen 
          cordic_stage #(
              .IN_WIDTH(OUT_WIDTH), 
              .OUT_WIDTH(OUT_WIDTH), 
              .i(k+1) 
          ) stage_inst (
              .clk(clk), 
              .valid_in(valid_chain[k]),   
              .x_in(x[k]),    
              .y_in(y[k]), 
              .z_in(z[k]), 
              .valid_out(valid_chain[k+1]),
              .x_out(x[k+1]), 
              .y_out(y[k+1]), 
              .z_out(z[k+1])
          );
       end
    endgenerate 

    assign valid_out = valid_chain[IN_WIDTH-1];
    assign x_out     = x[IN_WIDTH-1];
    assign y_out     = y[IN_WIDTH-1];
    assign z_out     = z[IN_WIDTH-1];

endmodule