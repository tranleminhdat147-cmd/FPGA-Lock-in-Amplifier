module cordic_stage # (
    parameter IN_WIDTH = 12,
    parameter OUT_WIDTH = 16,
    parameter i = 0
) (
    input wire clk,
    input wire valid_in,                    // VALID input
    input wire signed [IN_WIDTH-1:0] x_in,
    input wire signed [IN_WIDTH-1:0] y_in,
    input wire signed [IN_WIDTH-1:0] z_in,
    output reg valid_out,                   // VALID output
    output reg signed [OUT_WIDTH-1:0] x_out,
    output reg signed [OUT_WIDTH-1:0] y_out,
    output reg signed [OUT_WIDTH-1:0] z_out
);

    wire signed [OUT_WIDTH-1:0] x = $signed(x_in);
    wire signed [OUT_WIDTH-1:0] y = $signed(y_in);
    wire signed [OUT_WIDTH-1:0] z = $signed(z_in);

    function [OUT_WIDTH-1:0] atan;
        input [4:0] stage; 
        case (stage)
            0:  atan = 32'h20000000; // 45.00000°
            1:  atan = 32'h12E4051D; // 26.56505°
            2:  atan = 32'h09FB385B; // 14.03624°
            3:  atan = 32'h051111D4; // 7.12502°
            4:  atan = 32'h028B0D43; // 3.57633°
            5:  atan = 32'h0145D7E1; // 1.78991°
            6:  atan = 32'h00A2F61E; // 0.89517°
            7:  atan = 32'h00517C55; // 0.44761°
            8:  atan = 32'h0028BE53; // 0.22381°
            9:  atan = 32'h00145F2E; // 0.11191°
            10: atan = 32'h000A2F98; // 0.05595°
            11: atan = 32'h000517CC; // 0.02798°
            12: atan = 32'h00028BE6; // 0.01399°
            13: atan = 32'h000145F3; // 0.00699°
            14: atan = 32'h0000A2F9; // 0.00350°
            15: atan = 32'h0000517C; // 0.00175°
            16: atan = 32'h000028BE; // 0.00087°
            17: atan = 32'h0000145F; // 0.00044°
            18: atan = 32'h00000A30; // 0.00022°
            19: atan = 32'h00000518; // 0.00011°
            20: atan = 32'h0000028C; // 0.00005°
            21: atan = 32'h00000146; // 0.00003°
            22: atan = 32'h000000A3; // 0.00001°
            23: atan = 32'h00000051; // 0.00001°
            24: atan = 32'h00000029; // 0.00000°
            25: atan = 32'h00000014; // 0.00000°
            26: atan = 32'h0000000A; // 0.00000°
            27: atan = 32'h00000005; // 0.00000°
            28: atan = 32'h00000003; // approx 0
            29: atan = 32'h00000001; // approx 0
            default: atan = 32'h00000000;
        endcase
    endfunction

    always @ (posedge clk) begin
        valid_out <= valid_in; 

        if (valid_in) begin 
            if (y[OUT_WIDTH-1] == 1'b0) begin
                x_out <= x + ($signed(y) >>> i); 
                y_out <= y - ($signed(x) >>> i); 
                z_out <= z + atan(i);            
            end
            else begin
                x_out <= x - ($signed(y) >>> i); 
                y_out <= y + ($signed(x) >>> i); 
                z_out <= z - atan(i);            
            end
        end
    end

endmodule