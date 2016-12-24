module top_loopback1(
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX
);
	logic start_send;
	logic[7:0] receiver_to_sender;

	logic CLK;
	IBUFGDS ibufgds(.I(CLK_P), .IB(CLK_N), .O(CLK));

	receiver receiver_instance(CLK, UART_RX, receiver_to_sender, start_send);
	sender sender_instance(CLK, receiver_to_sender, start_send, UART_TX);
endmodule
