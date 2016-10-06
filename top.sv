module top #(
	parameter INST_MEM_WIDTH = 15,  //TODO too large?
	parameter DATA_MEM_WIDTH = 16   //TODO too large?
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX
);
	logic CLK;
	IBUFGDS IBUFGDS_instance(.I(CLK_P), .IB(CLK_N), .O(CLK));

	localparam OP_ADDI = 6'b001000;
	localparam OP_IN   = 6'b011010;
	localparam OP_OUT  = 6'b011011;

	logic[31:0] inst_mem[2**INST_MEM_WIDTH-1:0] = '{
		0                  : {OP_IN  , 5'b0, 5'd1, 16'b0},
		2**INST_MEM_WIDTH-1: {OP_OUT , 5'b0, 5'd1, 16'b0},
		default            : {OP_ADDI, 5'd1, 5'd1, 16'd1}
	};
	//logic[2**DATA_MEM_WIDTH-1:0][31:0] data_mem;
	logic[31:0][31:0] r;
	logic[INST_MEM_WIDTH-1:0] pc = 0;
	logic[31:0] inst;

	assign inst = inst_mem[pc];

	always @(posedge CLK) begin
		case (inst[31:26])
			OP_ADDI: r[inst[20:16]] <= r[inst[25:21]] + {{16{inst[15]}}, inst[15:0]};
			OP_IN  : if (receiver_valid) r[inst[20:16]][7:0] <= receiver_data;
		endcase
		if (!(inst[31:26]==OP_IN && !receiver_valid || inst[31:26]==OP_OUT && !sender_ready)) pc <= pc + 1;
	end



	logic[7:0] receiver_data;
	logic receiver_valid;
	logic sender_ready;

	receiver receiver_instance(CLK, UART_RX, receiver_data, receiver_valid);
	sender sender_instance(CLK, r[inst[20:16]][7:0], inst[31:26]==OP_OUT, UART_TX, sender_ready);
endmodule
