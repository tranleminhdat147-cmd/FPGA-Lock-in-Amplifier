module UART_TX 
  #(parameter CLKS_PER_BIT = 217)
  (
   input       Rst_L,
   input       Clock,
   input       TX_DV,
   input [7:0] TX_Byte, 
   output reg  TX_Active,
   output reg  TX_Serial,
   output reg  TX_Done
   );
  
  localparam IDLE         = 2'b00;
  localparam TX_START_BIT = 2'b01;
  localparam TX_DATA_BITS = 2'b10;
  localparam TX_STOP_BIT  = 2'b11;
  
  reg [2:0] r_SM_Main;
  reg [$clog2(CLKS_PER_BIT):0] r_Clock_Count;
  reg [2:0] r_Bit_Index;
  reg [7:0] r_TX_Data;

  // Purpose: Control TX state machine
  always @(posedge Clock or negedge Rst_L)
  begin
    if (~Rst_L)
    begin
      r_SM_Main <= 3'b000;
    end
    else
    begin
      TX_Done <= 1'b0;
      case (r_SM_Main)
      IDLE :
        begin
          TX_Serial     <= 1'b1;         // Drive Line High for Idle
          r_Clock_Count <= 0;
          r_Bit_Index   <= 0;
          
          if (TX_DV == 1'b1)
          begin
            TX_Active <= 1'b1;
            r_TX_Data <= TX_Byte;
            r_SM_Main <= TX_START_BIT;
          end
          else
            r_SM_Main <= IDLE;
        end // case: IDLE
      
      
      // Send out Start Bit. Start bit = 0
      TX_START_BIT :
        begin
          TX_Serial <= 1'b0;
          
          // Wait CLKS_PER_BIT-1 clock cycles for start bit to finish
          if (r_Clock_Count < CLKS_PER_BIT-1)
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= TX_START_BIT;
          end
          else
          begin
            r_Clock_Count <= 0;
            r_SM_Main     <= TX_DATA_BITS;
          end
        end // case: TX_START_BIT
      
      
      // Wait CLKS_PER_BIT-1 clock cycles for data bits to finish         
      TX_DATA_BITS :
        begin
          TX_Serial <= r_TX_Data[r_Bit_Index];
          
          if (r_Clock_Count < CLKS_PER_BIT-1)
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= TX_DATA_BITS;
          end
          else
          begin
            r_Clock_Count <= 0;
            
            // Check if we have sent out all bits
            if (r_Bit_Index < 7)
            begin
              r_Bit_Index <= r_Bit_Index + 1;
              r_SM_Main   <= TX_DATA_BITS;
            end
            else
            begin
              r_Bit_Index <= 0;
              r_SM_Main   <= TX_STOP_BIT;
            end
          end 
        end // case: TX_DATA_BITS
      
      
      // Send out Stop bit.  Stop bit = 1
      TX_STOP_BIT :
        begin
          TX_Serial <= 1'b1;
          
          // Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish
          if (r_Clock_Count < CLKS_PER_BIT-1)
          begin
            r_Clock_Count <= r_Clock_Count + 1;
            r_SM_Main     <= TX_STOP_BIT;
          end
          else
          begin
            TX_Done       <= 1'b1;
            r_Clock_Count <= 0;
            r_SM_Main     <= IDLE;
            TX_Active     <= 1'b0;
          end 
        end // case: TX_STOP_BIT      
      
      default :
        r_SM_Main <= IDLE;
      
    endcase
    end // else: !if(~Rst_L)
  end // always @ (posedge Clock or negedge Rst_L)
  
endmodule