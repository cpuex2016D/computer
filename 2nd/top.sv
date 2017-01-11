`include "common.vh"

module top #(
	parameter RECEIVER_PERIOD = 775,
	//300MHz
	//  300000000/115200/2 = 1302.0833333333333
	//  1302 - 10 = 1292
	//200MHz
	//  1292/1.5 = 861.3333333333334
	//180MHz
	//  1292*0.6 = 775.1999999999999
	parameter SENDER_PERIOD = 1550
	//300MHz
	//  300000000/115200 = 2604.1666666666665
	//  2604 - 20 = 2584
	//200MHz
	//  2584/1.5 = 1722.6666666666667
	//180MHz
	//  2584*0.6 = 1550.3999999999999
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX,
	input logic SW_W,
	input logic SW_E,
	output logic[7:0] LED
);
	////////////////////
	//clk
	//LED
	//mode
	//IO
	//inst_mem
	//issue
	//read
	//cdb
	//commit
	//unit
	////////////////////

	//clk
	logic clk;
	//IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));
	clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(clk));

	//LED
	assign LED[7] = mode==EXEC;
	assign LED[6:0] = pc;

	//mode
	typedef enum logic {
		LOAD,
		EXEC
	} mode_t;
	mode_t mode = LOAD;
	mode_t next_mode;
	assign next_mode = SW_W ? LOAD : SW_E ? EXEC : mode;
	wire mode_change = next_mode != mode;
	logic mode_changed;
	always_ff @(posedge clk) begin
		mode <= next_mode;
		mode_changed <= mode_change;
	end
	wire exec = mode==EXEC && !mode_changed;  //EXECモードの最初の1クロックは命令フェッチのために待つ

	//IO
	logic[31:0] receiver_out;
	logic receiver_valid;
	logic receiver_ready;
	logic[7:0] sender_in;
	logic sender_valid;
	logic sender_ready;
	receiver_wrapper #(RECEIVER_PERIOD) receiver_wrapper(
		.clk,
		.in(UART_RX),
		.ready(mode==LOAD || receiver_ready),
		.out(receiver_out),
		.valid(receiver_valid),
		.reset,
		.in_count
	);
	sender_wrapper #(SENDER_PERIOD) sender_wrapper(
		.clk,
		.in(sender_in),
		.valid(sender_valid),
		.out(UART_TX),
		.ready(sender_ready)
	);

	//inst_mem
	logic[INST_MEM_WIDTH-1:0] pc;
	inst_if inst();
	wire inst_mem_stall = (mode==LOAD && !receiver_valid) ||
	                      (exec &&
	                        ((inst.is_add_sub || inst.is_lw_sw || inst.is_in || inst.is_out || inst.is_b) && !issue_req_commit_ring.ready ||
	                         issue_req_add_sub.valid && !issue_req_add_sub.ready ||
	                         issue_req_lw_sw.valid   && !issue_req_lw_sw.ready   ||
	                         issue_req_in.valid      && !issue_req_in.ready      ||
	                         issue_req_out.valid     && !issue_req_out.ready     ||
	                         issue_req_jal.valid     && !issue_req_jal.ready     ||
	                         issue_req_b.valid       && !issue_req_b.ready));
	inst_mem inst_mem(
		.clk,
		.inst_in(receiver_out),
		.we(mode==LOAD && receiver_valid),
		.reset_pc(mode_change),
		.stall(inst_mem_stall),
		.pc,
		.inst,
		.prediction,
		.reset,
		.addr_on_failure(addr_on_failure_out),
		.return_addr
	);
	wire prediction = 1;
	wire[INST_MEM_WIDTH-1:0] addr_on_failure_in = prediction ? pc : inst.c_j;
	logic[INST_MEM_WIDTH-1:0] addr_on_failure_out;
	logic failure;
	logic[INST_MEM_WIDTH-1:0] return_addr;

	//issue
	req_if issue_req_commit_ring();
	req_if issue_req_add_sub();
	req_if issue_req_lw_sw();
	req_if issue_req_in();
	req_if issue_req_out();
	req_if issue_req_jal();
	req_if issue_req_b();
	logic[ROB_WIDTH-1:0] gpr_issue_tag;
	logic[ROB_WIDTH-1:0] fpr_issue_tag;
	assign issue_req_add_sub.valid = exec && issue_req_commit_ring.ready && inst.is_add_sub;
	assign issue_req_lw_sw.valid   = exec && issue_req_commit_ring.ready && inst.is_lw_sw;
	assign issue_req_in.valid      = exec && issue_req_commit_ring.ready && inst.is_in;
	assign issue_req_out.valid     = exec && issue_req_commit_ring.ready && inst.is_out;
	assign issue_req_jal.valid     = exec && inst.is_jal;
	assign issue_req_b.valid       = exec && issue_req_commit_ring.ready && inst.is_b;
	commit_ring_entry issue_type;
	assign issue_type = inst.is_add_sub ? COMMIT_GPR :
	                    inst.is_lw_sw ? inst.op[2] ? COMMIT_SW : inst.op[1] ? COMMIT_FPR : COMMIT_GPR :
	                    inst.is_in ? COMMIT_GPR_IN :
	                    inst.is_out ? COMMIT_OUT :
	                    inst.is_b ? COMMIT_B : COMMIT_X;
	assign issue_req_commit_ring.valid = issue_req_add_sub.valid && issue_req_add_sub.ready ||
	                                     issue_req_lw_sw.valid   && issue_req_lw_sw.ready   ||
	                                     issue_req_in.valid      && issue_req_in.ready      ||
	                                     issue_req_out.valid     && issue_req_out.ready     ||
	                                     issue_req_b.valid       && issue_req_b.ready;
	wire issue_gpr = issue_req_add_sub.valid && issue_req_add_sub.ready ||
	                 issue_req_lw_sw.valid && issue_req_lw_sw.ready && inst.op[2:1]==2'b00 ||
	                 issue_req_in.valid && issue_req_in.ready;
	wire issue_fpr = issue_req_lw_sw.valid && issue_req_lw_sw.ready && inst.op[2:1]==2'b01;
	//read
	cdb_t     gpr_arch_read[1:0];
	rob_entry gpr_rob_read[1:0];
	cdb_t     gpr_read[1:0];
	logic[ROB_WIDTH-1:0] gpr_read_tag[1:0];
	for (genvar i=0; i<2; i++) begin
		assign gpr_read_tag[i]   = gpr_arch_read[i].tag;
		assign gpr_read[i].valid = gpr_arch_read[i].valid || gpr_rob_read[i].valid;
		assign gpr_read[i].tag   = gpr_arch_read[i].tag;
		assign gpr_read[i].data  = gpr_arch_read[i].valid ? gpr_arch_read[i].data : gpr_rob_read[i].data;
	end
	cdb_t     fpr_arch_read[1:0];
	rob_entry fpr_rob_read[1:0];
	cdb_t     fpr_read[1:0];
	logic[ROB_WIDTH-1:0] fpr_read_tag[1:0];
	for (genvar i=0; i<2; i++) begin
		assign fpr_read_tag[i]   = fpr_arch_read[i].tag;
		assign fpr_read[i].valid = fpr_arch_read[i].valid || fpr_rob_read[i].valid;
		assign fpr_read[i].tag   = fpr_arch_read[i].tag;
		assign fpr_read[i].data  = fpr_arch_read[i].valid ? fpr_arch_read[i].data : fpr_rob_read[i].data;
	end

	//cdb
	cdb_t result_add_sub;
	cdb_t result_lw;
	cdb_t result_in;
	//gpr_cdb
	req_if gpr_cdb_req_add_sub();
	req_if gpr_cdb_req_lw();
	req_if gpr_cdb_req_in();
	assign gpr_cdb_req_lw.ready = 1;
	assign gpr_cdb_req_add_sub.ready = !gpr_cdb_req_lw.valid;
	assign gpr_cdb_req_in.ready = !gpr_cdb_rsv.valid;
	typedef enum logic {
		GPR_CDB_ADD_SUB,
		GPR_CDB_LW
	} gpr_unit_t;
	struct {
		logic valid;
		gpr_unit_t unit;
	} gpr_cdb_rsv;
	always_ff @(posedge clk) begin
		gpr_cdb_rsv.valid <= reset ? 0 :
		                     gpr_cdb_req_add_sub.valid && gpr_cdb_req_add_sub.ready ||
		                     gpr_cdb_req_lw.valid      && gpr_cdb_req_lw.ready;
		gpr_cdb_rsv.unit <= gpr_cdb_req_lw.valid&&gpr_cdb_req_lw.ready ? GPR_CDB_LW : GPR_CDB_ADD_SUB;
	end
	cdb_t gpr_cdb;
	assign gpr_cdb.valid = gpr_cdb_rsv.valid || gpr_cdb_req_in.valid&&gpr_cdb_req_in.ready;
	assign gpr_cdb.tag   = gpr_cdb_rsv.valid ? gpr_cdb_rsv.unit==GPR_CDB_LW ? result_lw.tag  : result_add_sub.tag  : result_in.tag;
	assign gpr_cdb.data  = gpr_cdb_rsv.valid ? gpr_cdb_rsv.unit==GPR_CDB_LW ? result_lw.data : result_add_sub.data : result_in.data;
	//fpr_cdb
	req_if fpr_cdb_req_lw();
	assign fpr_cdb_req_lw.ready = 1;
	struct {
		logic valid;
	} fpr_cdb_rsv;
	always_ff @(posedge clk) begin
		fpr_cdb_rsv.valid <= reset ? 0 : fpr_cdb_req_lw.valid;
	end
	cdb_t fpr_cdb;
	assign fpr_cdb.valid = fpr_cdb_rsv.valid;
	assign fpr_cdb.tag   = result_lw.tag;
	assign fpr_cdb.data  = result_lw.data;

	//commit
	req_if commit_req_gpr();
	req_if commit_req_fpr();
	req_if commit_req_sw();
	req_if commit_req_out();
	req_if commit_req_b();
	logic[ROB_WIDTH-1:0] gpr_commit_tag;
	logic[ROB_WIDTH-1:0] fpr_commit_tag;
	logic[31:0] gpr_commit_data;
	logic[31:0] fpr_commit_data;
	commit_ring commit_ring(
		.clk,
		.issue_type,
		.issue_req(issue_req_commit_ring),
		.commit_req_gpr,
		.commit_req_fpr,
		.commit_req_sw,
		.commit_req_out,
		.commit_req_b,
		.reset,
		.in_count
	);
	wire reset = commit_req_b.valid && commit_req_b.ready && failure;
	logic[COMMIT_RING_WIDTH-1:0] in_count;



	//unit
	register_file gpr_arch(
		.clk,
		.inst,
		.read(gpr_arch_read),
		.issue(issue_gpr),
		.issue_tag(gpr_issue_tag),
		.commit(commit_req_gpr.valid && commit_req_gpr.ready),
		.commit_tag(gpr_commit_tag),
		.commit_data(gpr_commit_data)
	);
	register_file fpr_arch(
		.clk,
		.inst,
		.read(fpr_arch_read),
		.issue(issue_fpr),
		.issue_tag(fpr_issue_tag),
		.commit(commit_req_fpr.valid && commit_req_fpr.ready),
		.commit_tag(fpr_commit_tag),
		.commit_data(fpr_commit_data)
	);
	rob gpr_rob(
		.clk,
		.read_tag(gpr_read_tag),
		.read(gpr_rob_read),
		.cdb(gpr_cdb),
		.issue(issue_gpr),
		.issue_tag(gpr_issue_tag),
		.commit_req(commit_req_gpr),
		.commit_tag(gpr_commit_tag),
		.commit_data(gpr_commit_data),
		.reset
	);
	rob fpr_rob(
		.clk,
		.read_tag(fpr_read_tag),
		.read(fpr_rob_read),
		.cdb(fpr_cdb),
		.issue(issue_fpr),
		.issue_tag(fpr_issue_tag),
		.commit_req(commit_req_fpr),
		.commit_tag(fpr_commit_tag),
		.commit_data(fpr_commit_data),
		.reset
	);
	add_sub add_sub(
		.clk,
		.inst,
		.gpr_read,
		.gpr_cdb,
		.gpr_issue_tag,
		.issue_req(issue_req_add_sub),
		.gpr_cdb_req(gpr_cdb_req_add_sub),
		.result(result_add_sub),
		.reset
	);
	lw_sw lw_sw(
		.clk,
		.inst,
		.gpr_read,
		.fpr_read,
		.gpr_issue_tag,
		.fpr_issue_tag,
		.gpr_cdb,
		.fpr_cdb,
		.issue_req(issue_req_lw_sw),
		.gpr_cdb_req(gpr_cdb_req_lw),
		.fpr_cdb_req(fpr_cdb_req_lw),
		.commit_req(commit_req_sw),
		.result(result_lw),
		.reset
	);
	in in(
		.clk,
		.gpr_issue_tag,
		.issue_req(issue_req_in),
		.gpr_cdb_req(gpr_cdb_req_in),
		.result(result_in),
		.receiver_out,
		.receiver_valid,
		.receiver_ready
	);
	out out(
		.clk,
		.gpr_read,
		.gpr_cdb,
		.issue_req(issue_req_out),
		.commit_req(commit_req_out),
		.sender_ready,
		.sender_valid,
		.sender_in,
		.reset
	);
	b b(
		.clk,
		.inst,
		.gpr_read,
		.fpr_read,
		.gpr_cdb,
		.fpr_cdb,
		.issue_req_b,
		.issue_req_jal,
		.commit_req(commit_req_b),
		.prediction,
		//.pattern_in,
		.addr_on_failure_in,
		.failure,
		//.patterm_out,
		.addr_on_failure_out,
		.reset,
		.pc,
		.return_addr
	);
endmodule
