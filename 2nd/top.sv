`include "common.vh"

module top #(
	parameter RECEIVER_PERIOD = 646,
	//300MHz
	//  300000000/115200/2 = 1302.0833333333333
	//  1302 - 10 = 1292
	//200MHz
	//  1292/1.5 = 861.3333333333334
	//180MHz
	//  1292*0.6 = 775.1999999999999
	//150MHz
	//  1292/2 = 646
	//100MHz
	//  1292/3 = 430.6666666666667
	parameter SENDER_PERIOD = 1292
	//300MHz
	//  300000000/115200 = 2604.1666666666665
	//  2604 - 20 = 2584
	//200MHz
	//  2584/1.5 = 1722.6666666666667
	//180MHz
	//  2584*0.6 = 1550.3999999999999
	//150MHz
	//  2584/2 = 1292
	//100MHz
	//  2584/3 = 861.3333333333334
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX,
	output logic[7:0] LED
);
	logic clk;
	//IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));
	clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(clk));

	core #(
		.RECEIVER_PERIOD(RECEIVER_PERIOD),
		.SENDER_PERIOD(SENDER_PERIOD)
	) core(
		.clk,
		.UART_RX,
		.UART_TX,
		.LED
	);
endmodule
