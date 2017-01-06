`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	logic[7:0] data;
} out_entry;

module out #(
) (
	input logic clk,
	input cdb_t gpr_read[1:0],
	input cdb_t cdb,
	req_if issue_req,
	req_if commit_req,
	input logic sender_ready,
	output logic sender_valid,
	output logic[7:0] sender_in,
	input logic reset
);
	localparam N_ENTRY = 4;
	logic[$clog2(N_ENTRY):0] count = 0;
	out_entry entry[N_ENTRY-1:0];
	out_entry entry_updated[N_ENTRY-1:0];
	out_entry entry_new;

	assign entry_new.valid = gpr_read[0].valid ? tag_match(cdb, entry_new.tag) ? 1'bx : 1
	                                           : tag_match(cdb, entry_new.tag) ?    1 : 0;
	assign entry_new.tag   = gpr_read[0].tag;
	assign entry_new.data  = gpr_read[0].valid ? tag_match(cdb, entry_new.tag) ? 8'bx          : gpr_read[0].data[7:0]
	                                           : tag_match(cdb, entry_new.tag) ? cdb.data[7:0] : 8'bx;
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign entry_updated[j].valid = entry[j].valid || tag_match(cdb, entry[j].tag);
		assign entry_updated[j].tag   = entry[j].tag;
		assign entry_updated[j].data  = entry[j].valid ? entry[j].data : cdb.data[7:0];
	end

	assign commit_req.ready = sender_ready;
	wire commit = commit_req.valid && commit_req.ready;
	assign sender_valid = commit_req.valid;
	assign sender_in = entry[0].data[7:0];
	assign issue_req.ready = commit || count < N_ENTRY;

	always_ff @(posedge clk) begin
		if (commit_req.valid && !entry[0].valid) begin
			$display("hoge: out: error!!!!!!!!!!");
		end
		count <= reset ? 0 : count - commit + (issue_req.valid && issue_req.ready);
		if (commit) begin
			entry[0] <= count>=2 ? entry_updated[1] : entry_new;
			entry[1] <= count>=3 ? entry_updated[2] : entry_new;
			entry[2] <= count>=4 ? entry_updated[3] : entry_new;
			entry[3] <= entry_new;
		end else begin
			entry[0] <= count>=1 ? entry_updated[0] : entry_new;
			entry[1] <= count>=2 ? entry_updated[1] : entry_new;
			entry[2] <= count>=3 ? entry_updated[2] : entry_new;
			entry[3] <= count>=4 ? entry_updated[3] : entry_new;
		end
	end
endmodule
