module test_button(
	input logic CLK_P,
	input logic CLK_N,
	input logic SW_W,
	input logic SW_E,
	output logic LED_W,
	output logic LED_E
);
	logic CLK;
	IBUFGDS ibufgds(.I(CLK_P), .IB(CLK_N), .O(CLK));

	enum logic {
		WEST,
		EAST
	} west_or_east;

	assign LED_W = west_or_east == WEST;
	assign LED_E = west_or_east == EAST;

	always @(posedge CLK) begin
		if (SW_W) begin
			west_or_east <= WEST;
		end else if (SW_E) begin
			west_or_east <= EAST;
		end
	end
endmodule
