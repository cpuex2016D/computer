module test_sendonly(
	input logic CLK_P,
	input logic CLK_N,
	//input logic UART_RX,
	output logic UART_TX
);
	int count_sec;
	int count_period;
	int state;

	logic CLK;
	IBUFGDS ibufgds(.I(CLK_P), .IB(CLK_N), .O(CLK));

	initial begin
		count_sec <= 0;
		count_period <= 0;
		state <= 0;
	end
	always_comb begin
			if (state == 0 | state == 1 | state == 4 | state == 5 | state == 8) begin
				UART_TX <= 0;
			end else begin
				UART_TX <= 1;
			end
	end
	always @(posedge CLK) begin
		if (count_sec == 99999999) begin
			count_sec <= 0;
			state <= 0;
		end else begin
			count_sec <= count_sec + 1;
		end
		if (count_period == 31249) begin
			count_period <= 0;
		end else begin
			if (state != 9) begin
				count_period <= count_period + 1;
			end
		end
		if (count_period == 31249) begin
			state <= state + 1;
		end
	end
endmodule
