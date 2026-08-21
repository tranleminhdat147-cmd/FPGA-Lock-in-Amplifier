module uart_packetizer (
    input  wire        clk,          // System clock (e.g., 50 MHz from DE0-Nano)
    input  wire        rst_n,        // Active-low reset
    
    
    // 1. Interface with FIFO (holds data from CORDIC/Filter)
    
    input  wire        fifo_empty,   // FIFO empty flag (0 = data available)
    input  wire [95:0] fifo_data,    // 96-bit data (Magnitude, Phase, N_step)
    output reg         fifo_rdreq,   // FIFO read request pulse
    
    
    // 2. Interface with UART TX block (bit serializer)
    
    input  wire        tx_ready,     // UART ready flag (1 = ready to accept new byte)
    output reg         tx_start,     // Pulse to trigger UART to start transmitting
    output reg  [7:0]  tx_data       // Data byte fed into UART
);

    // Define the 5 FSM states
    localparam IDLE       = 3'd0;
    localparam LATCH      = 3'd1;
    localparam SEND_BYTE  = 3'd2;
    localparam WAIT_ACK   = 3'd3;
    localparam WAIT_DONE  = 3'd4;

    reg [2:0]  state;
    reg [3:0]  byte_cnt;             // Counter from 0 to 12 (13 bytes total)
    reg [95:0] data_reg;             // 96-bit latch register

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            fifo_rdreq <= 1'b0;
            tx_start   <= 1'b0;
            tx_data    <= 8'h00;
            byte_cnt   <= 4'd0;
            data_reg   <= 96'd0;
        end else begin
            // Default: deassert trigger pulses so they act as single-cycle pulses
            fifo_rdreq <= 1'b0;
            tx_start   <= 1'b0;

            case (state)
                
                // STATE 0: Idle, waiting for new data
                
                IDLE: begin
                    byte_cnt <= 4'd0;
                    // If FIFO has data AND UART is not busy
                    if (!fifo_empty && tx_ready) begin
                        fifo_rdreq <= 1'b1; // Trigger read from FIFO
                        state      <= LATCH;
                    end
                end

                
                // STATE 1: Safely latch the data
                
                LATCH: begin
                    // Wait one clock cycle for FIFO to output data, then latch it into the internal register
                    data_reg <= fifo_data;
                    state    <= SEND_BYTE;
                end

                
                // STATE 2: Select byte and trigger UART
                
                SEND_BYTE: begin
                    // MUX that splits the 13-byte packet (1 Header + 12 Data)
                    case (byte_cnt)
                        4'd0:  tx_data <= 8'hAA;                  // Header Byte (0xAA)
                        
                        // 4 Bytes of Magnitude
                        4'd1:  tx_data <= data_reg[95:88];
                        4'd2:  tx_data <= data_reg[87:80];
                        4'd3:  tx_data <= data_reg[79:72];
                        4'd4:  tx_data <= data_reg[71:64];
                        
                        // 4 Bytes of Phase
                        4'd5:  tx_data <= data_reg[63:56];
                        4'd6:  tx_data <= data_reg[55:48];
                        4'd7:  tx_data <= data_reg[47:40];
                        4'd8:  tx_data <= data_reg[39:32];
                        
                        // 4 Bytes of N_step
                        4'd9:  tx_data <= data_reg[31:24];
                        4'd10: tx_data <= data_reg[23:16];
                        4'd11: tx_data <= data_reg[15:8];
                        4'd12: tx_data <= data_reg[7:0];
                        
                        default: tx_data <= 8'h00;
                    endcase
                    
                    tx_start <= 1'b1;     // Tell UART to start transmitting
                    state    <= WAIT_ACK;
                end

                
                // STATE 3: Wait for UART to acknowledge the command
                
                WAIT_ACK: begin
                    // Wait for tx_ready to drop to 0 (indicates UART has started shifting out bits)
                    if (!tx_ready) begin
                        state <= WAIT_DONE;
                    end
                end

                
                // STATE 4: Wait for UART to finish transmitting
                
                WAIT_DONE: begin
                    // Wait for tx_ready to go back to 1 (indicates UART has finished sending the stop bit)
                    if (tx_ready) begin
                        if (byte_cnt == 4'd12) begin
                            state <= IDLE;       // All 13 bytes sent, return to wait for next packet
                        end else begin
                            byte_cnt <= byte_cnt + 1'b1;
                            state    <= SEND_BYTE; // Go back and send the next byte
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
