 module timer_3s(clk,q,enable,resetn,enable_next_level);//150M
			input clk;
			input enable_next_level;
			output reg q;
			input enable;
			input resetn;
			reg[27:0]counter;
			always@(posedge clk) begin
				if(!resetn || enable_next_level) begin
					counter <= 150000000;
					q <= 0;
				end
				else if (!counter)begin
					counter <= 150000000;
					q <= 1;
				end
				else if (enable)
					counter <= counter-1;
			end
endmodule