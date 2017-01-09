`include "common.vh"

typedef enum logic[1:0] {
	CMP_FZ,
	CMP_FLE,
	CMP_E,
	CMP_LE
} cmp_type_t;
typedef struct {
	cmp_type_t cmp_type;
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
	input logic[PATTERN_WIDTH-1:0] pattern_in,
	input logic[INST_MEM_WIDTH-1:0] addr_on_failure_in,
	output logic failure,
	output logic[PATTERN_WIDTH-1:0] pattern_out,
	output logic[INST_MEM_WIDTH-1:0] addr_on_failure_out,
	input logic reset
);
	localparam N_ENTRY = 4;
	logic[$clog2(N_ENTRY):0] cmp_count = 0;
	logic[$clog2(N_ENTRY):0] b_count = 0;
	cmp_entry cmp_e[N_ENTRY-1:0];
	cmp_entry cmp_e_updated[N_ENTRY-1:0];
	cmp_entry cmp_e_new;
	b_entry b_e[N_ENTRY-1:0];
	b_entry b_e_moved[N_ENTRY-1:0];
	b_entry b_e_new;

	//cmp
	assign cmp_e_new.cmp_type = inst.op[4] ? inst.op[3] ? CMP_LE : CMP_E
	                                       : inst.op[2] ? CMP_FLE : CMP_FZ;
	cdb_t read[1:0];
	cdb_t cdb;
	assign read = cmp_e_new.cmp_type==CMP_E || cmp_e_new.cmp_type==CMP_LE ? gpr_read : fpr_read;
	assign cdb  = cmp_e_new.cmp_type==CMP_E || cmp_e_new.cmp_type==CMP_LE ? gpr_cdb  : fpr_cdb ;
	assign cmp_e_new.opd[0].valid = (read[0].valid ? tag_match(cdb, cmp_e_new.opd[0].tag) ? 1'bx : 1
	                                               : tag_match(cdb, cmp_e_new.opd[0].tag) ?    1 : 0);
	assign cmp_e_new.opd[0].tag   = read[0].tag;
	assign cmp_e_new.opd[0].data  = (read[0].valid ? tag_match(cdb, cmp_e_new.opd[0].tag) ? 32'bx    : read[0].data
	                                               : tag_match(cdb, cmp_e_new.opd[0].tag) ? cdb.data : 32'bx);
	assign cmp_e_new.opd[1].valid = (cmp_e_new.cmp_type==CMP_E || cmp_e_new.cmp_type==CMP_LE) && inst.op[2] ||
	                                (read[1].valid ? tag_match(cdb, cmp_e_new.opd[1].tag) ? 1'bx : 1
	                                               : tag_match(cdb, cmp_e_new.opd[1].tag) ?    1 : 0);
	assign cmp_e_new.opd[1].tag   = read[1].tag;
	assign cmp_e_new.opd[1].data  = (cmp_e_new.cmp_type==CMP_E || cmp_e_new.cmp_type==CMP_LE) && inst.op[2] ? 32'($signed(inst.c_cmp)) :
	                                (read[1].valid ? tag_match(cdb, cmp_e_new.opd[1].tag) ? 32'bx    : read[1].data
	                                               : tag_match(cdb, cmp_e_new.opd[1].tag) ? cdb.data : 32'bx);
	for (genvar i=0; i<N_ENTRY; i++) begin
		assign cmp_e_updated[i].cmp_type = cmp_e[i].cmp_type;
		cdb_t cdb;
		assign cdb = cmp_e_updated[i].cmp_type==CMP_E || cmp_e_updated[i].cmp_type==CMP_LE ? gpr_cdb : fpr_cdb;
		for (genvar j=0; j<2; j++) begin
			assign cmp_e_updated[i].opd[j].valid = cmp_e[i].opd[j].valid || tag_match(cdb, cmp_e[i].opd[j].tag);
			assign cmp_e_updated[i].opd[j].tag   = cmp_e[i].opd[j].tag;
			assign cmp_e_updated[i].opd[j].data  = cmp_e[i].opd[j].valid ? cmp_e[i].opd[j].data : cdb.data;
		end
	end

	wire dispatch = cmp_count!=0 && cmp_e[0].opd[0].valid && (cmp_e[0].cmp_type==CMP_FZ || cmp_e[0].opd[1].valid);
	wire[$clog2(N_ENTRY)-1:0] dispatch_to = b_count - cmp_count;
	logic fcmple_out;
	fcmple_core fcmple_core(
		.s_axis_a_tdata(cmp_e[0].opd[0].data),
		.s_axis_b_tdata(cmp_e[0].opd[1].data),
		.m_axis_result_tdata(fcmple_out)
	);
	wire cmp_result = cmp_e[0].cmp_type==CMP_E   ? cmp_e[0].opd[0].data == cmp_e[0].opd[1].data :
	                  cmp_e[0].cmp_type==CMP_LE  ? $signed(cmp_e[0].opd[0].data) <= $signed(cmp_e[0].opd[1].data) :
	                  cmp_e[0].cmp_type==CMP_FLE ? fcmple_out :
	                  cmp_e[0].cmp_type==CMP_FZ  ? cmp_e[0].opd[0].data[30:23]==0 : 1'bx;

	always_ff @(posedge clk) begin
		cmp_count <= reset ? 0 : cmp_count - dispatch + issue;
		if (dispatch) begin
			cmp_e[0] <= cmp_count>=2 ? cmp_e_updated[1] : cmp_e_new;
			cmp_e[1] <= cmp_count>=3 ? cmp_e_updated[2] : cmp_e_new;
			cmp_e[2] <= cmp_count>=4 ? cmp_e_updated[3] : cmp_e_new;
			cmp_e[3] <= cmp_e_new;
		end else begin
			cmp_e[0] <= cmp_count>=1 ? cmp_e_updated[0] : cmp_e_new;
			cmp_e[1] <= cmp_count>=2 ? cmp_e_updated[1] : cmp_e_new;
			cmp_e[2] <= cmp_count>=3 ? cmp_e_updated[2] : cmp_e_new;
			cmp_e[3] <= cmp_count>=4 ? cmp_e_updated[3] : cmp_e_new;
		end
	end

	//general
	assign commit_req.ready = cmp_count!=b_count;
	wire commit = commit_req.valid && commit_req.ready;
	assign issue_req.ready = commit || b_count < N_ENTRY;
	wire issue = issue_req.valid && issue_req.ready;

	//b
	assign b_e_new.prediction_or_failure = prediction;
	assign b_e_new.pattern               = pattern_in;
	assign b_e_new.addr_on_failure       = addr_on_failure_in;
	always_comb begin
		if (commit) begin
			b_e_moved[0] <= b_count>=2 ? b_e[1] : b_e_new;
			b_e_moved[1] <= b_count>=3 ? b_e[2] : b_e_new;
			b_e_moved[2] <= b_count>=4 ? b_e[3] : b_e_new;
			b_e_moved[3] <= b_e_new;
		end else begin
			b_e_moved[0] <= b_count>=1 ? b_e[0] : b_e_new;
			b_e_moved[1] <= b_count>=2 ? b_e[1] : b_e_new;
			b_e_moved[2] <= b_count>=3 ? b_e[2] : b_e_new;
			b_e_moved[3] <= b_count>=4 ? b_e[3] : b_e_new;
		end
	end
	always_ff @(posedge clk) begin
		b_count <= reset ? 0 : b_count - commit + issue;
	end
	for (genvar i=0; i<N_ENTRY; i++) begin
		always_ff @(posedge clk) begin
			b_e[i].prediction_or_failure <= b_e_moved[i].prediction_or_failure ^ (dispatch && dispatch_to==i && cmp_result);
			b_e[i].pattern               <= b_e_moved[i].pattern;
			b_e[i].addr_on_failure       <= b_e_moved[i].addr_on_failure;
		end
	end

	assign failure             = b_e[0].prediction_or_failure;  //commitまで使われないという仮定で書いている(commit前はinvalidかもしれない)
	assign pattern_out         = b_e[0].pattern;
	assign addr_on_failure_out = b_e[0].addr_on_failure;
endmodule
