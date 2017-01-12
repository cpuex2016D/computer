`include "common.vh"

module top_tb;
	logic CLK_P = 0;
	logic CLK_N = 1;
	logic UART_RX = 1;
	logic UART_TX;
	logic SW_W = 0;
	logic SW_E = 0;
	logic[7:0] LED;

	localparam PERIOD = 4;
	top #(
		.RECEIVER_PERIOD(PERIOD/2),
		.SENDER_PERIOD(PERIOD)
	) top(.*);
	localparam OP_ADD     = 6'b000000;
	localparam OP_ADDI    = 6'b000001;
	localparam OP_SUB     = 6'b000010;
	localparam OP_SUBI    = 6'b000011;
	localparam OP_SL2ADD  = 6'b000100;
	localparam OP_SL2ADDI = 6'b000101;
	localparam OP_IN      = 6'b011010;
	localparam OP_OUT     = 6'b011100;
	localparam OP_J       = 6'b100000;

//	always #(0.5) begin
//		CLK_P <= !CLK_P;
//		CLK_N <= !CLK_N;
//	end
	always #(0.5) begin
		force top.clk = !top.clk;
	end

	int fd;
	int c;

	initial begin
		fd = $fopen("../../../program_loopback_text", "rb");
		#10;
		forever begin
			c = $fgetc(fd);
			if (c==-1) break;
			UART_RX <= 0;
			#PERIOD;
			for (int i=0; i<8; i++) begin
				UART_RX <= c[i];
				#PERIOD;
			end
			UART_RX <= 1;
			#PERIOD;
			#1;
		end

		#10;
		SW_E <= !SW_E;
		#10;
		SW_E <= !SW_E;

		fd = $fopen("../../../program_loopback_data", "rb");
		#10;
		forever begin
			c = $fgetc(fd);
			if (c==-1) break;
			UART_RX <= 0;
			#PERIOD;
			for (int i=0; i<8; i++) begin
				UART_RX <= c[i];
				#PERIOD;
			end
			UART_RX <= 1;
			#PERIOD;
			#1;
		end
	end
endmodule
