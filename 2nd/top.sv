`include "common.vh"

module top #(
	parameter RECEIVER_PERIOD = 107,
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
	//100MHz 460800baud
	//  1292/3/4 = 107.66666666666667
	parameter SENDER_PERIOD = 215
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
	//100MHz 460800baud
	//  2584/3/4 = 215.33333333333334
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
	logic sw_broadcast;
	logic[DATA_MEM_WIDTH-1:0] sw_broadcast_addr;
	logic[31:0] sw_broadcast_data;
	logic issue_fork;
	logic[GC_WIDTH-1:0] fork_gc;
	logic[GD_WIDTH-1:0] fork_gd;
	logic[31:0] gpr_arch_broadcast[2**REG_WIDTH];
	logic[31:0] fpr_arch_broadcast[2**REG_WIDTH-N_ACC];
	logic[GC_WIDTH-1:0] gc;
	logic[GC_WIDTH-1:0] gc_plus[N_CORE+1];
	logic[GC_WIDTH-1:0] gc_assign[N_CORE];
	logic[GD_WIDTH-1:0] gd;
	logic[31:0] acc_data[N_CORE][N_ACC];
	logic[GC_WIDTH-1:0] gc_stamp[N_CORE][N_ACC];
	logic ending[1:N_CORE-1];
	logic gc_req_valid[N_CORE];
	logic[$clog2(N_CORE):0] gc_req_valid_sum[N_CORE+1];
	logic acc_req_valid[N_CORE][N_ACC];
	logic acc_req_ready[N_CORE][N_ACC];
	wire all_ending = ending[1]&&ending[2]&&ending[3]&&ending[4]&&ending[5];



	for (genvar i=0; i<N_CORE+1; i++) begin
		assign gc_plus[i] = $signed(gc) + i * $signed(gd);
	end
	assign gc_req_valid_sum[0] = 0;
	assign gc_req_valid_sum[1] = gc_req_valid[0];
	assign gc_req_valid_sum[2] = gc_req_valid[0]+gc_req_valid[1];
	assign gc_req_valid_sum[3] = gc_req_valid[0]+gc_req_valid[1]+gc_req_valid[2];
	assign gc_req_valid_sum[4] = gc_req_valid[0]+gc_req_valid[1]+gc_req_valid[2]+gc_req_valid[3];
	assign gc_req_valid_sum[5] = gc_req_valid[0]+gc_req_valid[1]+gc_req_valid[2]+gc_req_valid[3]+gc_req_valid[4];
	assign gc_req_valid_sum[6] = gc_req_valid[0]+gc_req_valid[1]+gc_req_valid[2]+gc_req_valid[3]+gc_req_valid[4]+gc_req_valid[5];
	assign gc_assign[0] = gc_plus[gc_req_valid_sum[0]];
	assign gc_assign[1] = gc_plus[gc_req_valid_sum[1]];
	assign gc_assign[2] = gc_plus[gc_req_valid_sum[2]];
	assign gc_assign[3] = gc_plus[gc_req_valid_sum[3]];
	assign gc_assign[4] = gc_plus[gc_req_valid_sum[4]];
	assign gc_assign[5] = gc_plus[gc_req_valid_sum[5]];
	always_ff @(posedge clk) begin
		if (issue_fork) begin
			gc <= fork_gc;
			gd <= fork_gd;
		end else begin
			gc <= gc_plus[gc_req_valid_sum[6]];
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
		.parallel_out(parallel),
		.sw_broadcast,
		.sw_broadcast_out(sw_broadcast),
		.sw_broadcast_addr,
		.sw_broadcast_addr_out(sw_broadcast_addr),
		.sw_broadcast_data,
		.sw_broadcast_data_out(sw_broadcast_data),
		.issue_fork,
		.issue_fork_out(issue_fork),
		.fork_gc,
		.fork_gd,
		.gpr_arch_broadcast,
		.gpr_arch_broadcast_out(gpr_arch_broadcast),
		.fpr_arch_broadcast,
		.fpr_arch_broadcast_out(fpr_arch_broadcast),
		.gc(gc_assign[0]),
		.gc_req_valid(gc_req_valid[0]),
		.acc_req_valid,
		.acc_req_valid_out(acc_req_valid[0]),
		.acc_req_ready(acc_req_ready[0]),
		.acc_req_ready_out(acc_req_ready),
		.acc_data,
		.acc_data_out(acc_data[0]),
		.gc_stamp,
		.gc_stamp_out(gc_stamp[0]),
		.gd_sign(gd[GD_WIDTH-1]),
		.all_ending
	);
	for (genvar i=1; i<N_CORE; i++) begin
		core #(
			.PARENT(0),
			.CORE_I(i)
		) child(
			.clk,
			.parallel,
			.sw_broadcast,
			.sw_broadcast_addr,
			.sw_broadcast_data,
			.issue_fork,
			.gpr_arch_broadcast,
			.fpr_arch_broadcast,
			.gc(gc_assign[i]),
			.gc_req_valid(gc_req_valid[i]),
			.acc_req_valid_out(acc_req_valid[i]),
			.acc_req_ready(acc_req_ready[i]),
			.acc_data_out(acc_data[i]),
			.gc_stamp_out(gc_stamp[i]),
			.gd_sign(gd[GD_WIDTH-1]),
			.ending(ending[i])
		);
	end
endmodule
