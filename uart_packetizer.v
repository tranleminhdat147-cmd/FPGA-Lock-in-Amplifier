module uart_packetizer (
    input  wire        clk,          // Xung nhịp hệ thống (ví dụ: 50 MHz từ DE0-Nano)
    input  wire        rst_n,        // Reset tích cực mức thấp
    
    // ==========================================
    // 1. Giao tiếp với FIFO (Chứa dữ liệu từ CORDIC/Filter)
    // ==========================================
    input  wire        fifo_empty,   // Cờ báo FIFO rỗng (0 = có dữ liệu)
    input  wire [95:0] fifo_data,    // Dữ liệu 96-bit (Magnitude, Phase, N_step)
    output reg         fifo_rdreq,   // Xung yêu cầu đọc FIFO
    
    // ==========================================
    // 2. Giao tiếp với khối UART TX (Bộ dịch bit)
    // ==========================================
    input  wire        tx_ready,     // Khối UART báo rảnh (1 = Sẵn sàng nhận byte mới)
    output reg         tx_start,     // Xung kích hoạt UART bắt đầu truyền
    output reg  [7:0]  tx_data       // Byte dữ liệu đưa vào UART
);

    // Định nghĩa 5 trạng thái của FSM
    localparam IDLE       = 3'd0;
    localparam LATCH      = 3'd1;
    localparam SEND_BYTE  = 3'd2;
    localparam WAIT_ACK   = 3'd3;
    localparam WAIT_DONE  = 3'd4;

    reg [2:0]  state;
    reg [3:0]  byte_cnt;             // Bộ đếm từ 0 đến 12 (tổng 13 bytes)
    reg [95:0] data_reg;             // Thanh ghi chốt 96-bit

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            fifo_rdreq <= 1'b0;
            tx_start   <= 1'b0;
            tx_data    <= 8'h00;
            byte_cnt   <= 4'd0;
            data_reg   <= 96'd0;
        end else begin
            // Mặc định hạ các xung kích hoạt để tạo thành xung đơn (1 clock cycle)
            fifo_rdreq <= 1'b0;
            tx_start   <= 1'b0;

            case (state)
                // --------------------------------------------------
                // TRẠNG THÁI 0: Đứng chờ dữ liệu mới
                // --------------------------------------------------
                IDLE: begin
                    byte_cnt <= 4'd0;
                    // Nếu FIFO có số liệu VÀ UART đang không bận
                    if (!fifo_empty && tx_ready) begin
                        fifo_rdreq <= 1'b1; // Kích hoạt lấy dữ liệu từ FIFO
                        state      <= LATCH;
                    end
                end

                // --------------------------------------------------
                // TRẠNG THÁI 1: Chốt dữ liệu an toàn
                // --------------------------------------------------
                LATCH: begin
                    // Đợi 1 nhịp clock để FIFO xuất dữ liệu ra, chốt vào thanh ghi nội bộ
                    data_reg <= fifo_data;
                    state    <= SEND_BYTE;
                end

                // --------------------------------------------------
                // TRẠNG THÁI 2: Chọn Byte và Kích hoạt UART
                // --------------------------------------------------
                SEND_BYTE: begin
                    // Bộ MUX phân rã gói dữ liệu 13 byte (1 Header + 12 Data)
                    case (byte_cnt)
                        4'd0:  tx_data <= 8'hAA;                  // Header Byte (0xAA)
                        
                        // 4 Bytes của Magnitude
                        4'd1:  tx_data <= data_reg[95:88];
                        4'd2:  tx_data <= data_reg[87:80];
                        4'd3:  tx_data <= data_reg[79:72];
                        4'd4:  tx_data <= data_reg[71:64];
                        
                        // 4 Bytes của Phase
                        4'd5:  tx_data <= data_reg[63:56];
                        4'd6:  tx_data <= data_reg[55:48];
                        4'd7:  tx_data <= data_reg[47:40];
                        4'd8:  tx_data <= data_reg[39:32];
                        
                        // 4 Bytes của N_step
                        4'd9:  tx_data <= data_reg[31:24];
                        4'd10: tx_data <= data_reg[23:16];
                        4'd11: tx_data <= data_reg[15:8];
                        4'd12: tx_data <= data_reg[7:0];
                        
                        default: tx_data <= 8'h00;
                    endcase
                    
                    tx_start <= 1'b1;     // Ra lệnh cho UART bắt đầu chạy
                    state    <= WAIT_ACK;
                end

                // --------------------------------------------------
                // TRẠNG THÁI 3: Đợi UART xác nhận đã nhận lệnh
                // --------------------------------------------------
                WAIT_ACK: begin
                    // Đợi chân tx_ready tụt xuống 0 (báo hiệu UART đã bắt đầu dịch bit)
                    if (!tx_ready) begin
                        state <= WAIT_DONE;
                    end
                end

                // --------------------------------------------------
                // TRẠNG THÁI 4: Đợi UART truyền xong
                // --------------------------------------------------
                WAIT_DONE: begin
                    // Đợi chân tx_ready nảy lên 1 (báo hiệu UART đã gửi xong bit Stop)
                    if (tx_ready) begin
                        if (byte_cnt == 4'd12) begin
                            state <= IDLE;       // Đã gửi đủ 13 bytes, quay về chờ gói mới
                        end else begin
                            byte_cnt <= byte_cnt + 1'b1;
                            state    <= SEND_BYTE; // Quay lại gửi byte tiếp theo
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule