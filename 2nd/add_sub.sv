`include "common.vh"

typedef struct {
	logic valid;
	logic[ROB_WIDTH-1:0] tag;
	enum logic {ADD, SUB, X_ADD_SUB=1'bx} add_or_sub;
	logic sl2;
	cdb_t opd[1:0];
} add_sub_entry;



module add_sub #(
) (
	input logic clk,
	unit_if i
);
	localparam N_ENTRY = 2;
	localparam add_sub_entry entry_invalid = '{
		valid: 0,
		tag: {ROB_WIDTH{1'bx}},
		add_or_sub: X_ADD_SUB,
		sl2: 1'bx,
		opd: '{default: '{
			valid: 1'bx,
			tag: {ROB_WIDTH{1'bx}},
			data: 32'bx
		}}
	};
	//add_sub_entry entry[N_ENTRY-1:0] = '{default: entry_invalid};  //この方法だと正しく初期化されない(vivadoのバグ?)
	add_sub_entry entry[N_ENTRY-1:0];  //0から順に詰める
	add_sub_entry entry_updated[N_ENTRY-1:0];
	add_sub_entry entry_new;
	initial begin
		for (int j=0; j<N_ENTRY; j++) begin
			entry[j] <= entry_invalid;
		end
	end

	assign entry_new.valid      = i.inst.op[5:3]==3'b000 && i.inst.op[2:1]!=2'b11;
	assign entry_new.tag        = i.new_tag;
	assign entry_new.add_or_sub = i.inst.op[1] ? SUB : ADD;
	assign entry_new.sl2        = i.inst.op[2];
	assign entry_new.opd[0].valid = i.inst.op[0] ||
	                                (i.read[1].valid ? tag_match(i.cdb, entry_new.opd[0].tag) ? 1'bx : 1
	                                                 : tag_match(i.cdb, entry_new.opd[0].tag) ?    1 : 0);  //オペランドが入れ替わるので注意
	assign entry_new.opd[0].tag   = i.read[1].tag;
	assign entry_new.opd[0].data  = i.inst.op[0] ? 32'($signed(i.inst.c)) :
	                                (i.read[1].valid ? tag_match(i.cdb, entry_new.opd[0].tag) ? 32'bx      : i.read[1].data
	                                                 : tag_match(i.cdb, entry_new.opd[0].tag) ? i.cdb.data : 32'bx);
	assign entry_new.opd[1].valid = (i.read[0].valid ? tag_match(i.cdb, entry_new.opd[1].tag) ? 1'bx : 1
	                                                 : tag_match(i.cdb, entry_new.opd[1].tag) ?    1 : 0);
	assign entry_new.opd[1].tag   = i.read[0].tag;
	assign entry_new.opd[1].data  = (i.read[0].valid ? tag_match(i.cdb, entry_new.opd[1].tag) ? 32'bx      : i.read[0].data
	                                                 : tag_match(i.cdb, entry_new.opd[1].tag) ? i.cdb.data : 32'bx) << (entry_new.sl2 ? 2 : 0);
	for (genvar j=0; j<N_ENTRY; j++) begin
		assign entry_updated[j].valid      = entry[j].valid;
		assign entry_updated[j].tag        = entry[j].tag;
		assign entry_updated[j].add_or_sub = entry[j].add_or_sub;
		assign entry_updated[j].sl2        = entry[j].sl2;
		for (genvar k=0; k<2; k++) begin
			assign entry_updated[j].opd[k].valid = entry[j].opd[k].valid || tag_match(i.cdb, entry[j].opd[k].tag);
			assign entry_updated[j].opd[k].tag   = entry[j].opd[k].tag;
		end
		assign entry_updated[j].opd[0].data = entry[j].opd[0].valid ? entry[j].opd[0].data : i.cdb.data;
		assign entry_updated[j].opd[1].data = entry[j].opd[1].valid ? entry[j].opd[1].data : i.cdb.data << (entry[j].sl2 ? 2 : 0);
	end

	wire dispatched = entry[0].opd[0].valid&&entry[0].opd[1].valid ? 0 : 1;  //dispatchされるエントリの番号
	assign i.req.valid = entry[0].valid&&entry[0].opd[0].valid&&entry[0].opd[1].valid ||
	                     entry[1].valid&&entry[1].opd[0].valid&&entry[1].opd[1].valid;
	wire dispatchable = i.req.valid && i.req.ready;
	assign i.feedback.stall = !dispatchable && entry[N_ENTRY-1].valid;

	always_ff @(posedge clk) begin
		if (dispatchable) begin
			entry[0] <= dispatched==0 ? entry[1].valid ? entry_updated[1] : entry_new : entry_updated[0];
			entry[1] <= entry[1].valid ? entry_new : entry_invalid;
		end else begin
			entry[0] <= entry[0].valid ? entry_updated[0] : entry_new;
			entry[1] <= entry[1].valid ? entry_updated[1] : entry[0].valid ? entry_new : entry_invalid;
		end
		i.result.tag <= entry[dispatched].tag;
		case (entry[dispatched].add_or_sub)
			ADD: i.result.data <= entry[dispatched].opd[0].data + entry[dispatched].opd[1].data;
			SUB: i.result.data <= entry[dispatched].opd[0].data - entry[dispatched].opd[1].data;
		endcase
	end
endmodule
