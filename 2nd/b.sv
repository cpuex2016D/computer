`include "common.vh"

typedef struct {
	enum logic {
		CMP_FZ,
		CMP_FLE,
		CMP_E,
		CMP_LE
	} cmp_type;
	cdb_t opd[1:0];
} cmp_entry;
typedef struct {
	logic prediction_or_failure;
	logic[PATTERN_WIDTH-1:0] pattern;
	logic[INST_MEM_WIDTH-1:0] addr_on_failure;
} b_entry;

module b #(
) (
	input logic clk,
	inst_if inst,
	input cdb_t gpr_read[1:0],
	input cdb_t fpr_read[1:0],
	input cdb_t gpr_cdb,
	input cdb_t fpr_cdb,
	req_if issue_req,
	req_if commit_req,
	input logic prediction,
	input logic[PATTERN_WIDTH-1:0] pattern,
	input logic[INST_MEM_WIDTH-1:0] addr_on_failure,
	output logic failure
);
	localparam N_ENTRY = 4;
	logic[$clog2(N_ENTRY):0] cmp_count = 0;
	logic[$clog2(N_ENTRY):0] b_count = 0;
	cmp_entry cmp_entry[N_ENTRY-1:0];
	cmp_entry cmp_entry_updated[N_ENTRY-1:0];
	cmp_entry cmp_entry_new;
	b_entry b_entry[N_ENTRY-1:0];
	b_entry b_entry_moved[N_ENTRY-1:0];
	b_entry b_entry_new;

	//cmp
	assign cmp_entry_new.cmp_type = inst.op[4] ? inst.op[3] ? CMP_LE : CMP_E
	                                           : inst.op[2] ? CMP_FLE : CMP_FZ;
	cdb_t read[1:0];
	cdb_t cdb;
	assign read = cmp_entry_new.cmp_type==CMP_E || emp_entry_new.cmp_type==CMP_LE ? gpr_read : fpr_read;
	assign cdb  = cmp_entry_new.cmp_type==CMP_E || emp_entry_new.cmp_type==CMP_LE ? gpr_cdb  : fpr_cdb ;
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign cmp_entry_new.opd[j].valid = (cmp_entry_new.cmp_type==CMP_E || emp_entry_new.cmp_type==CMP_LE) && inst.op[2] ||
		                                    (read[j].valid ? tag_match(cdb, cmp_entry_new.opd[j].tag) ? 1'bx : 1
		                                                   : tag_match(cdb, cmp_entry_new.opd[j].tag) ?    1 : 0);
		assign cmp_entry_new.opd[j].tag   = read[j].tag;
		assign cmp_entry_new.opd[j].data  = (cmp_entry_new.cmp_type==CMP_E || emp_entry_new.cmp_type==CMP_LE) && inst.op[2] ? 32'($signed(inst.c_cmp)) :
		                                    (read[j].valid ? tag_match(cdb, cmp_entry_new.opd[j].tag) ? 32'bx    : read[j].data
		                                                   : tag_match(cdb, cmp_entry_new.opd[j].tag) ? cdb.data : 32'bx);
	end
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign cmp_entry_updated[i].cmp_type = cmp_entry[i].cmp_type;
		cdb_t cdb;
		assign cdb = cmp_entry_updated[i].cmp_type==CMP_E || emp_entry_updated[i].cmp_type==CMP_LE ? gpr_cdb : fpr_cdb;
		for (genvar j=0; j<N_ENTRY; j++) begin
			assign cmp_entry_updated[i].opd[j].valid = cmp_entry[i].opd[j].valid || tag_match(cdb, cmp_entry[i].opd[j].tag);
			assign cmp_entry_updated[i].opd[j].tag   = cmp_entry[i].opd[j].tag;
			assign cmp_entry_updated[i].opd[j].data  = cmp_entry[i].opd[j].valid ? cmp_entry[i].opd[j].data : cdb.data;
		end
	end

	wire dispatch = cmp_count!=0 && cmp_entry[0].opd[0].valid && (cmp_entry[0].cmp_type==CMP_FZ || cmp_entry[0].opd[1].valid);
	wire[$clog2(N_ENTRY)-1:0] dispatch_to = b_count - cmp_count;
	logic fcmple_out;
	//TODO fcmple_core
	wire cmp_result = cmp_entry[0].cmp_type==CMP_E   ? cmp_entry[0].opd[0].data == cmp_entry[0].opd[1].data :
	                  cmp_entry[0].cmp_type==CMP_LE  ? $signed(cmp_entry[0].opd[0].data) <= $signed(cmp_entry[0].opd[1].data) :
	                  cmp_entry[0].cmp_type==CMP_FLE ? fcmple_out :
	                  cmp_entry[0].cmp_type==CMP_FZ  ? cmp_entry[0].opd[0].data[30:23]==0 : 1'bx;

	always_ff @(posedge clk) begin
		cmp_count <= cmp_count - dispatch + issue;
		if (dispatch) begin
			cmp_entry[0] <= cmp_count>=2 ? cmp_entry_updated[1] : cmp_entry_new;
			cmp_entry[1] <= cmp_count>=3 ? cmp_entry_updated[2] : cmp_entry_new;
			cmp_entry[2] <= cmp_count>=4 ? cmp_entry_updated[3] : cmp_entry_new;
			cmp_entry[3] <= cmp_entry_new;
		end else begin
			cmp_entry[0] <= cmp_count>=1 ? cmp_entry_updated[0] : cmp_entry_new;
			cmp_entry[1] <= cmp_count>=2 ? cmp_entry_updated[1] : cmp_entry_new;
			cmp_entry[2] <= cmp_count>=3 ? cmp_entry_updated[2] : cmp_entry_new;
			cmp_entry[3] <= cmp_count>=4 ? cmp_entry_updated[3] : cmp_entry_new;
		end
	end

	//general
	assign commit_req.ready = cmp_count!=b_count;
	wire commit = commit_req.valid && commit_req.ready;
	assign issue_req.ready = commit || b_count < N_ENTRY;
	wire issue = issue_req.valid && issue_req.ready;

	//b
	assign b_entry_new.prediction_or_failure = prediction;
	assign b_entry_new.pattern               = pattern;
	assign b_entry_new.addr_on_failure       = addr_on_failure;
	always_comb begin
		if (commit) begin
			b_entry_moved[0] <= b_count>=2 ? b_entry[1] : b_entry_new;
			b_entry_moved[1] <= b_count>=3 ? b_entry[2] : b_entry_new;
			b_entry_moved[2] <= b_count>=4 ? b_entry[3] : b_entry_new;
			b_entry_moved[3] <= b_entry_new;
		end else begin
			b_entry_moved[0] <= b_count>=1 ? b_entry[0] : b_entry_new;
			b_entry_moved[1] <= b_count>=2 ? b_entry[1] : b_entry_new;
			b_entry_moved[2] <= b_count>=3 ? b_entry[2] : b_entry_new;
			b_entry_moved[3] <= b_count>=4 ? b_entry[3] : b_entry_new;
		end
	end
	always_ff @(posedge clk) begin
		b_count <= b_count - commit + issue;
	end
	for (genvar i=0; i<N_ENTRY; i++) begin
		always_ff @(posedge clk) begin
			b_entry[i].prediction_or_failure <= b_entry_moved[i].prediction_or_failure ^ (dispatch && dispatch_to==i && cmp_result);
			b_entry[i].pattern               <= b_entry_moved[i].pattern;
			b_entry[i].addr_on_failure       <= b_entry_moved[i].addr_on_failure;
		end
	end

	assign failure = b_entry[0].prediction_or_failure;  //commitまで使われないという仮定で書いている(commit前はinvalidかもしれない)
endmodule
