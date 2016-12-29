`include "common.vh"

module top #(
	parameter RECEIVER_PERIOD = 1292,
	// 300000000/115200/2 = 1302.0833333333333
	// 1302 - 10 = 1292
	parameter SENDER_PERIOD = 2584
	// 300000000/115200 = 2604.1666666666665
	// 2604 - 20 = 2584
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
	IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));

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
		.valid(receiver_valid)
	);
	sender_wrapper #(SENDER_PERIOD) sender_wrapper(
		.clk,
		.in(sender_in),
		.valid(sender_valid),
		.out(UART_TX),
		.ready(sender_ready)
	);

	//inst_mem
	logic[INST_MEM_WIDTH-1:0] pc = 0;
	inst_if inst();
	wire inst_mem_stall = (mode==LOAD && !receiver_valid) ||
	                      (exec &&
	                        ((inst.is_in || inst.is_out) && !issue_req_commit_ring.ready ||
	                         issue_req_in.valid  && !issue_req_in.ready ||
	                         issue_req_out.valid && !issue_req_out.ready));
	inst_mem inst_mem(
		.clk,
		.inst_in(receiver_out),
		.we(mode==LOAD && receiver_valid),
		.reset_pc(mode_change),
		.stall(inst_mem_stall),
		.pc,
		.inst
	);

	//issue
	req_if issue_req_commit_ring();
	req_if issue_req_in();
	req_if issue_req_out();
	logic[ROB_WIDTH-1:0] issue_tag;
	assign issue_req_in.valid  = exec && issue_req_commit_ring.ready && inst.is_in;
	assign issue_req_out.valid = exec && issue_req_commit_ring.ready && inst.is_out;
	commit_ring_entry issue_type;
	assign issue_type = inst.is_in ? COMMIT_GPR_IN :
	                    inst.is_out ? COMMIT_OUT : COMMIT_X;
	assign issue_req_commit_ring.valid = issue_req_in.valid && issue_req_in.ready ||
	                                     issue_req_out.valid && issue_req_out.ready;
	wire issue_gpr = issue_req_in.valid && issue_req_in.ready;
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

	//cdb
	req_if cdb_req_in();
	assign cdb_req_in.ready = 1;
	cdb_t result_in;
	cdb_t cdb;
	assign cdb.valid = cdb_req_in.valid;
	assign cdb.tag   = result_in.tag;
	assign cdb.data  = result_in.data;

	//commit
	req_if commit_req_gpr();
	req_if commit_req_out();
	logic[ROB_WIDTH-1:0] commit_tag;
	logic[31:0] commit_data;
	commit_ring commit_ring(
		.clk,
		.issue_type,
		.issue_req(issue_req_commit_ring),
		.commit_req_gpr,
		.commit_req_out
	);



	//unit
	register_file gpr_arch(
		.clk,
		.inst,
		.read(gpr_arch_read),
		.issue(issue_gpr),
		.issue_tag,
		.commit(commit_req_gpr.valid && commit_req_gpr.ready),
		.commit_tag,
		.commit_data
	);
	rob gpr_rob(
		.clk,
		.read_tag(gpr_read_tag),
		.read(gpr_rob_read),
		.cdb,
		.issue(issue_gpr),
		.issue_tag,
		.commit_req(commit_req_gpr),
		.commit_tag,
		.commit_data
	);
	in in(
		.clk,
		.issue_tag,
		.issue_req(issue_req_in),
		.cdb_req(cdb_req_in),
		.result(result_in),
		.receiver_out,
		.receiver_valid,
		.receiver_ready
	);
	out out(
		.clk,
		.gpr_read,
		.cdb,
		.issue_req(issue_req_out),
		.commit_req(commit_req_out),
		.sender_ready,
		.sender_valid,
		.sender_in
	);
endmodule
