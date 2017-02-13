`include "common.vh"

module top #(
	parameter RECEIVER_PERIOD = 430,
	//300MHz
	//  300000000/115200/2 = 1302.0833333333333
	//  1302 - 10 = 1292
	//200MHz
	//  1292/1.5 = 861.3333333333334
	//180MHz
	//  1292*0.6 = 775.1999999999999
	//150MHz
	//  1292/2 = 646
	//100MHz
	//  1292/3 = 430.6666666666667
	parameter SENDER_PERIOD = 861
	//300MHz
	//  300000000/115200 = 2604.1666666666665
	//  2604 - 20 = 2584
	//200MHz
	//  2584/1.5 = 1722.6666666666667
	//180MHz
	//  2584*0.6 = 1550.3999999999999
	//150MHz
	//  2584/2 = 1292
	//100MHz
	//  2584/3 = 861.3333333333334
) (
	input logic CLK_P,
	input logic CLK_N,
	input logic UART_RX,
	output logic UART_TX,
	output logic[7:0] LED
);
	logic clk;
	//IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));
	clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(clk));

	logic parallel;
	cdb_t sw_broadcast;
	logic issue_fork;
	logic[GC_WIDTH-1:0] fork_gc;
	logic[GD_WIDTH-1:0] fork_gd;
	logic[31:0] gpr_arch_broadcast[2**REG_WIDTH];
	logic[31:0] fpr_arch_broadcast[2**REG_WIDTH-N_ACC];
	logic[GC_WIDTH-1:0] gc;
	logic[GC_WIDTH-1:0] gc_plus[N_CORE+1];
	logic[GC_WIDTH-1:0] gc_assign[N_CORE];
	logic[GD_WIDTH-1:0] gd;
	req_if gc_req[N_CORE]();
	req_if acc_req[N_CORE*N_ACC]();
	logic[31:0] acc_data[N_CORE][N_ACC];
	logic ending[1:N_CORE-1];
	wire all_ending = ending[1]&&ending[2]&&ending[3];



	for (genvar i=0; i<N_CORE; i++) begin
		assign gc_req[i].ready = 1;
	end
	for (genvar i=0; i<N_CORE+1; i++) begin
		assign gc_plus[i] = $signed(gc) + i * $signed(gd);
	end
	assign gc_assign[0] = gc_plus[0];
	assign gc_assign[1] = gc_plus[gc_req[0].valid];
	assign gc_assign[2] = gc_plus[gc_req[0].valid+gc_req[1].valid];
	assign gc_assign[3] = gc_plus[gc_req[0].valid+gc_req[1].valid+gc_req[2].valid];
	always_ff @(posedge clk) begin
		if (issue_fork) begin
			gc <= fork_gc;
			gd <= fork_gd;
		end else begin
			gc <= gc_plus[gc_req[0].valid+gc_req[1].valid+gc_req[2].valid+gc_req[3].valid];
		end
	end

	core #(
		.RECEIVER_PERIOD(RECEIVER_PERIOD),
		.SENDER_PERIOD(SENDER_PERIOD),
		.PARENT(1),
		.CORE_I(0)
	) parent(
		.clk,
		.UART_RX,
		.UART_TX,
		.LED,
		.parallel,
		.sw_broadcast,
		.issue_fork,
		.fork_gc,
		.fork_gd,
		.gpr_arch_broadcast,
		.fpr_arch_broadcast,
		.gc(gc_assign[0]),
		.gc_req(gc_req[0]),
		.acc_req,
		.acc_data,
		.ending(all_ending)
	);
	for (genvar i=1; i<N_CORE; i++) begin
		core #(
			.PARENT(0),
			.CORE_I(i)
		) child(
			.clk,
			.parallel,
			.sw_broadcast,
			.issue_fork,
			.gpr_arch_broadcast,
			.fpr_arch_broadcast,
			.gc(gc_assign[i]),
			.gc_req(gc_req[i]),
			.acc_req,
			.acc_data,
			.ending(ending[i])
		);
	end
endmodule
