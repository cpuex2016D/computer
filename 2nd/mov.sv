`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	cdb_t opd;
} mov_entry;

module mov #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t gpr_read[1:0],
	input cdb_t gpr_cdb,
	input logic[ROB_WIDTH-1:0] gpr_issue_tag,
	req_if issue_req,
	req_if gpr_cdb_req,
	output logic[ROB_WIDTH-1:0] tag,
	output logic[31:0] result,
	input logic reset
);
	localparam N_ENTRY = 2;
	localparam mov_entry e_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		opd: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}
	};
	mov_entry e[N_ENTRY-1:0];  //0から順に詰める
	mov_entry e_updated[N_ENTRY-1:0];
	mov_entry e_new;
	for (genvar i=0; i<N_ENTRY; i++) begin
		initial begin
			e[i] <= e_invalid;
		end
	end

	assign e_new.valid     = issue_req.valid;
	assign e_new.tag       = gpr_issue_tag;
	assign e_new.opd.valid = inst.op[0] ||
	                         (gpr_read[0].valid ? tag_match(gpr_cdb, e_new.opd.tag) ? 1'bx : 1
	                                            : tag_match(gpr_cdb, e_new.opd.tag) ?    1 : 0);
	assign e_new.opd.tag   = gpr_read[0].tag;
	assign e_new.opd.data  = inst.op[0] ? 32'($signed(inst.c_mov)) :
	                         (gpr_read[0].valid ? tag_match(gpr_cdb, e_new.opd.tag) ? 32'bx        : gpr_read[0].data
	                                            : tag_match(gpr_cdb, e_new.opd.tag) ? gpr_cdb.data : 32'bx);
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign e_updated[i].valid     = e[i].valid;
		assign e_updated[i].tag       = e[i].tag;
		assign e_updated[i].opd.valid = e[i].opd.valid || tag_match(gpr_cdb, e[i].opd.tag);
		assign e_updated[i].opd.tag   = e[i].opd.tag;
		assign e_updated[i].opd.data  = e[i].opd.valid ? e[i].opd.data : gpr_cdb.data;
	end

	logic dispatchable[2:0];
	assign dispatchable[0] = e_updated[0].valid&&e_updated[0].opd.valid;
	assign dispatchable[1] = e_updated[1].valid&&e_updated[1].opd.valid;
	assign dispatchable[2] = e_new       .valid&&e_new       .opd.valid;
	assign gpr_cdb_req.valid = dispatchable[0] || dispatchable[1] || dispatchable[2];
	assign tag = dispatchable[0] ? e_updated[0].tag :
	             dispatchable[1] ? e_updated[1].tag : e_new.tag;
	wire dispatch = gpr_cdb_req.valid && gpr_cdb_req.ready;
	assign issue_req.ready = dispatch || !e[N_ENTRY-1].valid;

	always_ff @(posedge clk) begin
		if (reset) begin
			e[0] <= e_invalid;
			e[1] <= e_invalid;
		end else begin
			if (dispatch) begin
				e[0] <= dispatchable[0] ? e[1].valid ? e_updated[1] : e_new : e_updated[0];
				e[1] <= e[1].valid&&(dispatchable[0]||dispatchable[1]) ? e_new : e_invalid;
			end else begin
				e[0] <= e[0].valid ? e_updated[0] : e_new;
				e[1] <= e[1].valid ? e_updated[1] : e[0].valid ? e_new : e_invalid;
			end
		end
		result <= dispatchable[0] ? e_updated[0].opd.data :
		          dispatchable[1] ? e_updated[1].opd.data : e_new.opd.data;
	end
endmodule
