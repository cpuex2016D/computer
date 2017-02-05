`include "common.vh"

module core #(
	parameter RECEIVER_PERIOD = "hoge",
	parameter SENDER_PERIOD = "hoge"
) (
	input logic clk,
	input logic UART_RX,
	output logic UART_TX,
	input logic SW_W,
	input logic SW_E,
	output logic[7:0] LED
);
	////////////////////
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

	//LED

	//mode
	logic sw_w = 0;
	logic sw_e = 0;
	mode_t mode = LOAD;
	mode_t next_mode;
	logic mode_change;
	logic exec = 0;

	//IO
	logic[31:0] receiver_out;
	logic receiver_valid;
	logic receiver_ready;
	logic[7:0] sender_in;
	logic sender_valid;
	logic sender_ready;

	//inst_mem
	logic[INST_MEM_WIDTH-1:0] pc;
	inst_if inst();
	logic inst_mem_stall;
	logic[PATTERN_WIDTH-1:0] pattern_begin;
	logic[PATTERN_WIDTH-1:0] pattern_end;
	logic[1:0] prediction_begin;
	logic[1:0] prediction_end;
	logic[INST_MEM_WIDTH-1:0] addr_on_failure_in;
	logic[INST_MEM_WIDTH-1:0] addr_on_failure_out;
	logic failure;
	logic[INST_MEM_WIDTH-1:0] return_addr;

	//issue
	req_if issue_req_commit_ring();
	req_if issue_req_add_sub();
	req_if issue_req_mov();
	req_if issue_req_fadd_fsub();
	req_if issue_req_fmul();
	req_if issue_req_fdiv_fsqrt();
	req_if issue_req_fmov();
	req_if issue_req_lw_sw();
	req_if issue_req_ftoi();
	req_if issue_req_itof();
	req_if issue_req_in();
	req_if issue_req_out();
	req_if issue_req_acc[N_ACC-1:0]();
	req_if issue_req_jal();
	req_if issue_req_b();
	logic[ROB_WIDTH-1:0] gpr_issue_tag;
	logic[ROB_WIDTH-1:0] fpr_issue_tag;
	commit_ring_entry issue_type;
	logic issue_gpr;
	logic issue_fpr;
	//read
	cdb_t     gpr_arch_read[1:0];
	rob_entry gpr_rob_read[1:0];
	cdb_t     gpr_read[1:0];
	cdb_t     fpr_arch_read[1:0];
	rob_entry fpr_rob_read[1:0];
	cdb_t     fpr_read[1:0];

	//cdb
	logic[ROB_WIDTH-1:0] tag_add_sub;
	logic[ROB_WIDTH-1:0] tag_mov;
	logic[ROB_WIDTH-1:0] tag_fadd_fsub;
	logic[ROB_WIDTH-1:0] tag_fmul;
	logic[ROB_WIDTH-1:0] tag_fdiv_fsqrt;
	logic[ROB_WIDTH-1:0] tag_fmov;
	logic[ROB_WIDTH-1:0] tag_lw;
	logic[ROB_WIDTH-1:0] tag_ftoi;
	logic[ROB_WIDTH-1:0] tag_itof;
	logic[31:0] result_add_sub;
	logic[31:0] result_mov;
	logic[31:0] result_fadd_fsub;
	logic[31:0] result_fmul;
	logic[31:0] result_fdiv;
	logic[31:0] result_fmov;
	logic[31:0] result_fsqrt;
	logic[31:0] result_lw;
	logic[31:0] result_ftoi;
	logic[31:0] result_itof;
	logic[31:0] result_in;
	//gpr_cdb
	req_if gpr_cdb_req_add_sub();
	req_if gpr_cdb_req_mov();
	req_if gpr_cdb_req_lw();
	req_if gpr_cdb_req_ftoi();
	req_if gpr_cdb_req_in();
	typedef enum logic[1:0] {
		GPR_CDB_ADD_SUB,
		GPR_CDB_MOV,
		GPR_CDB_LW,
		GPR_CDB_FTOI
	} gpr_unit_t;
	typedef struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		gpr_unit_t unit;
	} gpr_cdb_rsv_t;
	gpr_cdb_rsv_t gpr_cdb_rsv[2:0];
	cdb_t gpr_cdb;
	//fpr_cdb
	req_if fpr_cdb_req_fadd_fsub();
	req_if fpr_cdb_req_fmul();
	req_if fpr_cdb_req_fdiv_fsqrt();
	logic  fpr_cdb_req_is_fsqrt;
	req_if fpr_cdb_req_fmov();
	req_if fpr_cdb_req_lw();
	req_if fpr_cdb_req_itof();
	req_if fpr_cdb_req_in();
	typedef enum logic[2:0] {
		FPR_CDB_FDIV,
		FPR_CDB_FSQRT,
		FPR_CDB_FADD_FSUB,
		FPR_CDB_FMUL,
		FPR_CDB_ITOF,
		FPR_CDB_LW,
		FPR_CDB_FMOV = 3'b11x
	} fpr_unit_t;
	typedef struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		fpr_unit_t unit;
	} fpr_cdb_rsv_t;
	fpr_cdb_rsv_t fpr_cdb_rsv[13:0];
	cdb_t fpr_cdb;

	//commit
	req_if commit_req_gpr();
	req_if commit_req_fpr();
	req_if commit_req_sw();
	req_if commit_req_out();
	req_if commit_req_b();
	logic[REG_WIDTH-1:0] gpr_commit_arch_num;
	logic[REG_WIDTH-1:0] fpr_commit_arch_num;
	logic[ROB_WIDTH-1:0] gpr_commit_tag;
	logic[ROB_WIDTH-1:0] fpr_commit_tag;
	logic[31:0] gpr_commit_data;
	logic[31:0] fpr_commit_data;
	logic reset;
	logic[COMMIT_RING_WIDTH-1:0] in_count;

	//unit
	logic[$clog2(N_B_ENTRY):0] b_count_next;
	req_if acc_req[N_ACC-1:0]();
	logic[31:0] acc_data[N_ACC-1:0];



	////////////////////
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

	//LED
	assign LED[7] = mode==EXEC;
	assign LED[6:0] = pc;

	//mode
	assign next_mode = sw_w ? LOAD : sw_e ? EXEC : mode;
	assign mode_change = next_mode != mode;
	always_ff @(posedge clk) begin
		sw_w <= SW_W;
		sw_e <= SW_E;
		mode <= next_mode;
		exec <= mode==EXEC && next_mode==EXEC;  //EXECモードの最初の1クロックは命令フェッチのために待つ
	end

	//IO
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
	assign inst_mem_stall = (mode==LOAD && !receiver_valid) ||
	                        (exec &&
	                          ((inst.is_add_sub    ||
	                            inst.is_mov        ||
	                            inst.is_fadd_fsub  ||
	                            inst.is_fmul       ||
	                            inst.is_fdiv_fsqrt ||
	                            inst.is_fmov       ||
	                            inst.is_lw_sw      ||
	                            inst.is_ftoi       ||
	                            inst.is_itof       ||
	                            inst.is_in         ||
	                            inst.is_out        ||
	                            inst.is_b            ) && !issue_req_commit_ring.ready ||
	                           issue_req_add_sub.valid    && !issue_req_add_sub.ready    ||
	                           issue_req_mov.valid        && !issue_req_mov.ready        ||
	                           issue_req_fadd_fsub.valid  && !issue_req_fadd_fsub.ready  ||
	                           issue_req_fmul.valid       && !issue_req_fmul.ready       ||
	                           issue_req_fdiv_fsqrt.valid && !issue_req_fdiv_fsqrt.ready ||
	                           issue_req_fmov.valid       && !issue_req_fmov.ready       ||
	                           issue_req_lw_sw.valid      && !issue_req_lw_sw.ready      ||
	                           issue_req_ftoi.valid       && !issue_req_ftoi.ready       ||
	                           issue_req_itof.valid       && !issue_req_itof.ready       ||
	                           issue_req_in.valid         && !issue_req_in.ready         ||
	                           issue_req_out.valid        && !issue_req_out.ready        ||
	                           issue_req_acc[0].valid     && !issue_req_acc[0].ready     ||
	                           issue_req_acc[1].valid     && !issue_req_acc[1].ready     ||
	                           issue_req_acc[2].valid     && !issue_req_acc[2].ready     ||
	                           issue_req_jal.valid        && !issue_req_jal.ready        ||
	                           issue_req_b.valid          && !issue_req_b.ready));
	assign addr_on_failure_in = prediction_begin[1] ? pc : inst.c_j;
	inst_mem inst_mem(
		.clk,
		.inst_in(receiver_out),
		.we(mode==LOAD && receiver_valid),
		.reset_pc(mode_change),
		.stall(inst_mem_stall),
		.mode,
		.pc,
		.inst,
		.pattern_begin,
		.pattern_end,
		.prediction_begin,
		.prediction_end,
		.failure,
		.commit_b(commit_req_b.valid && commit_req_b.ready),
		.reset,
		.addr_on_failure(addr_on_failure_out),
		.return_addr
	);

	//issue
	assign issue_req_add_sub.valid    = exec && issue_req_commit_ring.ready && inst.is_add_sub;
	assign issue_req_mov.valid        = exec && issue_req_commit_ring.ready && inst.is_mov;
	assign issue_req_fadd_fsub.valid  = exec && issue_req_commit_ring.ready && inst.is_fadd_fsub;
	assign issue_req_fmul.valid       = exec && issue_req_commit_ring.ready && inst.is_fmul;
	assign issue_req_fdiv_fsqrt.valid = exec && issue_req_commit_ring.ready && inst.is_fdiv_fsqrt;
	assign issue_req_fmov.valid       = exec && issue_req_commit_ring.ready && inst.is_fmov;
	assign issue_req_lw_sw.valid      = exec && issue_req_commit_ring.ready && inst.is_lw_sw;
	assign issue_req_ftoi.valid       = exec && issue_req_commit_ring.ready && inst.is_ftoi;
	assign issue_req_itof.valid       = exec && issue_req_commit_ring.ready && inst.is_itof;
	assign issue_req_in.valid         = exec && issue_req_commit_ring.ready && inst.is_in;
	assign issue_req_out.valid        = exec && issue_req_commit_ring.ready && inst.is_out;
	for (genvar i=0; i<N_ACC; i++) begin
		assign issue_req_acc[i].valid   = exec && inst.is_acc && inst.r0[i];
	end
	assign issue_req_jal.valid        = exec && inst.is_jal;
	assign issue_req_b.valid          = exec && issue_req_commit_ring.ready && inst.is_b;
	assign issue_type = inst.is_add_sub ? COMMIT_GPR :
	                    inst.is_mov ? COMMIT_GPR :
	                    inst.is_fadd_fsub ? COMMIT_FPR :
	                    inst.is_fmul ? COMMIT_FPR :
	                    inst.is_fdiv_fsqrt ? COMMIT_FPR :
	                    inst.is_fmov ? COMMIT_FPR :
	                    inst.is_lw_sw ? inst.op[2] ? COMMIT_SW : inst.op[1] ? COMMIT_FPR : COMMIT_GPR :
	                    inst.is_ftoi ? COMMIT_GPR :
	                    inst.is_itof ? COMMIT_FPR :
	                    inst.is_in ? COMMIT_GPR_IN :
	                    inst.is_out ? COMMIT_OUT :
	                    inst.is_b ? COMMIT_B : COMMIT_X;
	assign issue_req_commit_ring.valid = issue_req_add_sub.valid    && issue_req_add_sub.ready    ||
	                                     issue_req_mov.valid        && issue_req_mov.ready        ||
	                                     issue_req_fadd_fsub.valid  && issue_req_fadd_fsub.ready  ||
	                                     issue_req_fmul.valid       && issue_req_fmul.ready       ||
	                                     issue_req_fdiv_fsqrt.valid && issue_req_fdiv_fsqrt.ready ||
	                                     issue_req_fmov.valid       && issue_req_fmov.ready       ||
	                                     issue_req_lw_sw.valid      && issue_req_lw_sw.ready      ||
	                                     issue_req_ftoi.valid       && issue_req_ftoi.ready       ||
	                                     issue_req_itof.valid       && issue_req_itof.ready       ||
	                                     issue_req_in.valid         && issue_req_in.ready         ||
	                                     issue_req_out.valid        && issue_req_out.ready        ||
	                                     issue_req_b.valid          && issue_req_b.ready;
	assign issue_gpr = issue_req_add_sub.valid    && issue_req_add_sub.ready    ||
	                   issue_req_mov.valid        && issue_req_mov.ready        ||
	                   issue_req_lw_sw.valid      && issue_req_lw_sw.ready      && inst.op[2:1]==2'b00 ||
	                   issue_req_ftoi.valid       && issue_req_ftoi.ready       ||
	                   issue_req_in.valid         && issue_req_in.ready         && inst.op[0]==0;
	assign issue_fpr = issue_req_fadd_fsub.valid  && issue_req_fadd_fsub.ready  ||
	                   issue_req_fmul.valid       && issue_req_fmul.ready       ||
	                   issue_req_fdiv_fsqrt.valid && issue_req_fdiv_fsqrt.ready ||
	                   issue_req_fmov.valid       && issue_req_fmov.ready       ||
	                   issue_req_lw_sw.valid      && issue_req_lw_sw.ready      && inst.op[2:1]==2'b01 ||
	                   issue_req_itof.valid       && issue_req_itof.ready       ||
	                   issue_req_in.valid         && issue_req_in.ready         && inst.op[0]==1;
	//read
	for (genvar i=0; i<2; i++) begin
		assign gpr_read[i].valid = gpr_arch_read[i].valid || gpr_rob_read[i].valid || tag_match(gpr_cdb, gpr_arch_read[i].tag);
		assign gpr_read[i].tag   = gpr_arch_read[i].tag;
		assign gpr_read[i].data  = gpr_arch_read[i].valid ? gpr_arch_read[i].data : tag_match(gpr_cdb, gpr_arch_read[i].tag) ? gpr_cdb.data : gpr_rob_read[i].data;
	end
	for (genvar i=0; i<2; i++) begin
		assign fpr_read[i].valid = fpr_arch_read[i].valid || fpr_rob_read[i].valid || tag_match(fpr_cdb, fpr_arch_read[i].tag);
		assign fpr_read[i].tag   = fpr_arch_read[i].tag;
		assign fpr_read[i].data  = fpr_arch_read[i].valid ? fpr_arch_read[i].data : tag_match(fpr_cdb, fpr_arch_read[i].tag) ? fpr_cdb.data : fpr_rob_read[i].data;
	end

	//cdb
	//gpr_cdb
	assign gpr_cdb_req_ftoi.ready    = 1;
	assign gpr_cdb_req_lw.ready      = !gpr_cdb_rsv[1].valid;
	assign gpr_cdb_req_add_sub.ready = !gpr_cdb_rsv[1].valid && !gpr_cdb_req_lw.valid;
	assign gpr_cdb_req_mov.ready     = !gpr_cdb_rsv[1].valid && !gpr_cdb_req_lw.valid && !gpr_cdb_req_add_sub.valid;
	assign gpr_cdb_req_in.ready      = !gpr_cdb_rsv[0].valid;
	for (genvar i=0; i<3; i++) begin
		initial begin
			gpr_cdb_rsv[i].valid <= 0;
		end
	end
	always_ff @(posedge clk) begin
		gpr_cdb_rsv[2].valid <= reset ? 0 : gpr_cdb_req_ftoi.valid && gpr_cdb_req_ftoi.ready;
		gpr_cdb_rsv[1].valid <= reset ? 0 : gpr_cdb_rsv[2].valid;
		gpr_cdb_rsv[0].valid <= reset ? 0 : gpr_cdb_rsv[1].valid ||
		                        gpr_cdb_req_lw.valid      && gpr_cdb_req_lw.ready      ||
		                        gpr_cdb_req_add_sub.valid && gpr_cdb_req_add_sub.ready ||
		                        gpr_cdb_req_mov.valid     && gpr_cdb_req_mov.ready;
		gpr_cdb_rsv[2].tag <= tag_ftoi;
		gpr_cdb_rsv[1].tag <= gpr_cdb_rsv[2].tag;
		gpr_cdb_rsv[0].tag <= gpr_cdb_rsv[1].valid                                   ? gpr_cdb_rsv[1].tag :
		                      gpr_cdb_req_lw.valid      && gpr_cdb_req_lw.ready      ? tag_lw :
		                      gpr_cdb_req_add_sub.valid && gpr_cdb_req_add_sub.ready ? tag_add_sub : tag_mov;
		gpr_cdb_rsv[0].unit <= gpr_cdb_rsv[1].valid                                   ? GPR_CDB_FTOI :
		                       gpr_cdb_req_lw.valid      && gpr_cdb_req_lw.ready      ? GPR_CDB_LW :
		                       gpr_cdb_req_add_sub.valid && gpr_cdb_req_add_sub.ready ? GPR_CDB_ADD_SUB : GPR_CDB_MOV;
	end
	assign gpr_cdb.valid = gpr_cdb_rsv[0].valid || gpr_cdb_req_in.valid&&gpr_cdb_req_in.ready;
	assign gpr_cdb.tag   = gpr_cdb_rsv[0].valid ? gpr_cdb_rsv[0].tag : gpr_issue_tag;
	assign gpr_cdb.data  = !gpr_cdb_rsv[0].valid ? result_in :
	                       gpr_cdb_rsv[0].unit==GPR_CDB_FTOI    ? result_ftoi    :
	                       gpr_cdb_rsv[0].unit==GPR_CDB_LW      ? result_lw      :
	                       gpr_cdb_rsv[0].unit==GPR_CDB_ADD_SUB ? result_add_sub : result_mov;
	//fpr_cdb
	assign fpr_cdb_req_fdiv_fsqrt.ready = 1;
	assign fpr_cdb_req_fadd_fsub.ready  = !fpr_cdb_rsv[6].valid;
	assign fpr_cdb_req_fmul.ready       = !fpr_cdb_rsv[4].valid;
	assign fpr_cdb_req_itof.ready       = !fpr_cdb_rsv[3].valid;
	assign fpr_cdb_req_lw.ready         = !fpr_cdb_rsv[1].valid;
	assign fpr_cdb_req_fmov.ready       = !fpr_cdb_rsv[1].valid && !fpr_cdb_req_lw.valid;
	assign fpr_cdb_req_in.ready         = !fpr_cdb_rsv[0].valid;
	for (genvar i=0; i<14; i++) begin
		initial begin
			fpr_cdb_rsv[i].valid <= 0;
		end
	end
	always_ff @(posedge clk) begin
		fpr_cdb_rsv[13].valid <= reset ? 0 : fpr_cdb_req_fdiv_fsqrt.valid && fpr_cdb_req_fdiv_fsqrt.ready;
		fpr_cdb_rsv[12].valid <= reset ? 0 : fpr_cdb_rsv[13].valid;
		fpr_cdb_rsv[11].valid <= reset ? 0 : fpr_cdb_rsv[12].valid;
		fpr_cdb_rsv[10].valid <= reset ? 0 : fpr_cdb_rsv[11].valid;
		fpr_cdb_rsv[9].valid <= reset ? 0 : fpr_cdb_rsv[10].valid;
		fpr_cdb_rsv[8].valid <= reset ? 0 : fpr_cdb_rsv[9].valid;
		fpr_cdb_rsv[7].valid <= reset ? 0 : fpr_cdb_rsv[8].valid;
		fpr_cdb_rsv[6].valid <= reset ? 0 : fpr_cdb_rsv[7].valid;
		fpr_cdb_rsv[5].valid <= reset ? 0 : fpr_cdb_rsv[6].valid ||
		                        fpr_cdb_req_fadd_fsub.valid && fpr_cdb_req_fadd_fsub.ready;
		fpr_cdb_rsv[4].valid <= reset ? 0 : fpr_cdb_rsv[5].valid;
		fpr_cdb_rsv[3].valid <= reset ? 0 : fpr_cdb_rsv[4].valid ||
		                        fpr_cdb_req_fmul.valid && fpr_cdb_req_fmul.ready;
		fpr_cdb_rsv[2].valid <= reset ? 0 : fpr_cdb_rsv[3].valid ||
		                        fpr_cdb_req_itof.valid && fpr_cdb_req_itof.ready;
		fpr_cdb_rsv[1].valid <= reset ? 0 : fpr_cdb_rsv[2].valid;
		fpr_cdb_rsv[0].valid <= reset ? 0 : fpr_cdb_rsv[1].valid ||
		                        fpr_cdb_req_lw.valid   && fpr_cdb_req_lw.ready ||
		                        fpr_cdb_req_fmov.valid && fpr_cdb_req_fmov.ready;
		fpr_cdb_rsv[13].tag <= tag_fdiv_fsqrt;
		fpr_cdb_rsv[12].tag <= fpr_cdb_rsv[13].tag;
		fpr_cdb_rsv[11].tag <= fpr_cdb_rsv[12].tag;
		fpr_cdb_rsv[10].tag <= fpr_cdb_rsv[11].tag;
		fpr_cdb_rsv[9].tag <= fpr_cdb_rsv[10].tag;
		fpr_cdb_rsv[8].tag <= fpr_cdb_rsv[9].tag;
		fpr_cdb_rsv[7].tag <= fpr_cdb_rsv[8].tag;
		fpr_cdb_rsv[6].tag <= fpr_cdb_rsv[7].tag;
		fpr_cdb_rsv[5].tag <= fpr_cdb_rsv[6].valid ? fpr_cdb_rsv[6].tag : tag_fadd_fsub;
		fpr_cdb_rsv[4].tag <= fpr_cdb_rsv[5].tag;
		fpr_cdb_rsv[3].tag <= fpr_cdb_rsv[4].valid ? fpr_cdb_rsv[4].tag : tag_fmul;
		fpr_cdb_rsv[2].tag <= fpr_cdb_rsv[3].valid ? fpr_cdb_rsv[3].tag : tag_itof;
		fpr_cdb_rsv[1].tag <= fpr_cdb_rsv[2].tag;
		fpr_cdb_rsv[0].tag <= fpr_cdb_rsv[1].valid                         ? fpr_cdb_rsv[1].tag :
		                      fpr_cdb_req_lw.valid && fpr_cdb_req_lw.ready ? tag_lw : tag_fmov;
		fpr_cdb_rsv[13].unit <= fpr_cdb_req_is_fsqrt ? FPR_CDB_FSQRT : FPR_CDB_FDIV;
		fpr_cdb_rsv[12].unit <= fpr_cdb_rsv[13].unit;
		fpr_cdb_rsv[11].unit <= fpr_cdb_rsv[12].unit;
		fpr_cdb_rsv[10].unit <= fpr_cdb_rsv[11].unit;
		fpr_cdb_rsv[9].unit <= fpr_cdb_rsv[10].unit;
		fpr_cdb_rsv[8].unit <= fpr_cdb_rsv[9].unit;
		fpr_cdb_rsv[7].unit <= fpr_cdb_rsv[8].unit;
		fpr_cdb_rsv[6].unit <= fpr_cdb_rsv[7].unit;
		fpr_cdb_rsv[5].unit <= fpr_cdb_rsv[6].valid ? fpr_cdb_rsv[6].unit : FPR_CDB_FADD_FSUB;
		fpr_cdb_rsv[4].unit <= fpr_cdb_rsv[5].unit;
		fpr_cdb_rsv[3].unit <= fpr_cdb_rsv[4].valid ? fpr_cdb_rsv[4].unit : FPR_CDB_FMUL;
		fpr_cdb_rsv[2].unit <= fpr_cdb_rsv[3].valid ? fpr_cdb_rsv[3].unit : FPR_CDB_ITOF;
		fpr_cdb_rsv[1].unit <= fpr_cdb_rsv[2].unit;
		fpr_cdb_rsv[0].unit <= fpr_cdb_rsv[1].valid                         ? fpr_cdb_rsv[1].unit :
		                       fpr_cdb_req_lw.valid && fpr_cdb_req_lw.ready ? FPR_CDB_LW : FPR_CDB_FMOV;
	end
	assign fpr_cdb.valid = fpr_cdb_rsv[0].valid || fpr_cdb_req_in.valid&&fpr_cdb_req_in.ready;
	assign fpr_cdb.tag   = fpr_cdb_rsv[0].valid ? fpr_cdb_rsv[0].tag : fpr_issue_tag;
	assign fpr_cdb.data  = !fpr_cdb_rsv[0].valid ? result_in :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_FDIV      ? result_fdiv      :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_FSQRT     ? result_fsqrt     :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_FADD_FSUB ? result_fadd_fsub :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_FMUL      ? result_fmul      :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_ITOF      ? result_itof      :
	                       fpr_cdb_rsv[0].unit==FPR_CDB_LW        ? result_lw        : result_fmov;

	//commit
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
	assign reset = commit_req_b.valid && commit_req_b.ready && failure;



	//unit
	register_file #(0) gpr_arch(
		.clk,
		.inst,
		.arch_read(gpr_arch_read),
		.issue(issue_gpr),
		.issue_tag(gpr_issue_tag),
		.commit(commit_req_gpr.valid && commit_req_gpr.ready),
		.commit_arch_num(gpr_commit_arch_num),
		.commit_tag(gpr_commit_tag),
		.commit_data(gpr_commit_data),
		.reset,
		.acc_req  //これがないと合成できない
	);
	register_file #(1) fpr_arch(
		.clk,
		.inst,
		.arch_read(fpr_arch_read),
		.issue(issue_fpr),
		.issue_tag(fpr_issue_tag),
		.commit(commit_req_fpr.valid && commit_req_fpr.ready),
		.commit_arch_num(fpr_commit_arch_num),
		.commit_tag(fpr_commit_tag),
		.commit_data(fpr_commit_data),
		.reset,
		.acc_req,
		.acc_data
	);
	rob gpr_rob(
		.clk,
		.arch_read(gpr_arch_read),
		.rob_read(gpr_rob_read),
		.cdb(gpr_cdb),
		.issue(issue_gpr),
		.inst,
		.issue_tag(gpr_issue_tag),
		.commit_req(commit_req_gpr),
		.commit_arch_num(gpr_commit_arch_num),
		.commit_tag(gpr_commit_tag),
		.commit_data(gpr_commit_data),
		.reset
	);
	rob fpr_rob(
		.clk,
		.arch_read(fpr_arch_read),
		.rob_read(fpr_rob_read),
		.cdb(fpr_cdb),
		.issue(issue_fpr),
		.inst,
		.issue_tag(fpr_issue_tag),
		.commit_req(commit_req_fpr),
		.commit_arch_num(fpr_commit_arch_num),
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
		.tag(tag_add_sub),
		.result(result_add_sub),
		.reset
	);
	mov mov(
		.clk,
		.inst,
		.gpr_read,
		.gpr_cdb,
		.gpr_issue_tag,
		.issue_req(issue_req_mov),
		.gpr_cdb_req(gpr_cdb_req_mov),
		.tag(tag_mov),
		.result(result_mov),
		.reset
	);
	fadd_fsub fadd_fsub(
		.clk,
		.inst,
		.fpr_read,
		.fpr_cdb,
		.fpr_issue_tag,
		.issue_req(issue_req_fadd_fsub),
		.fpr_cdb_req(fpr_cdb_req_fadd_fsub),
		.tag(tag_fadd_fsub),
		.result(result_fadd_fsub),
		.reset
	);
	fmul fmul(
		.clk,
		.inst,
		.fpr_read,
		.fpr_cdb,
		.fpr_issue_tag,
		.issue_req(issue_req_fmul),
		.fpr_cdb_req(fpr_cdb_req_fmul),
		.tag(tag_fmul),
		.result(result_fmul),
		.reset
	);
	fdiv_fsqrt fdiv_fsqrt(
		.clk,
		.inst,
		.fpr_read,
		.fpr_cdb,
		.fpr_issue_tag,
		.issue_req(issue_req_fdiv_fsqrt),
		.fpr_cdb_req(fpr_cdb_req_fdiv_fsqrt),
		.fpr_cdb_req_is_fsqrt,
		.tag(tag_fdiv_fsqrt),
		.result_fdiv,
		.result_fsqrt,
		.reset
	);
	fmov fmov(
		.clk,
		.inst,
		.fpr_read,
		.fpr_cdb,
		.fpr_issue_tag,
		.issue_req(issue_req_fmov),
		.fpr_cdb_req(fpr_cdb_req_fmov),
		.tag(tag_fmov),
		.result(result_fmov),
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
		.tag(tag_lw),
		.result(result_lw),
		.reset
	);
	ftoi ftoi(
		.clk,
		.inst,
		.fpr_read,
		.fpr_cdb,
		.gpr_issue_tag,
		.issue_req(issue_req_ftoi),
		.gpr_cdb_req(gpr_cdb_req_ftoi),
		.tag(tag_ftoi),
		.result(result_ftoi),
		.reset
	);
	itof itof(
		.clk,
		.inst,
		.gpr_read,
		.gpr_cdb,
		.fpr_issue_tag,
		.issue_req(issue_req_itof),
		.fpr_cdb_req(fpr_cdb_req_itof),
		.tag(tag_itof),
		.result(result_itof),
		.reset
	);
	in in(
		.clk,
		.inst,
		.issue_req(issue_req_in),
		.gpr_cdb_req(gpr_cdb_req_in),
		.fpr_cdb_req(fpr_cdb_req_in),
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
	for (genvar i=0; i<N_ACC; i++) begin
		acc acc(
			.clk,
			.fpr_read,
			.fpr_cdb,
			.b_count_next,
			.b_commit(commit_req_b.valid && commit_req_b.ready),
			.issue_req(issue_req_acc[i]),
			.acc_req(acc_req[i]),
			.acc_data(acc_data[i]),
			.failure
		);
	end
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
		.prediction_begin,
		.pattern_begin,
		.addr_on_failure_in,
		.b_count_next,
		.failure,
		.prediction_end,
		.pattern_end,
		.addr_on_failure_out,
		.reset,
		.pc,
		.return_addr
	);
endmodule