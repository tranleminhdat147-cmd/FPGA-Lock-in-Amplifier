module frequency_tracker_sync (
    // Inputs
    input  wire        clk,          // System clock(50MHz)
    input  wire        rst_n,        
    input  wire        ttl_in,       // TTL from a function generator
    
    // Outputs
    output reg  [31:0] phase_step,   
    output reg         locked,       
    output wire        ttl_rise_out, // this trigger tells the DDS to set its phase step to 0
    output wire [31:0] debug_cnt     // a debug Port  
);

    // 1. 3FF SYNCHRONIZER & EDGE DETECTOR
    reg ttl_r1, ttl_r2, ttl_r3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ttl_r1 <= 1'b0;
            ttl_r2 <= 1'b0;
            ttl_r3 <= 1'b0;
        end else begin
            ttl_r1 <= ttl_in;   
            ttl_r2 <= ttl_r1;   
            ttl_r3 <= ttl_r2;   
        end
    end

    wire ttl_rise = ttl_r2 & ~ttl_r3;
    assign ttl_rise_out = ttl_rise; 
    

    // 2. FREQUENCY TRACKER (Kiến trúc 15 điểm EIS Logarithmic Sweep)
    reg [31:0] period_cnt;
    
    assign debug_cnt = period_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_cnt <= 32'd0;
            phase_step <= 32'd0;
            locked     <= 1'b0;
        end else begin
            period_cnt <= period_cnt + 32'd1;
            
            if (ttl_rise) begin
                // 1 Hz 
                if (period_cnt > 32'd49000000 && period_cnt < 32'd51000000) begin
                    phase_step <= 32'd86; locked <= 1'b1;
                end
                // 2 Hz
                else if (period_cnt > 32'd24500000 && period_cnt < 32'd25500000) begin
                    phase_step <= 32'd172; locked <= 1'b1;
                end
                // 5 Hz
                else if (period_cnt > 32'd9800000 && period_cnt < 32'd10200000) begin
                    phase_step <= 32'd429; locked <= 1'b1;
                end
                
                // 10 Hz
                else if (period_cnt > 32'd4900000 && period_cnt < 32'd5100000) begin
                    phase_step <= 32'd859; locked <= 1'b1;
                end
                // 20 Hz
                else if (period_cnt > 32'd2450000 && period_cnt < 32'd2550000) begin
                    phase_step <= 32'd1718; locked <= 1'b1;
                end
                // 50 Hz
                else if (period_cnt > 32'd980000 && period_cnt < 32'd1020000) begin
                    phase_step <= 32'd4295; locked <= 1'b1;
                end

                // 100 Hz
                else if (period_cnt > 32'd490000 && period_cnt < 32'd510000) begin
                    phase_step <= 32'd8590; locked <= 1'b1;
                end
                // 200 Hz
                else if (period_cnt > 32'd245000 && period_cnt < 32'd255000) begin
                    phase_step <= 32'd17180; locked <= 1'b1;
                end
                // 500 Hz
                else if (period_cnt > 32'd98000 && period_cnt < 32'd102000) begin
                    phase_step <= 32'd42950; locked <= 1'b1;
                end

                // 1 kHz
                else if (period_cnt > 32'd49000 && period_cnt < 32'd51000) begin
                    phase_step <= 32'd85899; locked <= 1'b1;
                end
                // 2 kHz
                else if (period_cnt > 32'd24500 && period_cnt < 32'd25500) begin
                    phase_step <= 32'd171799; locked <= 1'b1;
                end
                // 5 kHz
                else if (period_cnt > 32'd9800 && period_cnt < 32'd10200) begin
                    phase_step <= 32'd429497; locked <= 1'b1;
                end

                // 10 kHz
                else if (period_cnt > 32'd4900 && period_cnt < 32'd5100) begin
                    phase_step <= 32'd858993; locked <= 1'b1;
                end
                // 15 kHz
                else if (period_cnt > 32'd3266 && period_cnt < 32'd3400) begin
                    phase_step <= 32'd1288490; locked <= 1'b1;
                end
                // 20 kHz
                else if (period_cnt > 32'd2450 && period_cnt < 32'd2550) begin
                    phase_step <= 32'd1717987; locked <= 1'b1;
                end
                
                // Trash signal or unsupported fequency
                else begin
                    locked <= 1'b0;
                end
                
                period_cnt <= 32'd0; 
            end
        end
    end

endmodule