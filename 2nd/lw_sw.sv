`include "common.vh"

typedef struct {
	logic valid;
	enum logic {LW, SW, X_LW_SW=1'bx} lw_or_sw;
	logic[1:0] pointer;
	struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		logic[DATA_MEM_WIDTH-1:0] data;
	} opd;
} agu_entry;
typedef struct {
	enum logic {LW_GPR, LW_FPR} gpr_or_fpr;
	logic[ROB_WIDTH-1:0] tag;
	logic addr_valid;  //なくせる?
	logic[DATA_MEM_WIDTH-1:0] addr;
	logic[2:0] pointer;
} lw_entry;
typedef struct {
	logic addr_valid;  //なくせる?
	logic[DATA_MEM_WIDTH-1:0] addr;
	enum logic {SW_GPR, SW_FPR} gpr_or_fpr;
	cdb_t sw_data;
} sw_entry;



module lw_sw #(
) (
	input logic clk,
	inst_if inst,
	cdb_t gpr_read[0:1],
	cdb_t fpr_read[0:1],
	logic[ROB_WIDTH-1:0] issue_tag,
	cdb_t gpr_cdb,
	cdb_t fpr_cdb,
	req_if issue_req,
	req_if gpr_cdb_req,
	req_if fpr_cdb_req,
	req_if commit_req,
	cdb_t result
);
	localparam N_AGU_ENTRY = 2;
	localparam N_LW_ENTRY = 2;
	localparam N_SW_ENTRY = 4;
	localparam agu_entry agu_entry_invalid = '{
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
	agu_entry agu_entry[N_AGU_ENTRY-1:0];  //0から順に詰める
	agu_entry agu_entry_updated[N_AGU_ENTRY-1:0];
	agu_entry agu_entry_new;
	lw_entry lw_entry[N_LW_ENTRY-1:0];  //0から順に詰める
	lw_entry lw_entry_updated[N_LW_ENTRY-1:0];
	lw_entry lw_entry_new;
	sw_entry sw_entry[N_SW_ENTRY-1:0];  //0から順に詰める
	sw_entry sw_entry_updated[N_SW_ENTRY-1:0];
	sw_entry sw_entry_new;
	for (genvar j=0; j<N_AGU_ENTRY; j++) begin
		initial begin
			agu_entry[j] <= agu_entry_invalid;
		end
	end

	//agu
	assign agu_entry_new.valid    = issue_req.valid && inst.op[0]==1'b0;
	assign agu_entry_new.lw_or_sw = inst.op[2] ? SW : LW;
	assign agu_entry_new.pointer  = agu_entry_new.lw_or_sw==LW ? lw_count - lw_dispatch :
	                                agu_entry_new.lw_or_sw==SW ? sw_count - sw_commit   : 2'bx;
	assign agu_entry_new.opd.valid = gpr_read[0].valid ? tag_match(gpr_cdb, agu_entry_new.opd.tag) ? 1'bx : 1
	                                                   : tag_match(gpr_cdb, agu_entry_new.opd.tag) ?    1 : 0;
	assign agu_entry_new.opd.tag   = gpr_read[0].tag;
	assign agu_entry_new.opd.data  = gpr_read[0].valid ? tag_match(gpr_cdb, agu_entry_new.opd.tag) ? {DATA_MEM_WIDTH{1'bx}}           : gpr_read[0].data[DATA_MEM_WIDTH-1:0]
	                                                   : tag_match(gpr_cdb, agu_entry_new.opd.tag) ? gpr_cdb.data[DATA_MEM_WIDTH-1:0] : {DATA_MEM_WIDTH{1'bx}};
	for (genvar j=0; j<N_AGU_ENTRY; j++) begin
		assign agu_entry_updated[j].valid    = agu_entry[j].valid;
		assign agu_entry_updated[j].lw_or_sw = agu_entry[j].lw_or_sw;
		assign agu_entry_updated[j].pointer  = agu_entry[j].lw_or_sw==LW ? agu_entry[j].pointer - lw_dispatch :
		                                       agu_entry[j].lw_or_sw==SW ? agu_entry[j].pointer - sw_commit   : 2'bx;
		assign agu_entry_updated[j].opd.valid = agu_entry[j].opd.valid || tag_match(gpr_cdb, agu_entry[j].opd.tag);
		assign agu_entry_updated[j].opd.tag   = agu_entry[j].opd.tag;
		assign agu_entry_updated[j].opd.data  = agu_entry[j].opd.valid ? agu_entry[j].opd.data : gpr_cdb.data[DATA_MEM_WIDTH-1:0];
	end

	wire agu_dispatched = agu_entry[0].opd.valid ? 0 : 1;  //dispatchされるエントリの番号
	wire agu_dispatch = agu_entry[0].valid&&agu_entry[0].opd.valid ||
	                    agu_entry[1].valid&&agu_entry[1].opd.valid;
	wire[DATA_MEM_WIDTH-1:0] agu_result = agu_entry[agu_dispatched].opd.data + (agu_entry[agu_dispatched].lw_or_sw==LW ? lw_entry[agu_entry[agu_dispatched].pointer].addr :
	                                                                            agu_entry[agu_dispatched].lw_or_sw==SW ? sw_entry[agu_entry[agu_dispatched].pointer].addr :
	                                                                            {DATA_MEM_WIDTH{1'bx}});

	always_ff @(posedge clk) begin
		if (agu_dispatch) begin
			agu_entry[0] <= agu_dispatched==0 ? agu_entry[1].valid ? agu_entry_updated[1] : agu_entry_new : agu_entry_updated[0];
			agu_entry[1] <= agu_entry[1].valid ? agu_entry_new : agu_entry_invalid;
		end else begin
			agu_entry[0] <= agu_entry[0].valid ? agu_entry_updated[0] : agu_entry_new;
			agu_entry[1] <= agu_entry[1].valid ? agu_entry_updated[1] : agu_entry[0].valid ? agu_entry_new : agu_entry_invalid;
		end
	end

	//lw
	assign lw_entry_new.gpr_or_fpr = inst.op[1] ? LW_FPR : LW_GPR;
	assign lw_entry_new.tag        = issue_tag;
	assign lw_entry_new.addr_valid = inst.op[0];
	assign lw_entry_new.addr       = inst.op[0] ? inst.c_lwi : DATA_MEM_WIDTH'($signed(inst.c_lw));
	assign lw_entry_new.pointer    = sw_count - sw_commit;
	for (genvar j=0; j<N_LW_ENTRY; j++) begin
		wire agu_dispatch_to_me = agu_dispatch&&agu_entry[agu_dispatched].lw_or_sw==LW&&agu_entry[agu_dispatched].pointer==j;
		assign lw_entry_updated[j].gpr_or_fpr = lw_entry[j].gpr_or_fpr;
		assign lw_entry_updated[j].tag        = lw_entry[j].tag;
		assign lw_entry_updated[j].addr_valid = lw_entry[j].addr_valid || agu_dispatch_to_me;
		assign lw_entry_updated[j].addr       = agu_dispatch_to_me ? agu_result : lw_entry[j].addr;
		assign lw_entry_updated[j].pointer    = lw_entry[j].pointer==0 ? 0 : lw_entry[j].pointer - sw_commit;
	end

	wire lw_entry0_valid = lw_count!=0 && lw_entry[0].addr_valid;
	wire disambiguatable = lw_entry[0].pointer==0 ||
	                       sw_entry[0].addr_valid&&sw_entry[0].sw_data.valid &&
	                        (lw_entry[0].pointer[1:0]==1 ||
	                         sw_entry[1].addr_valid&&sw_entry[1].sw_data.valid &&
	                          (lw_entry[0].pointer[1:0]==2 ||
	                           sw_entry[2].addr_valid&&sw_entry[2].sw_data.valid &&
	                            (lw_entry[0].pointer[1:0]==3 ||
	                             sw_entry[3].addr_valid&&sw_entry[3].sw_data.valid)));
	assign gpr_cdb_req.valid = lw_entry0_valid && disambiguatable && lw_entry[0].gpr_or_fpr==LW_GPR;
	assign fpr_cdb_req.valid = lw_entry0_valid && disambiguatable && lw_entry[0].gpr_or_fpr==LW_FPR;
	wire lw_dispatch = gpr_cdb_req.valid && gpr_cdb_req.ready ||
	                   fpr_cdb_req.valid && fpr_cdb_req.ready;

	always_ff @(posedge clk) begin
		lw_count <= lw_count - lw_dispatch + (issue_req.valid && issue_req.ready && inst.op[2]==0);
		if (lw_dispatch) begin
			lw_entry[0] <= lw_count>=2 ? lw_entry_updated[0] : lw_entry_new;
			lw_entry[1] <= lw_entry_new;
		end else begin
			lw_entry[0] <= lw_count>=1 ? lw_entry_updated[0] : lw_entry_new;
			lw_entry[1] <= lw_count>=2 ? lw_entry_updated[1] : lw_entry_new;
		end
		result.tag <= lw_entry[0].tag;
		result.data <= lw_entry[0].pointer>=1 && lw_entry[0].addr==sw_entry[0].addr ? sw_entry[0].sw_data.data :
		               lw_entry[0].pointer>=2 && lw_entry[0].addr==sw_entry[1].addr ? sw_entry[1].sw_data.data :
		               lw_entry[0].pointer>=3 && lw_entry[0].addr==sw_entry[2].addr ? sw_entry[2].sw_data.data :
		               lw_entry[0].pointer>=4 && lw_entry[0].addr==sw_entry[3].addr ? sw_entry[3].sw_data.data : data_mem_out;
	end

	//sw
	assign sw_entry_new.addr_valid    = inst.op[0];
	assign sw_entry_new.addr          = inst.op[0] ? inst.c_swi : DATA_MEM_WIDTH'($signed(inst.c_sw));
	assign sw_entry_new.gpr_or_fpr    = inst.op[1] ? SW_FPR : SW_GPR;
	assign sw_entry_new.sw_data.valid = sw_entry_new.gpr_or_fpr==SW_GPR ? gpr_read[1].valid ? tag_match(gpr_cdb, sw_entry_new.sw_data.tag) ? 1'bx : 1
	                                                                                        : tag_match(gpr_cdb, sw_entry_new.sw_data.tag) ?    1 : 0 :
	                                    sw_entry_new.gpr_or_fpr==SW_FPR ? fpr_read[1].valid ? tag_match(fpr_cdb, sw_entry_new.sw_data.tag) ? 1'bx : 1
	                                                                                        : tag_match(fpr_cdb, sw_entry_new.sw_data.tag) ?    1 : 0 : 1'bx;
	assign sw_entry_new.sw_data.tag   = sw_entry_new.gpr_or_fpr==SW_GPR ? gpr_read[1].tag :
	                                    sw_entry_new.gpr_or_fpr==SW_FPR ? fpr_read[1].tag : {ROB_WIDTH{1'bx}};
	assign sw_entry_new.sw_data.data  = sw_entry_new.gpr_or_fpr==SW_GPR ? gpr_read[1].valid ? tag_match(gpr_cdb, sw_entry_new.sw_data.tag) ? 32'bx        : gpr_read[1].data
	                                                                                        : tag_match(gpr_cdb, sw_entry_new.sw_data.tag) ? gpr_cdb.data : 32'bx            :
	                                    sw_entry_new.gpr_or_fpr==SW_FPR ? fpr_read[1].valid ? tag_match(fpr_cdb, sw_entry_new.sw_data.tag) ? 32'bx        : fpr_read[1].data
	                                                                                        : tag_match(fpr_cdb, sw_entry_new.sw_data.tag) ? fpr_cdb.data : 32'bx            : 32'bx;
	for (genvar j=0; j<N_SW_ENTRY; j++) begin
		wire agu_dispatch_to_me = agu_dispatch&&agu_entry[agu_dispatched].lw_or_sw==SW&&agu_entry[agu_dispatched].pointer==j;
		cdb_t cdb;
		assign cdb = sw_entry[j].gpr_or_fpr==SW_GPR ? gpr_cdb :
		             sw_entry[j].gpr_or_fpr==SW_FPR ? fpr_cdb :
		             '{
		               valid: 1'bx.
		               tag: {ROB_WIDTH{1'bx}},
		               data: 32'bx
		             };
		assign sw_entry_updated[j].addr_valid    = sw_entry[j].addr_valid || agu_dispatch_to_me;
		assign sw_entry_updated[j].addr          = agu_dispatch_to_me ? agu_result : sw_entry[j];
		assign sw_entry_updated[j].gpr_or_fpr    = sw_entry[j].gpr_or_fpr;
		assign sw_entry_updated[j].sw_data.valid = entry[j].sw_data.valid || tag_match(cdb, entry[j].sw_data.tag);
		assign sw_entry_updated[j].sw_data.tag   = entry[j].sw_data.tag;
		assign sw_entry_updated[j].sw_data.data  = entry[j].sw_data.valid ? entry[j].sw_data.data ? cdb.data;
	end

	assign commit_req.ready = 1;
	wire sw_commit = commit_req.valid && commit_req.ready;

	always_ff @(posedge clk) begin
		if (commit_req.valid && (!sw_entry_updated[j].addr_valid || !sw_entry[j].sw_data.valid)) begin
			$display("hoge: sw: error!!!!!!!!!!");
		end
		sw_count <= sw_count - sw_commit + (issue_req.valid && issue_req.ready && inst.op[2]==1);
		if (sw_commit) begin
			sw_entry[0] <= sw_count>=2 ? sw_entry_updated[0] : sw_entry_new;
			sw_entry[1] <= sw_count>=3 ? sw_entry_updated[1] : sw_entry_new;
			sw_entry[2] <= sw_count>=4 ? sw_entry_updated[2] : sw_entry_new;
			sw_entry[3] <= sw_entry_new;
		end else begin
			sw_entry[0] <= sw_count>=1 ? sw_entry_updated[0] : sw_entry_new;
			sw_entry[1] <= sw_count>=2 ? sw_entry_updated[1] : sw_entry_new;
			sw_entry[2] <= sw_count>=3 ? sw_entry_updated[2] : sw_entry_new;
			sw_entry[3] <= sw_count>=4 ? sw_entry_updated[3] : sw_entry_new;
		end
	end

	//general
	assign issue_req.ready = (inst.op[0]==1 || agu_dispatch || !agu_entry[N_AGU_ENTRY-1].valid) &&
	                         (inst.op[2]==1 || lw_dispatch || lw_count < N_LW_ENTRY) &&
	                         (inst.op[2]==0 || sw_commit || sw_count < N_SW_ENTRY);
	logic[31:0] data_mem_out;
	data_mem data_mem(
		.addra(sw_entry_updated[0].addr),
		.addrb(),
		.clka(clk),
		.dina(sw_entry[0].sw_data.data),
		.doutb(data_mem_out),
		.wea(sw_commit)
	);
endmodule
