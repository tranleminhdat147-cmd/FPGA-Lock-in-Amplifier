module data_delay_block # 
( parameter DATA_WIDTH = 12
)(input clk,
  input rst_n,
  input data_valid_spi_in,
  output reg data_valid_spi_out,
  input [DATA_WIDTH-1:0] data_in,
  output reg [DATA_WIDTH-1:0] data_out);
  
  reg [DATA_WIDTH-1:0] buffer;
  
  always @ (posedge clk or negedge rst_n) begin 
       if (!rst_n) begin
		    data_out <= {DATA_WIDTH{1'b0}};
			 buffer <= {DATA_WIDTH{1'b0}};
		 end 
		 else begin
		    //buffer <= data_in;
			 data_out <= data_in;
		end
	end
	
   reg dv_spi_buffer; 
   
	always @(posedge clk or negedge rst_n) begin
	     if (!rst_n) begin
		    dv_spi_buffer <= 1'b0;
			 data_valid_spi_out <= 1'b0;
		  end
		  else begin
         //dv_spi_buffer <= data_valid_spi_in;
         data_valid_spi_out <= data_valid_spi_in;
		  end
   end


endmodule 