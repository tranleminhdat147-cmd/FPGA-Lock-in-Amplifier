`timescale 1ns/1ps

module lut_sincos_tb();

    // Các tham số cấu hình tương ứng với module chính
    parameter PHASE_WIDTH = 32;
    parameter ADDR_WIDTH  = 10;
    parameter DATA_WIDTH  = 12;

    // Khai báo các tín hiệu kết nối
    reg clk;
    reg rst_n;
    reg [PHASE_WIDTH-1:0] phase_step;
    reg ttl_rise;
    reg enable;

    wire valid_out;
    wire signed [DATA_WIDTH-1:0] sine_wave;
    wire signed [DATA_WIDTH-1:0] cosine_wave;

    // Khởi tạo khối DUT (Device Under Test)
    lut_sincos #(
        .PHASE_WIDTH(PHASE_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .phase_step(phase_step),
        .ttl_rise(ttl_rise),
        .enable(enable),
        .valid_out(valid_out),
        .sine_wave(sine_wave),
        .cosine_wave(cosine_wave)
    );

    // Tạo xung nhịp hệ thống (Ví dụ: 50 MHz -> Chu kỳ T = 20 ns)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // Đảo trạng thái mỗi 10ns
    end

    // Kịch bản kiểm tra (Test Scenario)
    initial begin
        // 1. Khởi tạo trạng thái ban đầu
        rst_n = 0;
        ttl_rise = 0;
        enable = 0;
        
        // TÍNH TOÁN PHASE STEP CHO TẦN SỐ 1 KHz:
        // Công thức DDS: phase_step = (f_out * 2^PHASE_WIDTH) / f_sample
        // Giả sử f_sample = f_clk = 50 MHz
        // phase_step = (1000 * 2^32) / 50,000,000 ≈ 85899.34
        phase_step = 32'd85899; 

        // 2. Nhả reset (Đưa rst_n lên mức 1) sau 50ns
        #50;
        rst_n = 1;
        
        // 3. Kích hoạt module chạy (Cờ từ ADC)
        #20;
        enable = 1; // Giữ enable mức 1 để bộ cộng pha hoạt động mỗi xung nhịp
        
        // 4. Giả lập một xung ttl_rise từ máy phát hàm để Reset Pha (Tùy chọn)
        // Điều này giúp sóng Sine bắt đầu chính xác từ góc 0 độ
        #100;
        ttl_rise = 1;
        #20;
        ttl_rise = 0;

        // 5. Chạy mô phỏng trong 3 ms 
        // 1 KHz tương ứng với chu kỳ 1 ms. 
        // Chạy 3 ms để quan sát trọn vẹn 3 chu kỳ sóng trên dạng đồ thị (Waveform)
        #3000000; 
        
        // Kết thúc mô phỏng
        $display("Mô phỏng hoàn tất! Hãy mở cửa sổ Waveform để xem sine_wave và cosine_wave.");
        $stop;
    end

endmodule