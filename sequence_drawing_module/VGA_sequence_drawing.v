module VGA_sequence_drawing (
	input         clk                   , // Clock
	input         resetn                , // Asynchronous reset active low
	input  [ 7:0] num_char              ,
	input  [87:0] sequence_             ,
	input  [ 8:0] x_start               ,
	input  [ 8:0] y_start               ,
	input         enable_clear          ,
	input         plot_sequence         ,
	output        writeEn               ,
	output [ 8:0] x                     ,
	output [ 8:0] y                     ,
	output [ 5:0] colour                ,
	output        ready_to_plot_sequence
);

	wire       ld_sequence   ;
	wire       shift_sequence;
	wire [7:0] character_    ;

	wire [8:0] x_input;
	wire [8:0] y_input;

	VGA_SEQUENCE_DATAPATH i_VGA_SEQUENCE_DATAPATH (
		.clk           (clk           ),
		.rst_n         (resetn        ),
		.sequence_     (sequence_     ),
		.ld_sequence   (ld_sequence   ),
		.shift_sequence(shift_sequence),
		.x_start       (x_start       ),
		.y_start       (y_start       ),
		.x_input       (x_input       ),
		.y_input       (y_input       ),
		.character_    (character_    )
	);

	wire ready_to_start_character;
	wire  enable_character_plot   ;

	VGA_SEQUENCE_CONTROL i_VGA_SEQUENCE_CONTROL (
		.clk                     (clk                     ),
		.rst_n                   (resetn                  ),
		.num_char                (num_char                ),
		.plot_sequence           (plot_sequence           ),
		.ready_to_start_character(ready_to_start_character),
		.ld_sequence             (ld_sequence             ),
		.shift_sequence          (shift_sequence          ),
		.ready_to_plot_sequence  (ready_to_plot_sequence  ),
		.enable_character_plot   (enable_character_plot   )
	);

	wire [7:0] address;

	VGA_character_drawing i_VGA_character_drawing (
		.clk                     (clk                     ),
		.resetn                  (resetn                  ),
		.address                 (address                 ),
		.enable_character_plot   (enable_character_plot   ),
		.x_input                 (x_input                 ),
		.y_input                 (y_input                 ),
		.enable_clear            (enable_clear            ),
		.x                       (x                       ),
		.y                       (y                       ),
		.colour                  (colour                  ),
		.ready_to_start_character(ready_to_start_character),
		.writeEn                 (writeEn                 )
	);

	assign address = character_;

endmodule

module VGA_SEQUENCE_DATAPATH (
	input             clk           , // Clock
	input             rst_n         , // Asynchronous reset active low
	input      [87:0] sequence_     ,
	input             ld_sequence   ,
	input             shift_sequence,
	input      [ 8:0] x_start       ,
	input      [ 8:0] y_start       ,
	output reg [ 8:0] x_input       ,
	output reg [ 8:0] y_input       ,
	output reg [ 7:0] character_
);

	reg [87:0] sequence_wire;

	always@(posedge clk) begin
		if (!rst_n) begin
			character_ <= 0;
			x_input    <= 0;
			y_input    <= 0;
		end
		else if (ld_sequence) begin
			sequence_wire <= sequence_;
			x_input       <= x_start;
			y_input       <= y_start;
		end
		else if (shift_sequence) begin
			sequence_wire <= (sequence_wire << 87'd8);
			x_input       <= x_input + (8'd24);
		end
		character_ <= sequence_wire[87:80];
	end // always@(posedge clk)

endmodule

module VGA_SEQUENCE_CONTROL (
	input            clk                     , // Clock
	input            rst_n                   , // Asynchronous reset active low
	input      [7:0] num_char                ,
	input            plot_sequence           ,
	input            ready_to_start_character,
	output reg       ld_sequence             ,
	output reg       shift_sequence          ,
	output reg       ready_to_plot_sequence  ,
	output reg       enable_character_plot
);

	reg [2:0] current_state, next_state;
	reg [7:0] character_plotted;

	localparam
		S_WAIT_START_SEQUENCE = 3'd0,
			S_LOAD_SEQUENCE = 3'd1,
				S_WAIT_CHARACTER_PLOT = 3'd2,
					S_LOAD_NEXT_CHARACTER = 3'd3;


	always@(posedge clk) begin : proc_current_state
		if(~rst_n) begin
			current_state <= 0;
		end else begin
			current_state <= next_state;
		end
	end

	always @(*) begin : proc_current_state_next

		case (current_state)
			S_WAIT_START_SEQUENCE : next_state = (plot_sequence) ? S_LOAD_SEQUENCE : S_WAIT_START_SEQUENCE;
				S_LOAD_SEQUENCE       : next_state = S_WAIT_CHARACTER_PLOT;
			S_WAIT_CHARACTER_PLOT :
				begin
					if (ready_to_start_character) begin
						if (character_plotted == num_char)
							next_state = S_WAIT_START_SEQUENCE;
						else
							next_state = S_LOAD_NEXT_CHARACTER;
						end
						else
							next_state = S_WAIT_CHARACTER_PLOT;
					end
					S_LOAD_NEXT_CHARACTER : next_state = S_WAIT_CHARACTER_PLOT;

					default : next_state = S_WAIT_START_SEQUENCE;
					endcase
				end

			always @(*) begin: enable_signals
				ld_sequence = 1'b0;
				shift_sequence = 1'b0;
				enable_character_plot = 1'b0;
				case (current_state)
				S_WAIT_START_SEQUENCE :
					begin
						ready_to_plot_sequence = 1'b1;
					end
				S_LOAD_SEQUENCE:
					begin
						ld_sequence = 1'b1;
					end
				S_WAIT_CHARACTER_PLOT:
					begin
						enable_character_plot = 1'b1;
					end
				S_LOAD_NEXT_CHARACTER:
					begin
						shift_sequence = 1'b1;
					end
				endcase // current_state
			end


			always@(posedge clk) begin
				if (current_state == S_WAIT_START_SEQUENCE) begin
					character_plotted <= 0;
				end
				else if(current_state == S_LOAD_NEXT_CHARACTER) begin
					character_plotted <= character_plotted + 1;
				end
			end

			endmodule // VGA_SEQUENCE_CONTROL