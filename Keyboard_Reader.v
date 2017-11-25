module Keyboard_Reader (
	// Inputs
	input            CLOCK_50       , // Clock
	//input reset,
	//input start_read,
   input      [3:0] KEY            ,
	//input            ps2_key_pressed,
	//input      [7:0] ps2_key_data   ,
	// Bidirectionals
	inout            PS2_CLK        ,
	inout            PS2_DAT        ,
	// Outputs
 	output reg [9:0] LEDR           ,
 	output     [6:0] HEX0           ,
 	output     [6:0] HEX2	,
	output [6:0] HEX4
 );

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/

/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/

/*****************************************************************************
 *                           Constant Declarations                           *
 *****************************************************************************/

	// states
	parameter
	READER_STATE_0_IDLE = 4'd0,
	READER_STATE_1_READ = 4'd1,
	READER_STATE_2_COMPARE = 4'd2,
	READER_STATE_3_MATCH = 4'd3,
	READER_STATE_4_CHECK = 4'd4,
	READER_STATE_5_OUTPUT = 4'd5,
	READER_STATE_6_FAIL = 4'd6,
	READER_STATE_7_NEW = 4'd7,
	READER_STATE_WAIT = 4'd8;

/*****************************************************************************
 *                 Internal wires and registers Declarations                 *
 *****************************************************************************/

	// Internal Wires
	wire resetn;
	//wire reset;
	// wire reset ;
	reg enable_next_level;
	wire ps2_key_pressed;
	wire [7:0] ps2_key_data;
	wire       clk         ;
	wire       timer_done  ;
	wire [7:0] num_char;
	wire start_read;
	// wire [87:0]sequence;
		// Internal Registers
		reg finished;
		reg        enable_timer           ;
		reg  [1:0] debouncing_count       ;
		reg        failed_input           ;
		reg        writeEn                ;
		reg        correct_data_received  ;
		reg        get_next_character     ;
		reg  [7:0] total_keystroke_count  ;
		wire [7:0] comparison_data        ;
		reg  [7:0] last_data_received     ;
		reg  [3:0] current_state          ;
		reg  [3:0] next_state             ;
		reg  [7:0] correct_keystroke_count;
		
		assign clk=CLOCK_50;

/*****************************************************************************
 *                         Finite State Machine(s)                           *
 *****************************************************************************/

			always @(*) begin : state_table
				case (current_state)
					READER_STATE_WAIT : next_state = (start_read) ? READER_STATE_7_NEW : READER_STATE_WAIT;
					READER_STATE_7_NEW : next_state = READER_STATE_0_IDLE;
					READER_STATE_0_IDLE :
						begin
							if (timer_done)
								next_state = READER_STATE_6_FAIL;
							else
								next_state = (ps2_key_pressed) ? READER_STATE_1_READ : READER_STATE_0_IDLE;
						end
					READER_STATE_1_READ :
						begin
							next_state = READER_STATE_2_COMPARE;
						end
					READER_STATE_2_COMPARE :
						begin
							next_state = (last_data_received == comparison_data) ? READER_STATE_3_MATCH : READER_STATE_0_IDLE;
						end
					READER_STATE_3_MATCH :
						begin
							next_state = READER_STATE_4_CHECK;
						end
					READER_STATE_4_CHECK :
						begin
							next_state = (correct_keystroke_count == num_char) ? READER_STATE_5_OUTPUT : READER_STATE_0_IDLE;
						end
					READER_STATE_5_OUTPUT :
						begin
							next_state = READER_STATE_WAIT;
						end
					READER_STATE_6_FAIL:
						begin
							next_state = READER_STATE_6_FAIL;
						end

					default : next_state = READER_STATE_WAIT;
				endcase // current_state
			end

		always @(*) begin : enable_signals
			get_next_character    = 1'b0;
			writeEn               = 1'b0;
			correct_data_received = 1'b0;
			failed_input          = 1'b0;
			enable_next_level     = 1'b0;
			finished = 1'd0;
			case (current_state)
				READER_STATE_WAIT : 
				begin
					finished = 1'b1;
				end
				READER_STATE_1_READ :
					begin
						//get_next_character = 1'b1;
					end
				READER_STATE_3_MATCH :
					begin
						if(last_data_received == comparison_data) begin
							correct_data_received = 1'b1;
							get_next_character    = 1'b1;
						end
					end
				READER_STATE_5_OUTPUT :
					begin
						writeEn           = 1'b1;
					end
				READER_STATE_6_FAIL :
					begin
						failed_input = 1'd1;
					end
				READER_STATE_7_NEW : 
				begin
					enable_next_level = 1'b1;
				end
			endcase // current_state
		end


