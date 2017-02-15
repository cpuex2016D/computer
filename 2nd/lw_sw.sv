`include "common.vh"

typedef enum logic {LW, SW, X_LW_SW=1'bx} lw_or_sw_t;
typedef enum logic {GPR, FPR} gpr_or_fpr_t;
typedef struct {
	logic valid;
	lw_or_sw_t lw_or_sw;
	logic[1:0] pointer;
	struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		logic[DATA_MEM_WIDTH-1:0] data;
	} opd;
} agu_entry;
typedef struct {
	gpr_or_fpr_t gpr_or_fpr;
	logic[ROB_WIDTH-1:0] tag;
	logic addr_valid;  //なくせる?
	logic[DATA_MEM_WIDTH-1:0] addr;
	logic[2:0] pointer;
} lw_entry;
typedef struct {
	logic addr_valid;  //なくせる?
	logic[DATA_MEM_WIDTH-1:0] addr;
	gpr_or_fpr_t gpr_or_fpr;
	cdb_t sw_data;
	logic[$clog2(N_B_ENTRY):0] b_count;
} sw_entry;

module lw_sw #(
	parameter PARENT = "hoge"
) (
	input logic clk,
	inst_if inst,
	input cdb_t gpr_read[2],
	input cdb_t fpr_read[2],
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	input logic[ROB_WIDTH-1:0] fpr_issue_tag,
	input cdb_t gpr_cdb,
	input cdb_t fpr_cdb,
	input logic[$clog2(N_B_ENTRY):0] b_count_next,
	input logic b_commit,
	req_if issue_req,
	req_if gpr_cdb_req,
	req_if fpr_cdb_req,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic failure,
	input logic reset,
	input logic parallel,
	inout cdb_t sw_broadcast,  //tagは使わない
	output logic sw_empty
);
	localparam N_AGU_ENTRY = 2;
	localparam N_LW_ENTRY = 2;
	localparam N_SW_ENTRY = 4;
	localparam agu_entry agu_e_invalid = '{
		valid: 0,
		lw_or_sw: X_LW_SW,
		pointer: 2'bx,
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: {DATA_MEM_WIDTH{1'bx}}
		}
	};
	logic[1:0] lw_count = 0;
	logic[2:0] sw_count = 0;
	agu_entry agu_e[N_AGU_ENTRY];  //0から順に詰める
	agu_entry agu_e_updated[N_AGU_ENTRY];
	agu_entry agu_e_new;
	lw_entry lw_e[N_LW_ENTRY];  //0から順に詰める
	lw_entry lw_e_updated[N_LW_ENTRY];
	lw_entry lw_e_new;
	lw_entry lw_e_next[N_LW_ENTRY];
	sw_entry sw_e[N_SW_ENTRY];  //0から順に詰める
	sw_entry sw_e_updated[N_SW_ENTRY];
	sw_entry sw_e_new;
	for (genvar j=0; j<N_AGU_ENTRY; j++) begin
		initial begin
			agu_e[j] <= agu_e_invalid;
		end
	end

	//agu
	assign agu_e_new.valid    = issue_req.valid && inst.op[0]==1'b0;
	assign agu_e_new.lw_or_sw = inst.op[2] ? SW : LW;
	assign agu_e_new.pointer  = agu_e_new.lw_or_sw==LW ? lw_count - lw_dispatch :
	                            agu_e_new.lw_or_sw==SW ? sw_count - sw_commit   : 2'bx;
	assign agu_e_new.opd.valid = gpr_read[0].valid;
	assign agu_e_new.opd.tag   = gpr_read[0].tag;
	assign agu_e_new.opd.data  = gpr_read[0].data[DATA_MEM_WIDTH-1:0];
	for (genvar j=0; j<N_AGU_ENTRY; j++) begin
		assign agu_e_updated[j].valid    = agu_e[j].valid;
		assign agu_e_updated[j].lw_or_sw = agu_e[j].lw_or_sw;
		assign agu_e_updated[j].pointer  = agu_e[j].lw_or_sw==LW ? agu_e[j].pointer - lw_dispatch :
		                                   agu_e[j].lw_or_sw==SW ? agu_e[j].pointer - sw_commit   : 2'bx;
		assign agu_e_updated[j].opd.valid = agu_e[j].opd.valid || tag_match(gpr_cdb, agu_e[j].opd.tag);
		assign agu_e_updated[j].opd.tag   = agu_e[j].opd.tag;
		assign agu_e_updated[j].opd.data  = agu_e[j].opd.valid ? agu_e[j].opd.data : gpr_cdb.data[DATA_MEM_WIDTH-1:0];
	end

	wire agu_dispatched = agu_e[0].opd.valid ? 0 : 1;  //dispatchされるエントリの番号
	wire agu_dispatch = agu_e[0].valid&&agu_e[0].opd.valid ||
	                    agu_e[1].valid&&agu_e[1].opd.valid;
	wire[DATA_MEM_WIDTH-1:0] agu_result = agu_e[agu_dispatched].opd.data + (agu_e[agu_dispatched].lw_or_sw==LW ? lw_e[agu_e[agu_dispatched].pointer].addr :
	                                                                        agu_e[agu_dispatched].lw_or_sw==SW ? sw_e[agu_e[agu_dispatched].pointer].addr :
	                                                                        {DATA_MEM_WIDTH{1'bx}});

	always_ff @(posedge clk) begin
		if (reset) begin
			agu_e[0] <= agu_e_invalid;
			agu_e[1] <= agu_e_invalid;
		end else begin
			if (agu_dispatch) begin
				agu_e[0] <= agu_dispatched==0 ? agu_e[1].valid ? agu_e_updated[1] : agu_e_new : agu_e_updated[0];
				agu_e[1] <= agu_e[1].valid ? agu_e_new : agu_e_invalid;
			end else begin
				agu_e[0] <= agu_e[0].valid ? agu_e_updated[0] : agu_e_new;
				agu_e[1] <= agu_e[1].valid ? agu_e_updated[1] : agu_e[0].valid ? agu_e_new : agu_e_invalid;
			end
		end
	end

	//lw
	assign lw_e_new.gpr_or_fpr = inst.op[1] ? FPR : GPR;
	assign lw_e_new.tag        = inst.op[1] ? fpr_issue_tag : gpr_issue_tag;
	assign lw_e_new.addr_valid = inst.op[0];
	assign lw_e_new.addr       = inst.op[0] ? inst.c_lwi : DATA_MEM_WIDTH'($signed(inst.c_lw));
	assign lw_e_new.pointer    = sw_count - sw_commit;
	for (genvar j=0; j<N_LW_ENTRY; j++) begin
		wire agu_dispatch_to_me = agu_dispatch&&agu_e[agu_dispatched].lw_or_sw==LW&&agu_e[agu_dispatched].pointer==j;
		assign lw_e_updated[j].gpr_or_fpr = lw_e[j].gpr_or_fpr;
		assign lw_e_updated[j].tag        = lw_e[j].tag;
		assign lw_e_updated[j].addr_valid = lw_e[j].addr_valid || agu_dispatch_to_me;
		assign lw_e_updated[j].addr       = agu_dispatch_to_me ? agu_result : lw_e[j].addr;
		assign lw_e_updated[j].pointer    = lw_e[j].pointer==0 ? 0 : lw_e[j].pointer - sw_commit;
	end

	wire lw_e0_valid = lw_count!=0 && lw_e[0].addr_valid;
	wire disambiguatable = lw_e[0].pointer==0 ||
	                       sw_e[0].addr_valid&&sw_e[0].sw_data.valid &&
	                        (lw_e[0].pointer[1:0]==1 ||
	                         sw_e[1].addr_valid&&sw_e[1].sw_data.valid &&
	                          (lw_e[0].pointer[1:0]==2 ||
	                           sw_e[2].addr_valid&&sw_e[2].sw_data.valid &&
	                            (lw_e[0].pointer[1:0]==3 ||
	                             sw_e[3].addr_valid&&sw_e[3].sw_data.valid)));
	assign gpr_cdb_req.valid = lw_e0_valid && disambiguatable && lw_e[0].gpr_or_fpr==GPR;
	assign fpr_cdb_req.valid = lw_e0_valid && disambiguatable && lw_e[0].gpr_or_fpr==FPR;
	assign tag = lw_e[0].tag;
	wire lw_dispatch = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                   fpr_cdb_req.valid && fpr_cdb_req.ready;

	always_comb begin
		if (lw_dispatch) begin
			lw_e_next[0] <= lw_count>=2 ? lw_e_updated[1] : lw_e_new;
			lw_e_next[1] <= lw_e_new;
		end else begin
			lw_e_next[0] <= lw_count>=1 ? lw_e_updated[0] : lw_e_new;
			lw_e_next[1] <= lw_count>=2 ? lw_e_updated[1] : lw_e_new;
		end
	end
	always_ff @(posedge clk) begin
		lw_count <= reset ? 0 : lw_count - lw_dispatch + (issue_req.valid && issue_req.ready && inst.op[2]==0);
		lw_e[0] <= lw_e_next[0];
		lw_e[1] <= lw_e_next[1];
		result <= lw_e[0].pointer>=4 && lw_e[0].addr==sw_e[3].addr ? sw_e[3].sw_data.data :
		          lw_e[0].pointer>=3 && lw_e[0].addr==sw_e[2].addr ? sw_e[2].sw_data.data :
		          lw_e[0].pointer>=2 && lw_e[0].addr==sw_e[1].addr ? sw_e[1].sw_data.data :
		          lw_e[0].pointer>=1 && lw_e[0].addr==sw_e[0].addr ? sw_e[0].sw_data.data : data_mem_out;
	end

	//sw
	assign sw_e_new.addr_valid    = inst.op[0];
	assign sw_e_new.addr          = inst.op[0] ? inst.c_swi : DATA_MEM_WIDTH'($signed(inst.c_sw));
	assign sw_e_new.gpr_or_fpr    = inst.op[1] ? FPR : GPR;
	assign sw_e_new.sw_data.valid = sw_e_new.gpr_or_fpr==GPR ? gpr_read[1].valid :
	                                sw_e_new.gpr_or_fpr==FPR ? fpr_read[1].valid : 1'bx;
	assign sw_e_new.sw_data.tag   = sw_e_new.gpr_or_fpr==GPR ? gpr_read[1].tag :
	                                sw_e_new.gpr_or_fpr==FPR ? fpr_read[1].tag : {ROB_WIDTH{1'bx}};
	assign sw_e_new.sw_data.data  = sw_e_new.gpr_or_fpr==GPR ? gpr_read[1].data :
	                                sw_e_new.gpr_or_fpr==FPR ? fpr_read[1].data : 32'bx;
	assign sw_e_new.b_count       = b_count_next;
	for (genvar j=0; j<N_SW_ENTRY; j++) begin
		wire agu_dispatch_to_me = agu_dispatch&&agu_e[agu_dispatched].lw_or_sw==SW&&agu_e[agu_dispatched].pointer==j;
		cdb_t cdb;
		assign cdb = sw_e[j].gpr_or_fpr==GPR ? gpr_cdb : fpr_cdb;
		assign sw_e_updated[j].addr_valid    = sw_e[j].addr_valid || agu_dispatch_to_me;
		assign sw_e_updated[j].addr          = agu_dispatch_to_me ? agu_result : sw_e[j].addr;
		assign sw_e_updated[j].gpr_or_fpr    = sw_e[j].gpr_or_fpr;
		assign sw_e_updated[j].sw_data.valid = sw_e[j].sw_data.valid || tag_match(cdb, sw_e[j].sw_data.tag);
		assign sw_e_updated[j].sw_data.tag   = sw_e[j].sw_data.tag;
		assign sw_e_updated[j].sw_data.data  = sw_e[j].sw_data.valid ? sw_e[j].sw_data.data : cdb.data;
		assign sw_e_updated[j].b_count       = sw_e[j].b_count==0 ? 0 : sw_e[j].b_count-b_commit;
	end

	wire sw_commit = sw_count!=0 && sw_e[0].b_count==0 && sw_e[0].addr_valid && sw_e[0].sw_data.valid;

	always_ff @(posedge clk) begin
		sw_count <= failure ?
		            (sw_e[0].b_count==0)+(sw_e[1].b_count==0)+(sw_e[2].b_count==0)+(sw_e[3].b_count==0)-sw_commit :
		            sw_count - sw_commit + (issue_req.valid && issue_req.ready && inst.op[2]==1);
		if (sw_commit) begin
			sw_e[0] <= sw_count>=2 ? sw_e_updated[1] : sw_e_new;
			sw_e[1] <= sw_count>=3 ? sw_e_updated[2] : sw_e_new;
			sw_e[2] <= sw_count>=4 ? sw_e_updated[3] : sw_e_new;
			sw_e[3] <= sw_e_new;
		end else begin
			sw_e[0] <= sw_count>=1 ? sw_e_updated[0] : sw_e_new;
			sw_e[1] <= sw_count>=2 ? sw_e_updated[1] : sw_e_new;
			sw_e[2] <= sw_count>=3 ? sw_e_updated[2] : sw_e_new;
			sw_e[3] <= sw_count>=4 ? sw_e_updated[3] : sw_e_new;
		end
	end

	//general
	assign issue_req.ready = (inst.op[0]==1 || agu_dispatch || !agu_e[N_AGU_ENTRY-1].valid) &&
	                         (inst.op[2]==1 || lw_dispatch || lw_count < N_LW_ENTRY) &&
	                         (inst.op[2]==0 || sw_commit || sw_count < N_SW_ENTRY);
	assign sw_empty = sw_count==0;
	logic[31:0] data_mem_out;
	data_mem data_mem(
		.addra(sw_e[0].addr),
		.addrb(lw_e_next[0].addr),
		.clka(clk),
		.clkb(clk),
		.dina(parallel ? sw_e[0].sw_data.data : sw_broadcast.data),
		.doutb(data_mem_out),
		.wea(sw_commit || sw_broadcast.valid)
	);
	generate
		if (PARENT) begin
			assign sw_broadcast.valid = !parallel && sw_commit;
			assign sw_broadcast.data  = sw_e[0].sw_data.data;
		end
	endgenerate
endmodule
