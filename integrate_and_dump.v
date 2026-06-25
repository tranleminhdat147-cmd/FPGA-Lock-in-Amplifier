module integrate_and_dump (input clk,
                           input rst_n,
									input enable,
                           input ttl_rise,
									input signed [23:0]x,
									
									output reg valid_out,
									output reg signed [47:0]sum_out,
									output reg [31:0]N_sample);
reg signed [47:0] accumlator;
reg [31:0] sample_count;
	
always @ (posedge clk) begin 
     if(!rst_n) begin 
	     accumlator <= 48'b0;
		  sample_count <= 32'b0;
		  valid_out <= 1'b0;
	     sum_out <= 48'b0;
		  N_sample <= 32'b0;
	  end 
	  else begin 
	     if (ttl_rise) begin
		      sum_out <= accumlator;
				N_sample <= sample_count;
				valid_out <= 1'b1;
				
				accumlator <= 48'b0;
				sample_count <= 32'b0;
		  end 
		  else begin
		      valid_out <= 1'b0;
		  
		     if (enable) begin
		        accumlator <= accumlator + x;
			     sample_count <= sample_count + 32'b1;
		     end
		  end 
	  end 
end 
endmodule 