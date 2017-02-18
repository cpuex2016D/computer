`include "common.vh"

module top_tb;
	logic CLK_P = 0;
	logic CLK_N = 1;
	logic UART_RX = 1;
	logic UART_TX;
	logic SW_W = 0;
	logic SW_E = 0;
	logic[7:0] LED;

	localparam PERIOD = 4;
//	localparam PERIOD = 1292;
	top #(
		.RECEIVER_PERIOD(PERIOD/2),
		.SENDER_PERIOD(PERIOD)
	) top(.*);

	logic sim_receiver_valid;
	logic[7:0] sim_receiver_out;
	receiver #(
		.RECEIVER_PERIOD(PERIOD/2)
	) sim_receiver(
		.clk(top.clk),
		.in(UART_TX),
		.out(sim_receiver_out),
		.valid(sim_receiver_valid)
	);

//	always #(0.5) begin
//		CLK_P <= !CLK_P;
//		CLK_N <= !CLK_N;
//	end
	always #(0.5) begin
		force top.clk = !top.clk;
	end

	int fd, fd_w, fd_debug;
	int c;
	int count = 0;

	always @(posedge top.clk) begin
		if (sim_receiver_valid) begin
			$fwrite(fd_w, "%c", sim_receiver_out);
			$fflush(fd_w);
			count = count + 1;
			if (count==49167) $finish;
		end
	end

	always #(1) begin
		if (top.parent.b_commit && (top.parent.b.b_e[0].failure ^ top.parent.b.b_e[0].prediction[1])) begin
			$fdisplay(fd_debug, "%d %d %d", top.parent.b.b_e[0].pc_from, top.parent.b.b_e[0].pc_to, $stime());
			$fflush(fd_debug);
		end
	end

	initial begin
		fd_w = $fopen("../../../o_sim", "wb");
		fd_debug = $fopen("../../../o_debug_vivado", "w");
//		fd_w = $fopen("../../../../o_sim", "wb");
		top.parent.parallel_out <= 0;
		top.parent.gpr_arch.registers[REG_SP].data <= REG_SP_INIT;
		top.parent.gpr_arch.registers[REG_HP].data <= REG_HP_INIT;

		//毎回変える
//		$readmemh("../../../minrt_pc0_text.hex", top.inst_mem.inst_mem);
//		$readmemh("../../../minrt_pc0_data.hex", top.lw_sw.data_mem.data_mem);
//		top.gpr_arch.registers[31].data = 789;

/*
		fd = $fopen("../../../program_fib_text", "rb");
//		fd = $fopen("../../../program_init_text", "rb");
//		fd = $fopen("../../../../program_init_text", "rb");
		#10;
		forever begin
			c = $fgetc(fd);
			if (c==-1) break;
			UART_RX <= 0;
			#PERIOD;
			for (int i=0; i<8; i++) begin
				UART_RX <= c[i];
				#PERIOD;
			end
			UART_RX <= 1;
			#PERIOD;
			#1;
		end
*/

		//毎回変える
//		$readmemh("../../../contest.sld.bin.hex", top.receiver_wrapper.buffer);
//		top.receiver_wrapper.in_pointer = 325;

//		fd = $fopen("../../../program_mandelbrot_data", "rb");
////		fd = $fopen("../../../../program_mandelbrot_data", "rb");
//		#10;
//		forever begin
//			c = $fgetc(fd);
//			if (c==-1) break;
//			UART_RX <= 0;
//			#PERIOD;
//			for (int i=0; i<8; i++) begin
//				UART_RX <= c[i];
//				#PERIOD;
//			end
//			UART_RX <= 1;
//			#PERIOD;
//			#1;
//		end
//
//		#10;
//		SW_W <= !SW_W;
//		#10;
//		SW_W <= !SW_W;
//
//		fd = $fopen("../../../program_mandelbrot_text", "rb");
////		fd = $fopen("../../../../program_mandelbrot_text", "rb");
//		#10;
//		forever begin
//			c = $fgetc(fd);
//			if (c==-1) break;
//			UART_RX <= 0;
//			#PERIOD;
//			for (int i=0; i<8; i++) begin
//				UART_RX <= c[i];
//				#PERIOD;
//			end
//			UART_RX <= 1;
//			#PERIOD;
//			#1;
//		end
//
//		#10;
//		SW_E <= !SW_E;
//		#10;
//		SW_E <= !SW_E;
	end
endmodule
