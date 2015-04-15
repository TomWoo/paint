module vga_controller(iRST_n,
                      iVGA_CLK,
							 processorClk,
							 data_index_in,
							 data_memory_address_in,
							 ctrl_index_write_enable,
							 memory_read_data_out,
                      oBLANK_n,
                      oHS,
                      oVS,
                      b_data,
                      g_data,
                      r_data);
input iRST_n;
input iVGA_CLK;
input processorClk;
input [31:0] data_index_in; // The input index to be written to input memory 
input [31:0] data_memory_address_in; // the input data to be written to memory
input ctrl_index_write_enable; // The enable signal for writing the index
output reg oBLANK_n;
output reg oHS;
output reg oVS;
output [7:0] b_data;
output [7:0] g_data;  
output [7:0] r_data;
output [31:0] memory_read_data_out;                        
///////// ////                     
reg [18:0] ADDR;
reg [23:0] bgr_data;
wire VGA_CLK_n;
wire [31:0] index;
wire [23:0] bgr_data_raw;
wire cBLANK_n,cHS,cVS,rst;
////
assign rst = ~iRST_n;
video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
                              .reset(rst),
                              .blank_n(cBLANK_n),
                              .HS(cHS),
                              .VS(cVS));
////
////Addresss generator
always@(posedge iVGA_CLK,negedge iRST_n)
begin
  if (!iRST_n)
     ADDR<=19'd0;
  else if (cHS==1'b0 && cVS==1'b0)
     ADDR<=19'd0;
  else if (cBLANK_n==1'b1)
     ADDR<=ADDR+1;
end
//////////////////////////
//////INDEX addr.
assign VGA_CLK_n = ~iVGA_CLK;

indexRAM	indexRAM_inst (
	.clock_a(processorClk),
	.address_a(data_memory_address_in),
	.data_a(data_index_in),
	.wren_a(ctrl_index_write_enable),
	.q_a(memory_read_data_out),
	.clock_b(VGA_CLK_n),
	.address_b(ADDR),
	.wren_b(1'b0),
	.q_b(index)
	);
	
//////Color table output
img_index	img_index_inst (
	.address ( index[6:0] ),
	.clock ( iVGA_CLK ),
	.q ( bgr_data_raw)
	);
//////

//////latch valid data at falling edge;
always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw;
assign b_data = bgr_data[23:16];
assign g_data = bgr_data[15:8];
assign r_data = bgr_data[7:0];
///////////////////
//////Delay the iHD, iVD,iDEN for one clock cycle;
always@(negedge iVGA_CLK)
begin
  oHS<=cHS;
  oVS<=cVS;
  oBLANK_n<=cBLANK_n;
end

endmodule
