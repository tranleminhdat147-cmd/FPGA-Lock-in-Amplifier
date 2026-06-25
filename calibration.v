module calibration (input signed [47:0] datain_a,
                    input signed [47:0] datain_b,
						  output signed [29:0] dataout_a,
						  output signed [29:0] dataout_b);

assign dataout_a = $signed(datain_a[39:10]); 
assign dataout_b = $signed(datain_b[39:10]);

endmodule
					