`include "common.vh"

typedef struct {
	struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		logic[7:0] data;
	} opd;
} out_entry;

module out #(
) (
	input logic clk,
	input cdb_t gpr_read[2],
	input cdb_t gpr_cdb,
	req_if issue_req,
	req_if commit_req,
	input logic sender_ready,
	output logic sender_valid,
	output logic[7:0] sender_in,
	input logic reset
);
	localparam N_ENTRY = 4;
	logic[$clog2(N_ENTRY):0] count = 0;
	out_entry e[N_ENTRY];
	out_entry e_updated[N_ENTRY];
	out_entry e_new;

	assign e_new.opd.valid = gpr_read[0].valid;
	assign e_new.opd.tag   = gpr_read[0].tag;
	assign e_new.opd.data  = gpr_read[0].data[7:0];
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign e_updated[j].opd.valid = e[j].opd.valid || tag_match(gpr_cdb, e[j].opd.tag);
		assign e_updated[j].opd.tag   = e[j].opd.tag;
		assign e_updated[j].opd.data  = e[j].opd.valid ? e[j].opd.data : gpr_cdb.data[7:0];
	end

	assign commit_req.ready = sender_ready;
	wire commit = commit_req.valid && commit_req.ready;
	assign sender_valid = commit_req.valid;
	assign sender_in = e[0].opd.data;
	assign issue_req.ready = commit || count < N_ENTRY;

	always_ff @(posedge clk) begin
		if (commit_req.valid && !e[0].opd.valid) begin
			$display("hoge: out: error!!!!!!!!!!");
		end
		count <= reset ? 0 : count - commit + (issue_req.valid && issue_req.ready);
		if (commit) begin
			e[0] <= count>=2 ? e_updated[1] : e_new;
			e[1] <= count>=3 ? e_updated[2] : e_new;
			e[2] <= count>=4 ? e_updated[3] : e_new;
			e[3] <= e_new;
		end else begin
			e[0] <= count>=1 ? e_updated[0] : e_new;
			e[1] <= count>=2 ? e_updated[1] : e_new;
			e[2] <= count>=3 ? e_updated[2] : e_new;
			e[3] <= count>=4 ? e_updated[3] : e_new;
		end
	end
endmodule
