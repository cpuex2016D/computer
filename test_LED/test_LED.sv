module test_LED(
	input logic CLK_P,
	input logic CLK_N,
	output logic[7:0] LED
);
	logic CLK;
	IBUFGDS ibufgds(.I(CLK_P), .IB(CLK_N), .O(CLK));

	int count_sec;
	logic[2:0] number;

	assign LED[0] = number == 0;
	assign LED[1] = number == 1;
	assign LED[2] = number == 2;
	assign LED[3] = number == 3;
	assign LED[4] = number == 4;
	assign LED[5] = number == 5;
	assign LED[6] = number == 6;
	assign LED[7] = number == 7;

	always @(posedge CLK) begin
		if (count_sec == 99999999) begin
			count_sec <= 0;
			number <= number + 1;
		end else begin
			count_sec <= count_sec + 1;
		end
	end
endmodule