/*****************************************************************************
		*                             Sequential logic                              *
		*****************************************************************************/

			always @(posedge clk) begin : state_change
				if(!resetn) begin
					current_state <= READER_STATE_WAIT;
				end
				else begin
					current_state <= next_state;
				end
			end

		always @(posedge clk) begin
			if(!resetn||finished) begin
				correct_keystroke_count <= 0;
			end
			else if (correct_data_received) begin
				//&& debouncing_count == 2'd2
				correct_keystroke_count <= correct_keystroke_count + 1;
			end
		end

		always @(posedge clk) begin
			if (!resetn||finished) begin
				debouncing_count      <= 2'd0;
				last_data_received    <= 8'h00;
				total_keystroke_count <= 0;
				enable_timer          <= 0;
			end
			else if (ps2_key_pressed == 1'b1 && debouncing_count==2'd2) begin
				debouncing_count      <= 0;
				total_keystroke_count <= total_keystroke_count + 1;
			end
			else if (ps2_key_pressed == 1'b1) begin
				last_data_received <= ps2_key_data;
				enable_timer       <= 1;
				debouncing_count   <= debouncing_count + 1'b1;
			end
		end

		// always @(posedge clk) begin
		// 	if(!resetn) begin
		// 		LEDR[8:0] <= 0;

		// 	end
		// 	else if (writeEn)
		// 		LEDR[0] <= ~LEDR[0];
		// end

		// always @ (posedge clk) begin
		// 	if(!resetn)
		// 		LEDR[9] <= 0;
		// 	else if(failed_input)
		// 		LEDR[9] <= 1;
		// end


/*****************************************************************************
 *                            Combinational logic                            *
 *****************************************************************************/
			assign resetn				 =KEY[0];
			assign start_read =~KEY[1];
			//assign resetn=~reset;
			

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/

			 PS2_Controller PS2 (
			 	// Inputs
				.CLOCK_50        (clk       ),
				.reset           (reset          ),

			 	// Bidirectionals
			 	.PS2_CLK         (PS2_CLK        ),
				.PS2_DAT         (PS2_DAT        ),

			//Outputs
		 	.received_data   (ps2_key_data   ),
			 	.received_data_en(ps2_key_pressed)
			);
			
			
			
			



			// Keyboard_Input_Shift i_KeyBoard_Input_Shift (
			// 	.num_char          (char_num          ),
			// 	.sequence          (sequence          ),
			// 	.resetn            (resetn            ),
			// 	.get_next_character(get_next_character),
			// 	.clk               (clk               ),
			// 	.char_num          (char_num          ),
			// 	.comparison_data   (comparison_data   )
			// );

							hex_decoder i_hex_decoder0 (
							 	.hex_digit(correct_keystroke_count[3:0]),
							 	.segments (HEX0                        )
							 );

							 hex_decoder i_hex_decoder1 (
							 	.hex_digit(total_keystroke_count[3:0]),
							 	.segments (HEX2                  )
							 );
							 
							 							 hex_decoder i_hex_decoder2 (
							 	.hex_digit(current_state),
							 	.segments (HEX4                   )
							 );

	Keyboard_Parser i_Keyboard_Parser (
		.clk               (clk               ),
		.resetn            (resetn            ),
		.get_next_character(get_next_character),
		.enable_next_level (enable_next_level ),
		.num_char          (num_char          ),
		.comparison_data   (comparison_data   )
	);


			timer_3s i_timer_3s (
				.clk              (clk              ),
				.q                (timer_done       ),
				.enable_next_level(enable_next_level),
				.enable           (enable_timer     ),
				.resetn           (resetn           )
			);
			endmodule


