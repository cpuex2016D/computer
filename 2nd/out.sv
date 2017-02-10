`include "common.vh"

typedef struct {
	struct {
		logic valid;
		logic[ROB_WIDTH-1:0] tag;
		logic[7:0] data;
	} opd;
	logic[$clog2(N_B_ENTRY):0] b_count;
} out_entry;

module out #(
) (
	input logic clk,
	input cdb_t gpr_read[2],
	input cdb_t gpr_cdb,
	input logic[$clog2(N_B_ENTRY):0] b_count_next,
	input logic b_commit,
	req_if issue_req,
	input logic sender_ready,
	output logic sender_valid,
	output logic[7:0] sender_in,
	input logic failure
);
	localparam N_ENTRY = 4;
	logic[$clog2(N_ENTRY):0] count = 0;
	out_entry e[N_ENTRY];
	out_entry e_updated[N_ENTRY];
	out_entry e_new;

	assign e_new.opd.valid = gpr_read[0].valid;
	assign e_new.opd.tag   = gpr_read[0].tag;
	assign e_new.opd.data  = gpr_read[0].data[7:0];
	assign e_new.b_count   = b_count_next;
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign e_updated[j].opd.valid = e[j].opd.valid || tag_match(gpr_cdb, e[j].opd.tag);
		assign e_updated[j].opd.tag   = e[j].opd.tag;
		assign e_updated[j].opd.data  = e[j].opd.valid ? e[j].opd.data : gpr_cdb.data[7:0];
		assign e_updated[j].b_count   = e[j].b_count==0 ? 0 : e[j].b_count-b_commit;
	end

	assign sender_valid = count!=0 && e[0].b_count==0 && e[0].opd.valid;
	wire commit = sender_valid && sender_ready;
	assign sender_in = e[0].opd.data;
	assign issue_req.ready = commit || count < N_ENTRY;

	always_ff @(posedge clk) begin
		count <= failure ?
		           (count>=1 && e[0].b_count==0 ?
		              count>=2 && e[1].b_count==0 ?
		                count>=3 && e[2].b_count==0 ?
		                  count>=4 && e[3].b_count==0 ?
		                    4 :
		                    3 :
		                  2 :
		                1 :
		              0) - commit :
		           count - commit + (issue_req.valid && issue_req.ready);
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
