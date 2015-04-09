/*module test(DLY_RST, VGA_CTRL_CLK, VGA_BLANK_N, VGA_HS, VGA_B, VGA_G, VGA_R);
input[7:0] VGA_B, VGA_G, VGA_R;
input DLY_RST, VGA_CTRL_CLK, VGA_BLANK_N, VGA_HS;

vga_controller vga_ins(.iRST_n(DLY_RST),
		 .iVGA_CLK(VGA_CTRL_CLK),
		 .oBLANK_n(VGA_BLANK_N),
		 .oHS(VGA_HS),
		 .oVS(VGA_VS),
		 .b_data(VGA_B),
		 .g_data(VGA_G),
		 .r_data(VGA_R));
endmodule
*/

module test(clk, vga_h_sync, vga_v_sync, R, G, B);

	input clk;
	output vga_h_sync;
	output vga_v_sync;
	output [3:0] R;
	output [3:0] G;
	output [3:0] B;

	reg [9:0] CounterX;
	reg [8:0] CounterY;
	wire CounterXmaxed = (CounterX==767);

	always @(posedge clk)
	if(CounterXmaxed)
	  CounterX <= 0;
	else
	  CounterX <= CounterX + 1;

	always @(posedge clk)
	if(CounterXmaxed)
		 CounterY <= CounterY + 1;

	reg vga_HS, vga_VS;
	always @(posedge clk)
	begin
	  vga_HS <= (CounterX[9:4]==0);   // active for 16 clocks
	  vga_VS <= (CounterY==0);   // active for 768 clocks
	end

	assign vga_h_sync = ~vga_HS;
	assign vga_v_sync = ~vga_VS;

	assign R = 15;
	assign G = 15;
	assign B = 15;

endmodule
