module lut_sincos #(
    parameter PHASE_WIDTH = 32,
    parameter ADDR_WIDTH  = 10,
    parameter DATA_WIDTH  = 12
)(
    input  wire                      clk,
    input  wire                      rst_n,
    
    // --- CÁC CHÂN ĐIỀU KHIỂN MỚI THÊM VÀO ---
    input  wire [PHASE_WIDTH-1:0]    phase_step, // Từ khối Frequency Tracker đưa sang
    input  wire                      ttl_rise,   // Xung sườn lên từ TTL để Reset Phase
    input  wire                      enable,   // Cờ từ ADC: Báo có mẫu mới
    output reg                       valid_out,  // Cờ báo cho Mixer: Sóng Sine đã sẵn sàng
    // ----------------------------------------
    
    output reg  signed [DATA_WIDTH-1:0]  sine_wave,
    output reg  signed [DATA_WIDTH-1:0]  cosine_wave
);

// =========================================================================
// 1. PHASE ACCUMULATOR (Có kiểm soát nhịp và Khóa pha)
// =========================================================================
reg [PHASE_WIDTH-1:0] phase;

always @(posedge clk) begin        
    if(!rst_n) begin
        phase <= 32'b0;
    end else begin
        // Ưu tiên 1: Máy phát hàm bắt đầu chu kỳ mới -> Đập pha về 0 (Khóa pha)
        if (ttl_rise) begin
            phase <= 32'b0;
        end 
        // Ưu tiên 2: Chỉ quay vector pha khi ADC thực sự bơm data vào
        else if (enable) begin
            phase <= phase + phase_step;
        end
    end
end


wire [ADDR_WIDTH-1:0] index_sine;
wire [ADDR_WIDTH-1:0] index_cosine;

assign index_sine   = phase[PHASE_WIDTH-1 : PHASE_WIDTH-ADDR_WIDTH];


assign index_cosine = (phase[PHASE_WIDTH-1 : PHASE_WIDTH-ADDR_WIDTH] 
                     + (1 << (ADDR_WIDTH-2))) 
                     & {ADDR_WIDTH{1'b1}};   

(* ramstyle = "M9K" *) 
reg signed [DATA_WIDTH-1:0] sine_lut [0:(1<<ADDR_WIDTH)-1];

initial begin
    $readmemh("sine_lut.hex", sine_lut);
end

// =========================================================================
// 4. OUTPUT REGISTER & PIPELINE DELAY MATCHING
// =========================================================================
// Do việc đọc RAM tốn 1 xung clock, và việc tính phase tốn 1 xung clock.
// Ta phải tạo một thanh ghi trễ 2 nhịp (Shift Register) cho tín hiệu Valid
// để nó xuất hiện đúng lúc sine_wave nhảy ra ngoài.
reg valid_d1;

always @(posedge clk) begin
    if (!rst_n) begin
        valid_d1  <= 1'b0;
        valid_out <= 1'b0;
        sine_wave <= 0;
        cosine_wave <= 0;
    end else begin
        // Đọc LUT đồng bộ
        sine_wave   <= sine_lut[index_sine];
        cosine_wave <= sine_lut[index_cosine];
        
        // Trễ cờ Valid 2 nhịp clock
        valid_d1  <= enable;  
        valid_out <= valid_d1;  
    end
end

endmodule