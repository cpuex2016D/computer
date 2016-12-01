module top #(
	parameter INST_MEM_WIDTH = 17,
	parameter DATA_MEM_WIDTH = 19
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX,
	input logic SW_W,
	input logic SW_E,
	output logic[7:0] LED
);
	logic CLK;
	//IBUFGDS IBUFGDS_instance(.I(CLK_P), .IB(CLK_N), .O(CLK));
	clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(CLK));
	assign LED[7] = mode==EXEC;
	assign LED[5:0] = {pc[3:0], pc_sub};

	localparam OP_SPECIAL = 6'b000000;
	localparam OP_FPU     = 6'b010001;
	localparam OP_ADDI    = 6'b001000;
	localparam OP_ANDI    = 6'b001100;
	localparam OP_ORI     = 6'b001101;
	localparam OP_SLTI    = 6'b001010;
	localparam OP_BEQ     = 6'b000100;
	localparam OP_BNE     = 6'b000101;
	localparam OP_J       = 6'b000010;
	localparam OP_JAL     = 6'b000011;
	localparam OP_LUI     = 6'b001111;
	localparam OP_LW      = 6'b100011;
	localparam OP_SW      = 6'b101011;
	localparam OP_IN      = 6'b011010;
	localparam OP_OUT     = 6'b011011;
	localparam OP_LW_S    = 6'b110001;
	localparam OP_SW_S    = 6'b111001;
	localparam OP_FTOI    = 6'b111000;
	localparam OP_ITOF    = 6'b110000;

	localparam FUNCT_ADD  = 6'b100000;
	localparam FUNCT_SUB  = 6'b100010;
	localparam FUNCT_AND  = 6'b100100;
	localparam FUNCT_OR   = 6'b100101;
	localparam FUNCT_NOR  = 6'b100111;
	localparam FUNCT_SLL  = 6'b000000;
	localparam FUNCT_SRL  = 6'b000010;
	localparam FUNCT_SLT  = 6'b101010;
	localparam FUNCT_JR   = 6'b001000;
	localparam FUNCT_JALR = 6'b001001;

	localparam FPU_OP_SPECIAL = 2'b10;
	localparam FPU_OP_B       = 2'b01;

	localparam FPU_FUNCT_ADD  = 6'b000000;
	localparam FPU_FUNCT_SUB  = 6'b000001;
	localparam FPU_FUNCT_MUL  = 6'b000010;
	localparam FPU_FUNCT_DIV  = 6'b000011;
	localparam FPU_FUNCT_MOV  = 6'b000110;
	localparam FPU_FUNCT_NEG  = 6'b000111;
	localparam FPU_FUNCT_ABS  = 6'b000101;
	localparam FPU_FUNCT_SQRT = 6'b000100;
	localparam FPU_FUNCT_C_EQ = 6'b110010;
	localparam FPU_FUNCT_C_LT = 6'b111100;
	localparam FPU_FUNCT_C_LE = 6'b111110;

	enum logic {
		LOAD,
		EXEC
	} mode = LOAD;
	logic[DATA_MEM_WIDTH-1:0] data_mem_addr;
	logic[31:0] data_mem_in;
	logic[31:0] data_mem_out;
	logic data_mem_we;
	assign data_mem_addr = $signed(gpr[inst[25:21]]) + $signed(inst[15:0]);
	assign data_mem_in = inst[30] ? fpr[inst[20:16]] : gpr[inst[20:16]];
	assign data_mem_we = mode==EXEC && (inst[31:26]==OP_SW || inst[31:26]==OP_SW_S);
	data_mem data_mem(
		.addra(data_mem_addr),
		.clka(CLK),
		.dina(data_mem_in),
		.douta(data_mem_out),
		.wea(data_mem_we)
	);
	logic[31:0] inst_mem[2**INST_MEM_WIDTH-1:0];
	logic[31:0][31:0] gpr = {{31{32'bx}}, 32'b0};
	logic[31:0][31:0] fpr;
	logic[7:0] fcc;  // floating point condition codes
	logic[INST_MEM_WIDTH-1:0] pc = 0;
	logic[INST_MEM_WIDTH-1:0] pc_plus_1;
	assign pc_plus_1 = pc + 1;
	logic[1:0] pc_sub = 0;  // mode==LOAD の時しか使わない
	logic[31:0] inst;
	assign inst = inst_mem[pc];
	logic latency_1;
	assign latency_1 = inst[31:26]==OP_LW || inst[31:26]==OP_LW_S;
	logic latency_3;
	assign latency_3 = inst[31:26]==OP_FPU && inst[25:24]==FPU_OP_SPECIAL && (inst[5:0]==FPU_FUNCT_DIV || inst[5:0]==FPU_FUNCT_SQRT);
	logic[1:0] stage = 0;

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
	logic[31:0] fmul_out;
	fmul fmul(
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[15:11]]),
		.s_axis_b_tvalid(1'b1),
		.s_axis_b_tdata(fpr[inst[20:16]]),
		.m_axis_result_tdata(fmul_out)
	);
	logic[31:0] fdiv_out;
	fdiv fdiv(
		.aclk(CLK),
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[15:11]]),
		.s_axis_b_tvalid(1'b1),
		.s_axis_b_tdata(fpr[inst[20:16]]),
		.m_axis_result_tdata(fdiv_out)
	);
	logic[31:0] fsqrt_out;
	fsqrt fsqrt(
		.aclk(CLK),
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[20:16]]),
		.m_axis_result_tdata(fsqrt_out)
	);
	logic fcmp_out;
	logic[5:0] fcmp_operation;
	always_comb begin
		case (inst[5:0])
			FPU_FUNCT_C_EQ: fcmp_operation = 6'b010100;
			FPU_FUNCT_C_LT: fcmp_operation = 6'b001100;
			FPU_FUNCT_C_LE: fcmp_operation = 6'b011100;
			default       : fcmp_operation = 6'bxxxxxx;
		endcase
	end
	fcmp fcmp(
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[15:11]]),
		.s_axis_b_tvalid(1'b1),
		.s_axis_b_tdata(fpr[inst[20:16]]),
		.s_axis_operation_tvalid(1'b1),
		.s_axis_operation_tdata(fcmp_operation),
		.m_axis_result_tdata(fcmp_out)
	);
	logic[31:0] ftoi_out;
	ftoi ftoi(
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(fpr[inst[25:21]]),
		.m_axis_result_tdata(ftoi_out)
	);
	logic[31:0] itof_out;
	itof itof(
		.s_axis_a_tvalid(1'b1),
		.s_axis_a_tdata(gpr[inst[25:21]]),
		.m_axis_result_tdata(itof_out)
	);



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
						FUNCT_ADD : gpr[inst[15:11]] <= gpr[inst[25:21]] + gpr[inst[20:16]];
						FUNCT_SUB : gpr[inst[15:11]] <= gpr[inst[25:21]] - gpr[inst[20:16]];
						FUNCT_AND : gpr[inst[15:11]] <= gpr[inst[25:21]] & gpr[inst[20:16]];
						FUNCT_OR  : gpr[inst[15:11]] <= gpr[inst[25:21]] | gpr[inst[20:16]];
						FUNCT_NOR : gpr[inst[15:11]] <= ~(gpr[inst[25:21]] | gpr[inst[20:16]]);
						FUNCT_SLL : gpr[inst[15:11]] <= gpr[inst[20:16]] << inst[10:6];
						FUNCT_SRL : gpr[inst[15:11]] <= gpr[inst[20:16]] >> inst[10:6];
						FUNCT_SLT : gpr[inst[15:11]] <= $signed(gpr[inst[25:21]]) <= $signed(gpr[inst[20:16]]);
						FUNCT_JALR: gpr[31] <= pc_plus_1;
					endcase
				OP_FPU:
					case (inst[25:24])
						FPU_OP_SPECIAL:
							case (inst[5:0])
								FPU_FUNCT_ADD : fpr[inst[10:6]] <= fadd_fsub_out;
								FPU_FUNCT_SUB : fpr[inst[10:6]] <= fadd_fsub_out;
								FPU_FUNCT_MUL : fpr[inst[10:6]] <= fmul_out;
								FPU_FUNCT_DIV : if (stage==3) fpr[inst[10:6]] <= fdiv_out;
								FPU_FUNCT_MOV : fpr[inst[10:6]] <= fpr[inst[20:16]];
								FPU_FUNCT_NEG : fpr[inst[10:6]] <= fpr[inst[20:16]] ^ 32'h80000000;
								FPU_FUNCT_ABS : fpr[inst[10:6]] <= fpr[inst[20:16]] & 32'h7fffffff;
								FPU_FUNCT_SQRT: if (stage==3) fpr[inst[10:6]] <= fsqrt_out;
								FPU_FUNCT_C_EQ: fcc[inst[10:8]] <= fcmp_out;
								FPU_FUNCT_C_LT: fcc[inst[10:8]] <= fcmp_out;
								FPU_FUNCT_C_LE: fcc[inst[10:8]] <= fcmp_out;
							endcase
					endcase
				OP_ADDI: gpr[inst[20:16]] <= gpr[inst[25:21]] + {{16{inst[15]}}, inst[15:0]};
				OP_ANDI: gpr[inst[20:16]] <= gpr[inst[25:21]] & {16'b0, inst[15:0]};
				OP_ORI : gpr[inst[20:16]] <= gpr[inst[25:21]] | {16'b0, inst[15:0]};
				OP_SLTI: gpr[inst[20:16]] <= $signed(gpr[inst[25:21]]) <= $signed(inst[15:0]);
				OP_JAL : gpr[31] <= pc_plus_1;
				OP_LUI : gpr[inst[20:16]] <= {inst[15:0], 16'b0};
				OP_LW  : if (stage[0]) gpr[inst[20:16]] <= data_mem_out;
				OP_LW_S: if (stage[0]) fpr[inst[20:16]] <= data_mem_out;
				OP_IN  : if (receiver_valid) gpr[inst[20:16]][7:0] <= receiver_data;
				OP_FTOI: gpr[inst[20:16]] <= ftoi_out;
				OP_ITOF: fpr[inst[20:16]] <= itof_out;
			endcase
			stage <= latency_3 ? stage + 1 :
			         latency_1 ? stage ^ 2'b01 :
			         0;
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
				else if (inst[31:26]==OP_J || inst[31:26]==OP_JAL) pc <= inst[INST_MEM_WIDTH-1:0];
				else if (inst[31:26]==OP_SPECIAL && (inst[5:0]==FUNCT_JR || inst[5:0]==FUNCT_JALR)) pc <= gpr[inst[25:21]];
				else if (inst[31:26]==OP_BEQ && gpr[inst[25:21]]==gpr[inst[20:16]] ||
				         inst[31:26]==OP_BNE && gpr[inst[25:21]]!=gpr[inst[20:16]] ||
				         inst[31:26]==OP_FPU && inst[25:24]==FPU_OP_B && fcc[inst[20:18]]==inst[16]) pc <= $signed(pc) + $signed(inst[15:0]);
				else if (!(inst[31:26]==OP_IN && !receiver_valid ||
				           inst[31:26]==OP_OUT && !sender_ready ||
				           latency_3 && stage!=3 ||
				           latency_1 && !stage[0])) pc <= pc + 1;
			end
		endcase

		if (mode==EXEC) begin
			if (SW_W) LED[6] <= 0;
			else if (receiver_valid && inst[31:26]!=OP_IN) LED[6] <= 1;
		end
	end



	logic[7:0] receiver_data;
	logic receiver_valid;
	logic sender_ready;

	receiver receiver_instance(CLK, UART_RX, receiver_data, receiver_valid);
	sender sender_instance(CLK, gpr[inst[20:16]][7:0], mode==EXEC && inst[31:26]==OP_OUT, UART_TX, sender_ready);
endmodule
