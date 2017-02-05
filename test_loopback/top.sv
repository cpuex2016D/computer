module top #(
	//300MHz 115200baud
	//parameter RECEIVER_PERIOD = 1292,
	//parameter SENDER_PERIOD = 2584
	//300MHz 230400baud
	//parameter RECEIVER_PERIOD = 646,
	//parameter SENDER_PERIOD = 1292
	//300MHz 460800baud
	parameter RECEIVER_PERIOD = 323,
	parameter SENDER_PERIOD = 646
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX
);
	logic clk;
	IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));
	//clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(clk));

	logic valid;
	logic[7:0] data;
	receiver #(RECEIVER_PERIOD) receiver(
		.clk,
		.in(UART_RX),
		.out(data),
		.valid
	);
	sender #(SENDER_PERIOD) sender(
		.clk,
		.in(data),
		.valid,
		.out(UART_TX)
	);
endmodule
