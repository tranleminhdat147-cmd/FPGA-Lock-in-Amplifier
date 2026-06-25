module multiplier #(
    parameter DATA_WIDTH = 12
)(
    input wire clk,
    input wire rst_n,             
    input wire enable,             
    input wire signed [DATA_WIDTH-1:0] AFE,
    input wire signed [DATA_WIDTH-1:0] REF,
    output reg signed [DATA_WIDTH*2-1:0] product,
    output reg valid_out           
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product   <= {(DATA_WIDTH*2){1'b0}};
            valid_out <= 1'b0;
        end else begin
            if (enable) begin
                product   <= $signed(AFE) * $signed(REF); 
                valid_out <= 1'b1;         
            end else begin
                valid_out <= 1'b0;        
            end
        end
    end
endmodule