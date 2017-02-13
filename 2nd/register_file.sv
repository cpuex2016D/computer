`include "common.vh"

module register_file #(
	parameter PARENT = "hoge",
	parameter FPR = "hoge"
) (
	input logic clk,
	inst_if inst,
	output cdb_t arch_read[2],
	input logic issue,
	input logic[ROB_WIDTH-1:0] issue_tag,
	input logic commit,
	input logic[REG_WIDTH-1:0] commit_arch_num,
	input logic[ROB_WIDTH-1:0] commit_tag,
	input logic[31:0] commit_data,
	input logic reset,
	req_if acc_req[N_CORE*N_ACC],
	input logic[31:0] acc_data[N_CORE][N_ACC],
	output logic acc_all_valid_parallel,
	output logic no_acc_req,
	input logic issue_fork,
	inout logic[31:0] arch_broadcast[2**REG_WIDTH-FPR*N_ACC]
);
	localparam LATENCY_FADD = 6;
	localparam cdb_t init_default = '{
		valid: 1,
		tag: {ROB_WIDTH{1'bx}},
		data: 0
	};
	localparam cdb_t init_sp = '{
		valid: 1,
		tag: {ROB_WIDTH{1'bx}},
		data: REG_SP_INIT
	};
	localparam cdb_t init_hp = '{
		valid: 1,
		tag: {ROB_WIDTH{1'bx}},
		data: REG_HP_INIT
	};
	cdb_t registers[2**REG_WIDTH-(!PARENT&&FPR)*N_ACC] = '{REG_SP: (FPR ? init_default : init_sp), REG_HP: (FPR ? init_default : init_hp), default: init_default};
	logic[$clog2(LATENCY_FADD):0] fadd_count[N_ACC] = '{default: 0};
	logic[31:0] fadd_result[N_ACC];

	assign arch_read[0] = registers[inst.r1];
	assign arch_read[1] = registers[inst.r2];

	for (genvar i=0; i<2**REG_WIDTH-(!PARENT&&FPR)*N_ACC; i++) begin
		always_ff @(posedge clk) begin
			if (reset) begin
				registers[i].valid <= 1;
			end else if (issue && i==inst.r0) begin
				registers[i].valid <= 0;
			end else if (commit && /* !registers[i].valid && */ registers[i].tag==commit_tag) begin
				registers[i].valid <= 1;
			end

			if (issue && i==inst.r0) begin
				registers[i].tag <= issue_tag;
			end

			if (!PARENT && issue_fork) begin
				registers[i].data <= arch_broadcast[i];
			end else if (FPR && i>=2**REG_WIDTH-N_ACC && fadd_count[i-(2**REG_WIDTH-N_ACC)][0]) begin
				registers[i].data <= fadd_result[i-(2**REG_WIDTH-N_ACC)];
			end else if (commit && !registers[i].valid && i==commit_arch_num) begin
				registers[i].data <= commit_data;
			end
		end
	end

	generate
		if (PARENT) begin
			for (genvar i=0; i<2**REG_WIDTH-FPR*N_ACC; i++) begin
				assign arch_broadcast[i] = registers[i].data;
			end
		end
		if (PARENT && FPR) begin
			assign acc_all_valid_parallel = fadd_count[0]<=1 && fadd_count[1]<=1 && fadd_count[2]<=1;
			assign no_acc_req = !acc_req[0].valid && !acc_req[ 1].valid && !acc_req[ 2].valid &&
			                    !acc_req[3].valid && !acc_req[ 4].valid && !acc_req[ 5].valid &&
			                    !acc_req[6].valid && !acc_req[ 7].valid && !acc_req[ 8].valid &&
			                    !acc_req[9].valid && !acc_req[10].valid && !acc_req[11].valid;
			for (genvar i=0; i<N_ACC; i++) begin
				assign acc_req[0*N_ACC+i].ready = fadd_count[i]<=1;
				assign acc_req[1*N_ACC+i].ready = fadd_count[i]<=1 && !acc_req[0*N_ACC+i].valid;
				assign acc_req[2*N_ACC+i].ready = fadd_count[i]<=1 && !acc_req[0*N_ACC+i].valid && !acc_req[1*N_ACC+i].valid;
				assign acc_req[3*N_ACC+i].ready = fadd_count[i]<=1 && !acc_req[0*N_ACC+i].valid && !acc_req[1*N_ACC+i].valid && !acc_req[2*N_ACC+i].valid;
				wire[1:0] dispatched = acc_req[0*N_ACC+i].valid ? 0 :
				                       acc_req[1*N_ACC+i].valid ? 1 :
				                       acc_req[2*N_ACC+i].valid ? 2 : 3;
				wire dispatch = acc_req[0*N_ACC+i].valid&&acc_req[0*N_ACC+i].ready ||
				                acc_req[1*N_ACC+i].valid&&acc_req[1*N_ACC+i].ready ||
				                acc_req[2*N_ACC+i].valid&&acc_req[2*N_ACC+i].ready ||
				                acc_req[3*N_ACC+i].valid&&acc_req[3*N_ACC+i].ready;
				always_ff @(posedge clk) begin
					fadd_count[i] <= dispatch ? LATENCY_FADD : fadd_count[i]==0 ? 0 : fadd_count[i]-1;
				end
				fadd_core fadd_core(
					.aclk(clk),
					.s_axis_a_tdata(fadd_count[i][0] ? fadd_result[i] : registers[2**REG_WIDTH-N_ACC+i].data),  //バイパス
					.s_axis_b_tdata(acc_data[dispatched][i]),
					.m_axis_result_tdata(fadd_result[i])
				);
			end
		end
	endgenerate
endmodule
