module top #(
	//parameter INST_MEM_WIDTH = 17,
	//parameter DATA_MEM_WIDTH = 19
	parameter INST_MEM_WIDTH = 6,
	parameter DATA_MEM_WIDTH = 5
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX,
	input logic SW_W,
	input logic SW_E,
	output logic LED_W,
	output logic LED_E,
	output logic[5:0] LED_DEBUG
);
	logic CLK;
	//IBUFGDS IBUFGDS_instance(.I(CLK_P), .IB(CLK_N), .O(CLK));
	clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(CLK));

	localparam OP_SPECIAL = 6'b000000;
	localparam OP_FPU     = 6'b010001;
	localparam OP_ADDI    = 6'b001000;
	localparam OP_ORI     = 6'b001101;
	localparam OP_J       = 6'b000010;
	localparam OP_LUI     = 6'b001111;
	localparam OP_LW      = 6'b100011;
	localparam OP_SW      = 6'b101011;
	localparam OP_IN      = 6'b011010;
	localparam OP_OUT     = 6'b011011;
	localparam OP_LW_S    = 6'b110001;
	localparam OP_SW_S    = 6'b111001;
	localparam FUNCT_SLL = 6'b000000;
	localparam FUNCT_SRL = 6'b000010;

	enum logic {
		LOAD,
		EXEC
	} mode = LOAD;

	logic[DATA_MEM_WIDTH-1:0] data_mem_addr;
	logic[31:0] data_mem_in;
	logic[31:0] data_mem_out;
	logic data_mem_we;
	logic data_read_stall = 0;
	data_mem data_mem(
		.addra(data_mem_addr),
		.clka(CLK),
		.dina(data_mem_in),
		.douta(data_mem_out),
		.wea(data_mem_we)
	);
	logic[31:0] inst_mem[2**INST_MEM_WIDTH-1:0];
	logic[31:0][31:0] gpr;
	logic[31:0][31:0] fpr;
	logic[INST_MEM_WIDTH-1:0] pc = 0;
	logic[1:0] pc_sub = 0;  // mode==LOAD の時しか使わない
	logic[31:0] inst;

	logic[31:0] fadd_fsub_out;
	fadd_fsub fadd_fsub(
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[15:11]]),
		.s_axis_b_tvalid(1'b1),
		.s_axis_b_tdata(fpr[inst[20:16]]),
		.s_axis_operation_tvalid(1'b1),
		.s_axis_operation_tdata({7'b0000000, inst[0]}),
		.m_axis_result_tdata(fadd_fsub_out)
	);

	assign LED_W = mode==LOAD;
	assign LED_E = mode==EXEC;
	assign LED_DEBUG = {pc[3:0], pc_sub};
	assign inst = inst_mem[pc];
	assign data_mem_addr = gpr[inst[25:21]] + inst[15:0];  //TODO 幅が合っていない
	assign data_mem_in = inst[30] ? fpr[inst[20:16]] : gpr[inst[20:16]];
	assign data_mem_we = mode==EXEC && (inst[31:26]==OP_SW || inst[31:26]==OP_SW_S);

	always @(posedge CLK) begin
		if (SW_W) begin
			mode <= LOAD;
		end else if (SW_E) begin
			mode <= EXEC;
		end

		if (mode==LOAD) begin
			if (receiver_valid) inst_mem[pc][pc_sub*8+:8] <= receiver_data;
		end

		if (mode==EXEC) begin
			case (inst[31:26])
				OP_SPECIAL:
					case (inst[5:0])
						FUNCT_SLL: gpr[inst[15:11]] <= gpr[inst[20:16]] << inst[10:6];
						FUNCT_SRL: gpr[inst[15:11]] <= gpr[inst[20:16]] >> inst[10:6];
					endcase
				OP_FPU:
					case (inst[25:24])
						2'b10: fpr[inst[10:6]] <= fadd_fsub_out;
					endcase
				OP_ADDI: gpr[inst[20:16]] <= gpr[inst[25:21]] + {{16{inst[15]}}, inst[15:0]};
				OP_ORI : gpr[inst[20:16]] <= gpr[inst[25:21]] | {16'b0, inst[15:0]};
				OP_LUI : gpr[inst[20:16]] <= {inst[15:0], 16'b0};
				OP_LW  : if (data_read_stall) gpr[inst[20:16]] <= data_mem_out;
				OP_LW_S: if (data_read_stall) fpr[inst[20:16]] <= data_mem_out;
				OP_IN  : if (receiver_valid) gpr[inst[20:16]][7:0] <= receiver_data;
			endcase
			data_read_stall <= (inst[31:26]==OP_LW || inst[31:26]==OP_LW_S) && !data_read_stall;
		end

		case (mode)
			LOAD: begin
				if (SW_E) pc <= 0;
				else if (receiver_valid) {pc, pc_sub} <= {pc, pc_sub} + 1;
			end
			EXEC: begin
				if (SW_W) begin
					pc <= 0;
					pc_sub <= 0;
				end
				else if (inst[31:26]==OP_J) pc <= inst[INST_MEM_WIDTH-1:0];
				else if (!(inst[31:26]==OP_IN && !receiver_valid ||
				           inst[31:26]==OP_OUT && !sender_ready ||
				           (inst[31:26]==OP_LW || inst[31:26]==OP_LW_S) && !data_read_stall)) pc <= pc + 1;
			end
		endcase
	end



	logic[7:0] receiver_data;
	logic receiver_valid;
	logic sender_ready;

	receiver receiver_instance(CLK, UART_RX, receiver_data, receiver_valid);
	sender sender_instance(CLK, gpr[inst[20:16]][7:0], mode==EXEC && inst[31:26]==OP_OUT, UART_TX, sender_ready);
endmodule
