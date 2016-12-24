module test_loopback(
	//input logic CLK,
	input logic UART_RX,
	output logic UART_TX
);
	assign UART_TX = UART_RX;

endmodule
