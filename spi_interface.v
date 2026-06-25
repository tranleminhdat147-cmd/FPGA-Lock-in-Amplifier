module spi_interface (
    input  wire        clk,        // PLL clock 
    input  wire        clk_50m,    // System clock(50MHz)
    input  wire        rst_n,
    output wire        sclk,
    output reg         din,
    input  wire        dout,
    output reg         cs,
    output reg  [3:0]  count,
    output reg         clock_out,
    
    output reg  [11:0] dataout,    
    output reg         data_valid  
);

    reg [11:0] data_temp;
    reg        idle_state;

    reg [11:0] dataout_slow;
    reg        valid_slow;

    initial begin
        count        = 4'd0;
        cs           = 1'b0;
        din          = 1'b0;
        clock_out    = 1'b0;
        dataout      = 12'd0;
        data_temp    = 12'd0;
        idle_state   = 1'b1;
        data_valid   = 1'b0;
        dataout_slow = 12'd0;
        valid_slow   = 1'b0;
    end

    // SCLK idles high. When CS is low, it follows clk.
    assign sclk = cs ? 1'b1 : clk;

    // 1. Counter & Idle
    always @(posedge clk) begin
        if (idle_state) begin
            idle_state <= 1'b0;
            count      <= 4'd0;
        end else begin
            if (count == 4'd15)
                idle_state <= 1'b1;
            else
                count <= count + 4'd1;
        end
    end

    // 2. CS Control
    always @(posedge clk) begin
        if (count == 4'd15 && !idle_state)
            cs <= 1'b1;
        else if (idle_state)
            cs <= 1'b0;
    end

    // 3. DIN CH2=010
    always @(negedge clk) begin
        case (count)
            4'd2:    din <= 1'b0;
            4'd3:    din <= 1'b1;
            4'd4:    din <= 1'b0;
            default: din <= 1'b0;
        endcase
    end

    // 4. Shift in DOUT
    always @(posedge clk) begin
        case (count)
            4'd4:  data_temp[11] <= dout;
            4'd5:  data_temp[10] <= dout;
            4'd6:  data_temp[9]  <= dout;
            4'd7:  data_temp[8]  <= dout;
            4'd8:  data_temp[7]  <= dout;
            4'd9:  data_temp[6]  <= dout;
            4'd10: data_temp[5]  <= dout;
            4'd11: data_temp[4]  <= dout;
            4'd12: data_temp[3]  <= dout;
            4'd13: data_temp[2]  <= dout;
            4'd14: data_temp[1]  <= dout;
            4'd15: data_temp[0]  <= dout;
            default: ;
        endcase
    end

    always @(posedge clk) begin
        clock_out  <= 1'b0;
        valid_slow <= 1'b0;
        
        if (count == 4'd15 && !idle_state) begin
            dataout_slow <= {data_temp[11:1], dout};
            clock_out    <= 1'b1;
            valid_slow   <= 1'b1;
        end
    end

    // 6. CDC — 3FF sync + Edge Detector 
    reg dv_r1, dv_r2, dv_r3;

    always @(posedge clk_50m or negedge rst_n) begin
        if (!rst_n) begin
            dv_r1      <= 1'b0;
            dv_r2      <= 1'b0;
            dv_r3      <= 1'b0;
            data_valid <= 1'b0;
            dataout    <= 12'd0;
        end else begin
            dv_r1 <= valid_slow;
            dv_r2 <= dv_r1;
            dv_r3 <= dv_r2;

            if (dv_r2 == 1'b1 && dv_r3 == 1'b0) begin
                data_valid <= 1'b1;         
                dataout    <= {dataout_slow[11]^1, dataout_slow[10:0]};   // data is latched
            end else begin
                data_valid <= 1'b0;
            end
        end
    end

endmodule