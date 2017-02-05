module top #(
	parameter SENDER_PERIOD = 2584,
	parameter ROM_WIDTH = 2
) (
	input logic CLK_P,
	input logic CLK_N,
	output logic UART_TX
);
	logic clk;
	IBUFGDS IBUFGDS(.I(CLK_P), .IB(CLK_N), .O(clk));
	//clk_wiz clk_wiz(.clk_in1_p(CLK_P), .clk_in1_n(CLK_N), .clk_out1(clk));

	logic[7:0] rom[2**ROM_WIDTH];
	logic[ROM_WIDTH-1:0] count = 0;

	logic ready;
	sender #(SENDER_PERIOD) sender(
		.clk,
		.in(rom[count]),
		.valid(1),
		.out(UART_TX),
		.ready
	);

	//int fd;
	initial begin
		$readmemh("data.hex", rom);
		//fd = $fopen("data.bin", "rb");
		//$fread(rom, fd);
	end
	always @(posedge clk) begin
		if (ready) begin
			count <= count + 1;
		end
	end
endmodule
