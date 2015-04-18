//*******************************************************************************************************************
//
//SECTION : Processor
//
//*******************************************************************************************************************
module processor(clock, reset, memory_read_data,ctrl_memory_write_enable, ps2_key_pressed, ps2_out, lcd_write, lcd_data, debug_data, debug_addr,debug_pc,debug_pc_change,debug_opcode_execute,debug_status);

	input 	clock, reset, ps2_key_pressed;
	input [31:0] memory_read_data; /* The data read from memory */
	input 	[7:0]	ps2_out;
	output 	lcd_write;
	output 	[31:0] 	lcd_data;
	output ctrl_memory_write_enable; /* A control signal to indicate whether memory should be written to */
	// GRADER OUTPUTS - YOU MUST CONNECT TO YOUR DMEM
	output 	[31:0] 	debug_data;
	output	[31:0]	debug_addr;
	
	//testing outputs. TODO remove these
	output [31:0] debug_pc;
	assign debug_pc = programCounter_fetch;
	output [1:0] debug_pc_change;
	assign debug_pc_change = {ctrl_PCSelect1,ctrl_PCSelect0};
	output [4:0] debug_opcode_execute;
	assign debug_opcode_execute = opcode_execute;
	output [10:0] debug_status;
	assign debug_status = status_execute;

	//Global Control wires
	wire ctrl_hazard;
	wire clk;
	assign clk = ~clock;
	
	//Set up the processor stages
	
	//********
	// Fetch
	//********

	
	//Fetch stage wires
	wire ctrl_exception_fetch;
	wire [31:0] programCounter_fetch,instructionData_fetch;
	
	//Fetch stage instantiation
	FetchStage fetchStage(.clk(clk),.hazard(ctrl_hazard|ctrl_multDivReservedHazard_execute|ctrl_multDivReady_execute),.data_jumpPC(jumpPC_execute),.data_branchPC(branchPC_execute),.data_jumpReturnPC(aluOperandB_execute),.ctrl_PCSrc({ctrl_PCSelect1,ctrl_PCSelect0}),
                         .data_PC_out(programCounter_fetch), .data_instruction_out(instructionData_fetch),
	 .data_exception(ctrl_exception_fetch), .ctrl_reset(reset));
	
	//Fetch decode interconnect
	RegNb #(.n(64))FDInterconnect(.clk(clk),.write_enable(~(ctrl_multDivReady_execute|ctrl_multDivReservedHazard_execute)),
	                             .data({64{~(ctrl_hazard)}/* If there's a hazard, write in nothing (NOP)*/}&
	                             {programCounter_fetch,instructionData_fetch}),.out({programCounter_decode,opcode_decode,rd_decode,rs_decode,immediate_decode}),
	 .reset(reset|ctrl_PCSelect1|ctrl_PCSelect0 /* Empty out interconnect if a reset signal is seen or if a new PC was stored(branch taken)*/));
	
	//********
	// Decode + Control + Status register
	//********
	
	//Decode stage wires 
	wire ctrl_PCSourceSelect_decode,ctrl_registerWriteEnable_decode,ctrl_ALUSrcSelect_decode,ctrl_PCSelect0, ctrl_returnAddrRegWrite_decode, ctrl_PCSelect1, ctrl_regReadAddr2Choice_decode,
	    ctrl_memoryWriteEnable_decode,ctrl_writeMemToReg_decode,ctrl_executeRtRdSelect_decode,ctrl_displayMemoryWriteEnable_decode,ctrl_displayDataMemoryOutputSelect_decode;
	wire [4:0] opcode_decode,rd_decode,rs_decode,ALUOpcode_decode,regReadAddr2_decode,regWriteIntermediate_decode;
	wire [16:0] immediate_decode;
	wire [31:0] branchPC_execute,programCounter_decode,regValA_decode,regValB_decode,regWriteIntermediateData_decode;
	
	//The decode stage
	DecodeStage decodeStage(.clk(clk), .ctrl_readReg1(rs_decode), .ctrl_readReg2(regReadAddr2_decode), .ctrl_writeReg(regWriteAddr_writeback), .data_a(regValA_decode), .data_b(regValB_decode),
                        	.data_writeData(newData_writeback),.ctrl_enable(ctrl_multDivReady_execute|ctrl_regDataWrite_writeback|ctrl_returnAddrRegWrite_decode/*Enable writing if we're writing in the writeback stage or if we're writing a return address*/),
	.ctrl_reset(reset));	
	// put a mux to select between rt and rd as a source for the register reading
	Mux2b32w RtSelection(.inB(immediate_decode[16:12]),.inA(rd_decode),.out(regReadAddr2_decode),.select(ctrl_regReadAddr2Choice_decode));
	// put a mux on the register writeback data that chooses between the original writeback info, the data read from memory, and the old PC for stuff like JAL
	Mux4b32w RegDataSelection(.inA(memOutput_writeback),.inB(memOutput_writeback),.inC(programCounter_decode),.inD(aluoutput_writeback),.out(regWriteIntermediateData_decode),.select({ctrl_writeMemToReg_writeback,ctrl_returnAddrRegWrite_decode}));
	// put another mux on the writeback to choose between what would have been writtenback and the mult div data
	Mux2b32w RegDataOrWriteDataSelection(.inA(multDivOutput_execute),.inB(regWriteIntermediateData_decode),.out(newData_writeback),.select(ctrl_multDivReady_execute));
	// have a mux on the register write address between Rd and 31 to choose between them in the case of a return address writeback
	Mux2b32w RegWriteAddrSelection(.inB(rd_writeback),.inA(5'b11111),.out(regWriteIntermediate_decode),.select(ctrl_returnAddrRegWrite_decode));
	//Have a mux on the register wride address to choose between mult/div address or the old address
	Mux2b32w MultDivOutputSelection(.inA(multDiv_addr_execute),.inB(regWriteIntermediate_decode),.out(regWriteAddr_writeback),.select(ctrl_multDivReady_execute));
	//The control stage
	ControlStage control(.opcode_decode(opcode_decode),.opcode_execute(opcode_execute),.aluop_decode(immediate_decode[6:2]),.programCounter_decode(programCounter_decode),
	                    .opA(aluOperandA_execute),.opB(aluOperandB_execute),.status_execute(status_execute),.ctrl_pcsrc(ctrl_PCSourceSelect_decode),.ctrl_regWrite(ctrl_registerWriteEnable_decode),
	                    .ctrl_ALUsrc(ctrl_ALUSrcSelect_decode),.ctrl_aluop(ALUOpcode_decode),.ctrl_PCSelect0(ctrl_PCSelect0),
	                    .ctrl_returnAddrRegWrite_decode(ctrl_returnAddrRegWrite_decode), .ctrl_PCSelect1(ctrl_PCSelect1),.ctrl_regReadAddr2Choice_decode(ctrl_regReadAddr2Choice_decode),
							  .ctrl_statusWrite_execute(ctrl_statusWrite_execute),
	.ctrl_writeMemToReg_decode(ctrl_writeMemToReg_decode),.ctrl_memoryWriteEnable_decode(ctrl_memoryWriteEnable_decode),.ctrl_displayMemoryWriteEnable_decode(ctrl_displayMemoryWriteEnable_decode),
	.ctrl_displayDataMemoryOutputSelect_decode(ctrl_displayDataMemoryOutputSelect_decode));
	
	
	//Detect hazards for the system
	/*Signal that is 1 if the next stage will use rd as opposed to rt in the ALU*/
	assign ctrl_executeRtRdSelect_decode = &(instructionData_fetch[31:27]~^5'b00101)|&(instructionData_fetch[31:27]~^5'b01000)|&(instructionData_fetch[31:27]~^5'b10010)|&(instructionData_fetch[31:27]~^5'b00111)|&(instructionData_fetch[31:27]~^5'b10001);
	/* A hazard occurs when a load word is being read at decode and (the rs of fetch matches rd of load or if we will use rd and it matches rd decode or if rt will be used and it matches rd of decode)*/
	assign ctrl_hazard = (&(opcode_decode~^5'b01000/*there is lw at decode*/)|&(opcode_decode~^5'b10010)) & (&(instructionData_fetch[21:17]~^rd_decode)/* If rs of fetch matches rd of load */|(ctrl_executeRtRdSelect_decode&(&(instructionData_fetch[26:22]~^rd_decode)))/*If fetch will use rd and it matches the decode rd */|
	                     (~ctrl_executeRtRdSelect_decode&(&(instructionData_fetch[16:12]~^rd_decode))))/*If rt will be used and it matches decode rd*/;
	
	//Decode Execute interconnect
	RegNb #(.n(147))decodeAluInterconnect(.clk(clk),.write_enable(~ctrl_multDivReady_execute),.data({147{~(ctrl_multDivReservedHazard_execute)}}&{opcode_decode,programCounter_decode,regValA_decode,regValB_decode,immediate_decode,ALUOpcode_decode,
	                                     rd_decode,rs_decode,ctrl_registerWriteEnable_decode,ctrl_ALUSrcSelect_decode,ctrl_writeMemToReg_decode,ctrl_memoryWriteEnable_decode,regReadAddr2_decode,
													 ctrl_displayMemoryWriteEnable_decode,ctrl_displayDataMemoryOutputSelect_decode}),
	                              .out({opcode_execute,programCounter_execute,registerAVal_execute,registerBVal_execute,immediate_execute,ALUOpcode_execute,rd_execute,rs_execute,ctrl_registerWriteEnable_execute,
	 ctrl_ALUSrcSelect_execute,ctrl_writeMemToReg_execute,ctrl_memoryWriteEnable_execute,regReadAddr2_execute,ctrl_displayMemoryWriteEnable_execute,ctrl_displayDataMemoryOutputSelect_execute}),
	 .reset({ctrl_PCSelect1|ctrl_PCSelect0|reset/*Reset in the case of a new PC selection to drop partial jump*/}));
	 
	//********
	// Execute 
	//********
	
	//Execute stage wires
	wire ctrl_registerWriteEnable_execute,ctrl_ALUSrcSelect_execute,ctrl_statusWrite_execute,ctrl_writeMemToReg_execute,ctrl_memoryWriteEnable_execute,ctrl_multDivException_execute,
	    ctrl_multDivReady_execute,ctrl_multDivReservedHazard_execute,ctrl_displayMemoryWriteEnable_execute,ctrl_displayDataMemoryOutputSelect_execute;
	wire [4:0] regReadAddr2_execute,opcode_execute,rd_execute,ALUOpcode_execute,rs_execute,multDiv_addr_execute;
	wire [16:0] immediate_execute;
	wire [15:0] status_execute;
	wire [26:0] jumpPC_execute;
	wire [31:0] programCounter_execute,registerBVal_execute,registerAVal_execute,aluOutput_execute,multDivOutput_execute;
	//Assign the address to be used in a jump from the execute stage
	assign jumpPC_execute = {rd_execute,rs_execute,immediate_execute};
	// Add the execute immediate and the program counter at the execute stage to create the branch PC address
	CLAadder PCBranchingadder(.a(programCounter_execute),.b({{15{immediate_execute[16]}},immediate_execute}),.subtract(1'b0),.sum(branchPC_execute));
	
	//Put in Execute stage forwarding
	wire [31:0] aluOperandA_execute, aluOperandB_execute;
	Mux4b32w ALUinASelection(.inA({32{ctrl_writeMemToReg_memory}}&memoryOutput_memory|{32{~ctrl_writeMemToReg_memory}}&aluOutput_memory),
	                        .inB({32{ctrl_writeMemToReg_memory}}&memoryOutput_memory|{32{~ctrl_writeMemToReg_memory}}&aluOutput_memory),
	.inC(newData_writeback),.inD(registerAVal_execute),.out(aluOperandA_execute),
	.select({(&(rd_memory~^rs_execute))&(ctrl_registerWriteEnable_memory|ctrl_memoryWriteEnable_memory)/*If we need to grab from write*/,
	(&(regWriteAddr_writeback~^rs_execute))&(ctrl_regDataWrite_writeback|ctrl_returnAddrRegWrite_decode)/*If we need to grab from writeback*/}));
	Mux4b32w ALUinBSelection(.inA({32{ctrl_writeMemToReg_memory}}&memoryOutput_memory|{32{~ctrl_writeMemToReg_memory}}&aluOutput_memory),
	                        .inB({32{ctrl_writeMemToReg_memory}}&memoryOutput_memory|{32{~ctrl_writeMemToReg_memory}}&aluOutput_memory),
	.inC(newData_writeback),.inD(registerBVal_execute),.out(aluOperandB_execute),
	.select({(&(rd_memory~^regReadAddr2_execute))&(ctrl_registerWriteEnable_memory|ctrl_memoryWriteEnable_memory)/*If we need to grab from write*/,(
	&(regWriteAddr_writeback~^regReadAddr2_execute))&(ctrl_regDataWrite_writeback|ctrl_returnAddrRegWrite_decode)/*If we need to grab from writeback*/}));
	
	// Create the ALU
	ALUStage alu(.clk(clk), .data_regA(aluOperandA_execute), .data_regB(aluOperandB_execute), .data_immediate(immediate_execute), .data_output(aluOutput_execute), .data_programCounter(programCounter_execute),
	            .ctrl_ALUopcode(ALUOpcode_execute), .ctrl_ALUsrc(ctrl_ALUSrcSelect_execute), .ctrl_enable(1'b1),
	.ctrl_reset(reset),.ctrl_multDivReady(ctrl_multDivReady_execute),.data_multDivOutput(multDivOutput_execute),.ctrl_exception(ctrl_multDivException_execute));
	// Create the reservation station
	ReservationStation resStation(.clk(clk),.multDivRegister(rd_execute),.aluop(ALUOpcode_execute),.checkRegister1(rs_decode),.checkRegister2(regReadAddr2_decode),
	                             .reservedHazard(ctrl_multDivReservedHazard_execute),.reset(reset),.addressOut(multDiv_addr_execute));
	// make the status register
	RegNb #(.n(16))statusReg(.clk(clk),.write_enable(ctrl_statusWrite_execute|ctrl_multDivException_execute),.data(({16{!ctrl_multDivException_execute}}&immediate_execute)|{{15{1'b0}},ctrl_multDivException_execute}),
	                        .out(status_execute),.reset(reset));
	
	//Execute-Memory interconnect
	RegNb #(.n(75))EMInterconnect(.clk(clk),.write_enable(~ctrl_multDivReady_execute),.data({72{~(&(ALUOpcode_execute~^5'b00110)|&(ALUOpcode_execute~^5'b00111)|&(ALUOpcode_execute~^5'b10001))}/* Put a noop in if we've multiplied */}&
	{aluOutput_execute,rd_execute,ctrl_registerWriteEnable_execute,ctrl_writeMemToReg_execute,aluOperandB_execute,ctrl_memoryWriteEnable_execute,ctrl_displayMemoryWriteEnable_execute,ctrl_displayDataMemoryOutputSelect_execute}),
	.out({aluOutput_memory,rd_memory,ctrl_registerWriteEnable_memory,ctrl_writeMemToReg_memory,aluOperandB_memory,ctrl_memoryWriteEnable_memory,ctrl_displayMemoryWriteEnable_memory,ctrl_displayDataMemoryOutputSelect_memory}),.reset(reset));
	
	//**********
	// Memory
	//**********
	
	//Put in memory forwarding
	wire ctrl_registerWriteEnable_memory,ctrl_writeMemToReg_memory, ctrl_memoryWriteEnable_memory,ctrl_displayMemoryWriteEnable_memory,ctrl_displayDataMemoryOutputSelect_memory;
	wire [4:0] rd_memory;
	wire [31:0] memoryDataIn_memory, aluOperandB_memory, aluOutput_memory, memoryOutput_memory,dataMemoryOutput_memory,displayMemoryOutput_memory;
	Mux2b32w MemoryForwardUnit(.inA(newData_writeback),.inB(aluOperandB_memory),.out(memoryDataIn_memory), 
	                          .select(&(rd_memory~^regWriteAddr_writeback)&(ctrl_regDataWrite_writeback|ctrl_returnAddrRegWrite_decode)));
	//Put in a memory output mux to choose between the two memory modules
	Mux2b32w MemorySelectionUnit(.inA(displayMemoryOutput_memory),.inB(dataMemoryOutput_memory),.out(memoryOutput_memory),.select(ctrl_displayDataMemoryOutputSelect_memory));
	//Set the memory from external
		assign displayMemoryOutput_memory = memory_read_data ;
		assign ctrl_memory_write_enable = ctrl_displayMemoryWriteEnable_memory;
	//Create the data memory
	dmem DataMemory(
	.address(aluOutput_memory),
	.clock(clk),
	.data(memoryDataIn_memory),
	.wren(ctrl_memoryWriteEnable_memory),
	.q(dataMemoryOutput_memory));
	//Memory writeback interconnect
	RegNb #(.n(71))MemWBInterconnect(.clk(clk),.write_enable(~ctrl_multDivReady_execute),.data({memoryOutput_memory,aluOutput_memory,rd_memory,ctrl_registerWriteEnable_memory,ctrl_writeMemToReg_memory}),
	                                .out({memOutput_writeback,aluoutput_writeback,rd_writeback,ctrl_regDataWrite_writeback,ctrl_writeMemToReg_writeback}),.reset(reset));
	//**********
	// Writeback
	//**********
	
	//Writeback wires
	wire ctrl_regDataWrite_writeback, ctrl_writeMemToReg_writeback;
	wire [4:0] rd_writeback,regWriteAddr_writeback;
	wire [31:0] memOutput_writeback,aluoutput_writeback, newData_writeback;
	
	
	//**********
	// Output Pin Assignment
	//**********
	
	// THIS IS REQUIRED FOR GRADING
	// CHANGE THIS TO ASSIGN YOUR DMEM WRITE ADDRESS ALSO TO debug_addr
	assign debug_addr = aluOutput_memory;
	// CHANGE THIS TO ASSIGN YOUR DMEM DATA INPUT (TO BE WRITTEN) ALSO TO debug_data
	assign debug_data = memoryDataIn_memory;
	////////////////////////////////////////////////////////////
	
endmodule


//*******************************************************************************************************************
//
//SECTION : Control modules
//
//*******************************************************************************************************************

//-------------------------------------------
// The control stage to evaluate with the Decode stage. Contains barely minified logic to allow the compiler to minimize
// opcode_decode -- the current opcode (5)
// aluop_decode -- the opcode for the alu (5)
// programCounter_decode -- the program counter (12)
// opA -- the A operation (32)
// opB -- the B operation (32)
// status_execute -- the status_execute signal (16)
// ctrl_pcsrc -- the pc source control signal (1)
// ctrl_regWrite -- a control indicating if a register should write (1)
// ctrl_aluSrc -- the source operand b to the ALU (1)
// ctrl_aluop -- the new alu operation (5)
// ctrl_PCSelect0 -- choose the new program counter (1)
// ctrl_returnAddrRegWrite_decode -- write the program counter to register 31 (1) 
// ctrl_PCSelect1 -- a control signal to choose to set PC to PC+1+N (1)
// ctrl_regReadAddr2Choice_decode -- a control signal to decide between Rs and Rd (1)
// ctrl_memoryWriteEnable_decode -- the enable signal for writing to memory (1)
//-------------------------------------------
module ControlStage(opcode_decode, opcode_execute, aluop_decode, programCounter_decode, opA,opB, status_execute, ctrl_pcsrc,ctrl_regWrite,ctrl_ALUsrc,ctrl_aluop, ctrl_PCSelect0,
                    ctrl_returnAddrRegWrite_decode, ctrl_PCSelect1,ctrl_regReadAddr2Choice_decode, ctrl_statusWrite_execute,ctrl_writeMemToReg_decode,ctrl_memoryWriteEnable_decode,
						  ctrl_displayMemoryWriteEnable_decode,ctrl_displayDataMemoryOutputSelect_decode);
	input [4:0] opcode_decode, opcode_execute, aluop_decode;
	input [31:0] opA,opB;
	input [15:0] status_execute;
	input [11:0] programCounter_decode;
	output [4:0] ctrl_aluop;
	output ctrl_pcsrc,ctrl_regWrite,ctrl_ALUsrc, ctrl_PCSelect0, ctrl_returnAddrRegWrite_decode, ctrl_PCSelect1, ctrl_regReadAddr2Choice_decode, ctrl_statusWrite_execute,
          ctrl_writeMemToReg_decode,ctrl_memoryWriteEnable_decode, ctrl_displayMemoryWriteEnable_decode,ctrl_displayDataMemoryOutputSelect_decode;
	wire [31:0] opDifference;
	// Assign the pcsrc
	assign ctrl_pcsrc = !opcode_decode[4]&!opcode_decode[3]&!opcode_decode[2]&opcode_decode[0]|!opcode_decode[4]&!opcode_decode[3]&!opcode_decode[2]&opcode_decode[1]|!opcode_decode[4]&!opcode_decode[3]&opcode_decode[2]&!opcode_decode[0]|opcode_decode[4]&!opcode_decode[3]&opcode_decode[2]&opcode_decode[1]&!opcode_decode[0];
	// Assign whether a register should write
	assign ctrl_regWrite = !opcode_decode[4]&!opcode_decode[3]&!opcode_decode[2]&!opcode_decode[1]&!opcode_decode[0]|!opcode_decode[4]&!opcode_decode[3]&opcode_decode[2]&!opcode_decode[1]&opcode_decode[0]|!opcode_decode[4]&!opcode_decode[3]&!opcode_decode[2]&opcode_decode[1]&opcode_decode[0]|&(opcode_decode~^5'b01000)|&(opcode_decode~^5'b10010);
	// Assign the ALU source
	assign ctrl_ALUsrc = !opcode_decode[4]&!opcode_decode[3]&opcode_decode[2]&!opcode_decode[1]&opcode_decode[0]|!opcode_decode[4]&opcode_decode[3]&!opcode_decode[2]&!opcode_decode[1]&!opcode_decode[0]|!opcode_decode[4]&!opcode_decode[3]&opcode_decode[2]&opcode_decode[1]&opcode_decode[0]|&(opcode_decode~^5'b00111)|&(opcode_decode~^5'b10001)|&(opcode_decode~^5'b01000)|&(opcode_decode~^5'b10010);
	// Assign additional ALU functions
	assign ctrl_aluop = ({5{&(opcode_decode~^5'b00000)}}&aluop_decode) | ({5{&(opcode_decode~^5'b00101)}}&5'b00000);
	// Choose whether to choose a new program counter
	assign ctrl_PCSelect0 = &(opcode_execute~^5'b00001)|&(opcode_execute~^5'b00011)|&(opcode_execute~^5'b00100);
	// Choose whether to write the PC to reg31
	assign ctrl_returnAddrRegWrite_decode = &(opcode_decode~^5'b00011);
	// Figure out equality for writeback
	CLAadder controlAdder(.a(opB),.b(opA),.subtract(1'b1),.sum(opDifference));
	assign ctrl_PCSelect1 = (&(opcode_execute~^5'b00010)&|opDifference)/* Not Equals */| (&(opcode_execute~^5'b10110)&(|status_execute)/*Branch exception*/) | (&(opcode_execute~^5'b00110)&opDifference[31])/* Less Than */|(&(opcode_execute~^5'b10110)&(|status_execute))|&(opcode_execute~^5'b00100)/* jr*/;
	// Choose between Rs and Rd
	assign ctrl_regReadAddr2Choice_decode = &(opcode_decode~^5'b00010)|&(opcode_decode~^5'b10110) | &(opcode_decode~^5'b00110)|&(opcode_decode~^5'b00100)|&(opcode_decode~^5'b00111)|&(opcode_decode~^5'b10001);
	// Choose whether to write to status_execute
	assign ctrl_statusWrite_execute = &(opcode_execute~^5'b10101);
	// Choose whether to write memory to registers
	assign ctrl_writeMemToReg_decode = &(opcode_decode~^5'b01000)|&(opcode_decode~^5'b10010);
	// Choose write enabling
	assign ctrl_memoryWriteEnable_decode = (&(opcode_decode~^5'b00111));
	// Choose write enabling for display memory
	assign ctrl_displayMemoryWriteEnable_decode = &(opcode_decode~^5'b10001);
	//Choose between the output selection of display memory or data memory
	assign ctrl_displayDataMemoryOutputSelect_decode = &(opcode_decode~^5'b10001)|&(opcode_decode~^5'b10010);
	
	
endmodule

//*******************************************************************************************************************
//
//SECTION : Stages. Do not contain any barrier or control logic
//
//*******************************************************************************************************************

//-------------------------------------------
// The instruction read, contains logic for incrementing the PC and selecting between a new PC, and loading from the instruction memory
// status_execute: Unverified
// clk -- clock signal (1 bit wide)
// data_jumpPC -- an optional new PC value (32)
// data_jumpReturnPC -- the PC with value from RD (32)
// ctrl_PCSrc -- set the PC to the new PC (1)
// data_PC_out -- the current program counter value + 1(12)
// data_instruction_out -- the output instruction from the instruction memory (32)
// data_exception -- an exception from the stage (1)
// ctrl_reset -- resets the stage (1)
//-------------------------------------------
module FetchStage(clk,hazard,data_jumpPC,data_branchPC,data_jumpReturnPC,ctrl_PCSrc, data_PC_out, data_instruction_out, data_exception, ctrl_reset);
	input clk, ctrl_reset, hazard;
	input [1:0] ctrl_PCSrc;
	input [31:0] data_jumpPC, data_branchPC, data_jumpReturnPC;
	output [31:0] data_instruction_out,data_PC_out;
	output data_exception;
	wire[31:0] new_PC, current_PC, incremented_PC;
	// Make the PC
	Reg32b pc(.clk(clk),.write_enable(1'b1),.data(new_PC),.out(current_PC),.reset(ctrl_reset));
	// Select between the incremented PC or a new PC
	Mux4b32w PCselectionMux(.inA(data_jumpReturnPC),.inB(data_branchPC),.inC(data_jumpPC), .inD(incremented_PC), .out(new_PC), .select(ctrl_PCSrc));
	// Increment the PC by 1
	CLAadder cladder(.a(current_PC),.b(0),.subtract(1'b0),.sum(incremented_PC),.cout(data_exception),.cin(~hazard));
	//Set the current PC output
	assign data_PC_out = new_PC;
	imem myimem(	.address 	(current_PC[11:0]),
	.clken	(1'b1),
	.clock	(!clk),
	.q 	(data_instruction_out)
	); 
endmodule
//-------------------------------------------
// The register read stage (instruction decode). Reads data from the 32 registers and outputs them. Data write on high-low transition.
// status_decode: Unverified
// clk -- clock signal (1)
// ctrl_readReg1 -- the read address of register 1 (5)
// ctrl_readReg2 -- the read address of register 2 (5)
// ctrl_writeReg -- the write register address (5)
// data_a -- the data output of the first register (32)
// data_b -- the data output of the second register (32)
// data_writeData -- the data input for the write register (32)
// data_branchPC -- the program counter added to the immediate value (32)
// ctrl_enable -- the enable signal for the stage (1)
// ctrl_reset -- the reset signal for the stage (1)
//-------------------------------------------
module DecodeStage(clk, ctrl_readReg1, ctrl_readReg2, ctrl_writeReg, data_a, data_b, data_writeData, ctrl_enable, ctrl_reset);
	input clk, ctrl_enable, ctrl_reset;
	input [4:0] ctrl_readReg1, ctrl_readReg2, ctrl_writeReg;
	input [31:0] data_writeData;
	output [31:0] data_a,data_b;

	// Make the register file
	regfile registerFile(.clock(clk), .ctrl_memoryWriteEnable_decode(ctrl_enable), .ctrl_reset(ctrl_reset), .ctrl_writeReg(ctrl_writeReg),
	.ctrl_readRegA(ctrl_readReg1), .ctrl_readRegB(ctrl_readReg2), .data_writeReg(data_writeData), .data_readRegA(data_a), .data_readRegB(data_b));
	
	
endmodule

//-------------------------------------------
// The ALU stage. Performs calculations on A, B, and immediate. Also increments the program counter
// status_decode: Unverified
// clk -- the clock signal (1)
// data_regA -- the data from register A (32)
// data_regB -- the data from register B (32)
// data_immediate -- the immediate data (17)
// data_output -- the output of the ALU (32)
// data_programCounter_fetch -- the original program counter (32)
// data_addedprogramCounter_fetch -- the added program counter (32)
// ctrl_ALUsrc -- a control signal for ALU selection (1)
// ctrl_ALUopcode -- the opcode for the ALU
// data_exception -- exception output from ALU (1)
// ctrl_enable -- enable signal for the module (1)
// ctrl_reset -- the reset signal for the stage (1)
//-------------------------------------------	 
module ALUStage(clk, data_regA, data_regB, data_immediate,data_output, data_programCounter, data_addedprogramCounter, ctrl_ALUopcode, ctrl_ALUsrc,ctrl_enable, ctrl_reset,
                ctrl_multDivReady,data_multDivOutput,ctrl_exception);
	input clk,ctrl_reset,ctrl_enable, ctrl_ALUsrc;
	input [31:0] data_regA, data_regB, data_programCounter;
	input [16:0] data_immediate;
	input [4:0] ctrl_ALUopcode;
	output [31:0] data_output, data_addedprogramCounter,data_multDivOutput;
	output ctrl_exception,ctrl_multDivReady;
	wire [31:0] opB;
	// Add the value of the PC to the sign extended immediate
	CLAadder programCounter_fetchAdder(.a(data_programCounter),.b({{15{data_immediate[16]}},data_immediate}),.subtract(1'b0),.sum(data_addedprogramCounter));
	// Choose between the sign extended immediate, the data in register b
	Mux4b32w bMux(.inC({{15{data_immediate[16]}},data_immediate}), .inD(data_regB), .out(opB), .select({1'b0,ctrl_ALUsrc}));
	// Create the ALU
	zdb3_alu Alu(.data_operandA(data_regA), .data_operandB(opB), .ctrl_ALUopcode(ctrl_ALUopcode), .ctrl_shiftamt(data_immediate[11:7]), .data_result(data_output), .clk(clk),
	            .multDivReady(ctrl_multDivReady),.multDivOutput(data_multDivOutput),.exception(ctrl_exception));
endmodule
//-------------------------------------------
// The reservation station. Keeps track of which registers are awaiting a mult and when input a register 
// indicates whether the register is present in the reservation station. It is assumed that register 0 will never be multiplied to.
// status: Unverified
// clk -- clock signal (1)
// multDivRegister -- the current mult/divide write destination from execute stage(5)
// aluop -- the current alu opcode from execute stage. Used to determine if a multiply or divide is taking place (5)
// checkRegister1 -- destination register from Decode stage input1 to check if reserved (5)
// checkRegister2 -- destination register from Decode stage input2 to check if reserved (5)
// reservedHazard -- a bit indicating whether the register is reserved in the reservation station (1)
// reset -- the reset bit (1)
// addressOut--the output address of the current mult/div completed instruction (5)
//-------------------------------------------
module ReservationStation(clk,multDivRegister,aluop,checkRegister1,checkRegister2,reservedHazard,reset,addressOut);
	input clk,reset;
	input [4:0] multDivRegister, aluop,checkRegister1,checkRegister2;
	output [4:0] addressOut;
	output reservedHazard;
	wire isMultDiv;
	wire [31:0] registerMatches1,registerMatches2;
	wire [159:0] registerDestination;

	//Figure out if a multiply or divide is taking place
	assign isMultDiv = &(aluop~^5'b00110)|&(aluop~^5'b00111);
	
	//Make the first reservation station register
	RegNb #(.n(5))resStation0(.clk(clk),.write_enable(isMultDiv),.data(multDivRegister),.out(registerDestination[4:0]),.reset(reset|!isMultDiv));
	assign registerMatches1[0] = isMultDiv&|checkRegister1 &(&(checkRegister1~^multDivRegister));
	assign registerMatches2[0] = isMultDiv&|checkRegister2 &(&(checkRegister2~^multDivRegister));
	genvar c;
	generate
	for(c = 1;c<32; c= c+1) begin: regfileLoop
	//Generate the registers of the reservation station
	RegNb #(.n(5))resStation(.clk(clk),.write_enable(1'b1),.data(registerDestination[(5*c)-1:5*(c-1)]),
	                                .out(registerDestination[(5*(c+1))-1:5*(c)]),.reset(reset));
	  //Assign the register matches bits. Ensure it's not a 0
	assign registerMatches1[c] = |checkRegister1 &(&(checkRegister1~^registerDestination[(5*(c))-1:5*(c-1)]));
	assign registerMatches2[c] = |checkRegister2 &(&(checkRegister2~^registerDestination[(5*(c))-1:5*(c-1)]));
	end
	endgenerate
	assign addressOut = registerDestination[159:155];
	assign reservedHazard = (|registerMatches1)|(|registerMatches2);
	
endmodule
//-------------------------------------------
// The Memory stage. Fetches values from memory
// status_decode: Unverified
// clk -- the clock signal (1)
// data_addr -- the address to fetch from memory (32)
// data_output -- the output of the memory (32)
// data_in -- the data to be written (32)
// ctrl_memoryWriteEnable -- the write enable (1)
// ctrl_enable -- enable signal for the module (1)
// ctrl_reset -- the reset signal for the stage (1)

/* This has been removed for the paint program as memory is now external to the processor

module MemoryStage(clk, data_addr, data_output,data_in, ctrl_memoryWriteEnable, ctrl_enable);
	input clk, ctrl_enable,ctrl_memoryWriteEnable;
	input [31:0] data_addr, data_in;
	output [31:0] data_output;
	
	// You'll need to change where the dmem and imem read and write...
	dmem mydmem(	.address	(data_addr),
	.clock	(!clk),
	.data	(data_in),
	.wren	(ctrl_memoryWriteEnable&ctrl_enable),
	.q	(data_output)
	);
endmodule
*/






//*******************************************************************************************************************
//
//SECTION : Top level modules i.e. ALU, Register, etc.
//
//*******************************************************************************************************************

//-------------------------------------------
// A basic ALU. NOTE: isNotEqual and isLessThan are only valid during or immediately after a subtraction.
//00000 - Add
//00001 - Subtract
//00010 - And
//00011 - Or
//00100 - SLL
//00101 - SRA
//00110 - Multiply
//00111 - Divide
// status_decode : Unverified
// data_operandA -- operand A (32 bits)
// data_operandB -- operand B (32 bits)
// ctrl_ALUopcode -- alu operation code (5 bits)
// ctrl_shiftamt -- shift amount for bit shifters (5 bits)
// data_result -- the result of the alu operation (32 bits)
// isNotEqual -- the result of the isNotEqual. Only valid after subtraction (1 bit)
// isLessThan -- the result of the isLessThan. Only valid after subtraction (1 bit)
// clk -- the clock signal (1 bit wide)
// multDivReady -- a bit indicating if the multiplier/divider is ready (1)
// multDivOutput -- the output of the multiplier/divider (32)
// exception -- an exception from the multiplier/divider (1)
//-------------------------------------------
module zdb3_alu(data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan,clk,multDivReady,multDivOutput,exception);
   input [31:0] data_operandA, data_operandB;
   input [4:0] ctrl_ALUopcode, ctrl_shiftamt;
	input clk;
   output [31:0] data_result,multDivOutput;
   output isNotEqual, isLessThan, multDivReady,exception;
	wire [31:0] operation,andout,orout,sumout,sllout,sraout;
	// Decode the operation code
	Dec5b opDecoder(.in(ctrl_ALUopcode),.out(operation));
	// Make the adder
	CLAadder adder(.a(data_operandA),.b(data_operandB),.subtract(operation[1]),.sum(sumout),.orout(orout),.andout(andout));
	// Make the mult/div module	
	multdiv multiplyDivide(.data_operandA(data_operandA), .data_operandB(data_operandB), .ctrl_MULT(operation[6]), .ctrl_DIV(operation[7]), .clock(clk), 
	                      .data_result(multDivOutput),.data_exception(exception),.data_resultRDY(multDivReady));
	// Make the notEquals operator
	NotZeroCheck zeroModule(.data(sumout),.out(isNotEqual));
	// Make the is less than operator
	assign isLessThan = sumout[31];
	// Make the shift left logical component
	SLL32b shiftLeftLogical(.data(data_operandA),.shamt(ctrl_shiftamt),.out(sllout));
	// Make the shift right arithmetic component
	SRA32b shiftRightArithmetic(.data(data_operandA), .shamt(ctrl_shiftamt),.out(sraout));
	// Create the tri-state buffers for the various outputs of the ALU
	TriBuff32 andTri(.in(andout),.oe(operation[2]),.out(data_result));
	TriBuff32 orTri(.in(orout),.oe(operation[3]),.out(data_result));
	TriBuff32 sumTri(.in(sumout),.oe(operation[0]|operation[1]),.out(data_result));
	TriBuff32 sllTri(.in(sllout),.oe(operation[4]),.out(data_result));
	TriBuff32 sraTri(.in(sraout),.oe(operation[5]),.out(data_result));
endmodule

// ----------------------------------------------
// A 32 32-bit register  file. Writes on clock low
// status_decode : Unverified
// clock -- clock signal (1 bit wide)
// ctrl_memoryWriteEnable_decode -- write enable signal (1 bit wide)
// ctrl_reset -- reset signal (1 bit wide)
// ctrl_writeReg -- register address to write (5 bits wide)
// ctrl_readRegA -- read A register address (5 bits wide)
// ctrl_readRegB -- read B register address (5 bits wide)
// data_writeReg -- register data to write (32 bits wide)
// data_readRegA -- read A register data (32 bits wide)
// data_readRegB -- read B register data (32 bits wide)
//-----------------------------------------------
module regfile(clock, ctrl_memoryWriteEnable_decode, ctrl_reset, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA, data_readRegB);
   input clock, ctrl_memoryWriteEnable_decode, ctrl_reset;
   input [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
   input [31:0] data_writeReg;
   output [31:0] data_readRegA, data_readRegB;
	
	wire [31:0] regWriteAddr_writebackess, readA_address, regReadAddr2_decode_address;
	//Decode the addresses
	Dec5b write_dec(ctrl_writeReg,regWriteAddr_writebackess);
	Dec5b readA_dec(ctrl_readRegA, readA_address);
	Dec5b regReadAddr2_decode_dec(ctrl_readRegB, regReadAddr2_decode_address);	
	
	//Generate the registers
	genvar c;
	generate
	for(c = 0;c<32; c= c+1) begin: regfileLoop
	wire [31:0] regist_wire;
	Reg32b regist(.clk(!clock),.write_enable(regWriteAddr_writebackess[c]&ctrl_memoryWriteEnable_decode),.data(data_writeReg), .out(regist_wire), .reset(ctrl_reset));	
	TriBuff32 tribuff_a(.in(regist_wire),.oe(readA_address[c]),.out(data_readRegA));
	TriBuff32 tribuff_b(.in(regist_wire),.oe(regReadAddr2_decode_address[c]),.out(data_readRegB));
	
	end
	endgenerate
endmodule

//*******************************************************************************************************************
//
//SECTION : Secondary modules i.e. Mult/Div, Adder, etc.
//
//*******************************************************************************************************************

// ----------------------------------------------
// A generic 32 bit register
// status_decode : Verified
// clk -- the clock signal for the register (1 bit wide)
// write_enable -- the read enable signal for the register (1 bit wide)
// data -- the data signal for the register (32 bits wide)
// out -- the output data from the register (32 bits wide)
// reset -- the reset signal for the register (1 bit wide)
//-----------------------------------------------
module Reg32b(clk,write_enable,data,out,reset);
	
	input clk, reset, write_enable;
	input [31:0] data;
	output [31:0] out;
	
	
	genvar c;
	generate
	for(c = 0;c<32;c=c+1) begin: registerLoop
	DFlip flip(.data(data[c]),.clk(clk),.reset(reset),.out(out[c]),.enable(write_enable));
	end
	endgenerate
endmodule

// ----------------------------------------------
// A generic n- bit register
// status_decode : Unverified
// parameter: n - the number of bits in the register
// clk -- the clock signal for the register (1 bit wide)
// write_enable -- the read enable signal for the register (1 bit wide)
// data -- the data signal for the register (n bits wide)
// out -- the output data from the register (n bits wide)
// reset -- the reset signal for the register (1 bit wide)
//-----------------------------------------------
module RegNb(clk,write_enable,data,out,reset);
	parameter n;
	input clk, reset, write_enable;
	input [n-1:0] data;
	output [n-1:0] out;
	
	
	genvar c;
	generate
	for(c = 0;c<n;c=c+1) begin: registerLoop
	DFlip flip(.data(data[c]),.clk(clk),.reset(reset),.out(out[c]),.enable(write_enable));
	end
	endgenerate
endmodule




//-----------------------------------------------
// A 32-bit pipelined multiplier/divider that uses booth's algorithm for
// multiplication and the naive method for division. Both multiplication and
// division take12 clock cycles
// status_decode: Verified
// data_operandA -- the first operand (dividend)(32 bits)
// data_operandB -- the second operand (divisor)(32 bits)
// ctrl_MULT -- multiplication signal (1 bit)
// ctrl_DIV -- division signal (1 bit)
// clock -- clock signal
//-----------------------------------------------

module multdiv(data_operandA, data_operandB, ctrl_MULT, ctrl_DIV, clock, data_result, data_exception, data_inputRDY, data_resultRDY);
   input [31:0] data_operandA;
   input [31:0] data_operandB;
   input ctrl_MULT, ctrl_DIV, clock;             
   output [31:0] data_result; 
   output data_exception, data_inputRDY, data_resultRDY;
	
	wire [1:0] error, ready;
	wire [31:0] multResult, divResult;
	// make the divider. Throw an error if the number is the maximum allowed negative number.
	PipelinedDivider divider(.clk(clock), .error_in(ctrl_MULT&ctrl_DIV|(data_operandA[31]&~|data_operandA[30:0])|(data_operandB[31]&~|data_operandB[30:0])), .data_divisor(data_operandB), .data_dividend(data_operandA), .ctrl_begin(ctrl_DIV), .data_ready(ready[1]), 
	                        .data_error(error[1]), .data_result(divResult));
	PipelinedBoothMultiplier multiplier(.clk(clock),.error_in(ctrl_MULT&ctrl_DIV),.data_multiplier(data_operandA), 
	                        .data_multiplicand(data_operandB), .ctrl_begin(ctrl_MULT), .data_ready(ready[0]), .data_error(error[0]), .data_result(multResult));
	 
	TriBuff32 multTri(.in(multResult),.oe(ready[0]&!ready[1]),.out(data_result));
	TriBuff32 divTri(.in(divResult),.oe(ready[1]&!ready[0]),.out(data_result));
	
	assign data_exception = |error | &ready;
	assign data_inputRDY = 1'b1;
	assign data_resultRDY = |ready;

endmodule


//-------------------------------------------
// A hierarchical CLA adder with built-in subtraction, or-ing, and and-ing
// status_decode : Verified
// a -- the first operand (32 bits)
// b -- the second operand (32 bits)
// subtract -- 1 if subtract b from a (1 bit)
// cout -- the carry out (1 bit)
// sum -- the sum (32 bits)
// orout -- the or of all the bits (32 bits)
// andout -- the and of all the bits (32 bits)
//-------------------------------------------
module CLAadder(a,b,subtract,cout,sum,orout, andout, cin);
	input [31:0] a,b;
	input subtract, cin;
	output [31:0] sum, orout, andout;
	output cout;
	//wires
	wire [3:0] gBus, pBus;
	wire [4:0] cBus;
	wire [31:0] bInput;
	
	
	genvar c;
	generate
	for (c = 0; c<32;c=c+1) begin: bInvertLoop
	// Set up the tri-state buffers to select b/n b and its inverse
	TriBuff bBuff(.in(b[c]), .oe(!subtract), .out(bInput[c]));
	TriBuff notBBuff(.in(!b[c]), .oe(subtract), .out(bInput[c]));
	end
	// Make the CLAblocks
	for (c = 0; c<4;c=c+1) begin: adderLoop
	CLAblock block(.a(a[8*c+7:8*c]),.b(bInput[8*c+7:8*c]),.cin(cBus[c]),.sum(sum[8*c+7:8*c]),.gout(gBus[c]),.pout(pBus[c]),.andout(andout[8*c+7:8*c]),.orout(orout[8*c+7:8*c]));
	end
	endgenerate
	assign cBus[0] = subtract|cin;
	assign cBus[1] = gBus[0]|pBus[0]&cBus[0];
	assign cBus[2] = gBus[1]|pBus[1]&gBus[0]|pBus[1]&pBus[0]&cBus[0];
	assign cBus[3] = gBus[2]|pBus[2]&gBus[1]|pBus[2]&pBus[1]&gBus[0]|pBus[2]&pBus[1]&pBus[0]&cBus[0];
	assign cBus[4] = gBus[3]|pBus[3]&gBus[2]|pBus[3]&pBus[2]&gBus[1]|pBus[3]&pBus[2]&pBus[1]&gBus[0]|pBus[3]&pBus[2]&pBus[1]&pBus[0]&cBus[0];
	assign cout = cBus[4];
endmodule

//*******************************************************************************************************************
//
//SECTION : Tertiary modules i.e. Mult, Div, Adder block, etc.
//
//*******************************************************************************************************************

//-----------------------------------------------
// A 32-bit pipelined divider that uses the naive method
// status_decode: Verified
// clk -- the clock signal for this module (1 bit wide)
// error_in -- an error signal in (1 bit wide)
// data_divisor -- the divisor (32 bits wide)
// data_dividend -- the dividend (32 bits wide)
// ctrl_begin -- begin division on the clock cycle (1 bit wide)
// data_ready -- indicates if a division cycle has been completed (1 bit wide)
// data_error -- indicates an error in the computation (1 bit wide)
// data_result -- the result of the division (32 bits wide)
//-----------------------------------------------
module PipelinedDivider(clk, error_in, data_divisor, data_dividend, ctrl_begin, data_ready, data_error, data_result);

	input clk,ctrl_begin,error_in;
	input [31:0] data_divisor, data_dividend;
	output data_ready, data_error;
	output [31:0] data_result;
	
	wire negateResult;	
	wire [31:0] alignedDivisor, errorIn,activeIn,negResultIn, flippedDivisor, flippedDividend, unflippedResult;
	wire[1023:0] quotientIn,divisorIn, dividendIn, originalDivisorIn;
	
	//2's compliment if negative
	CLAadder divisorSubtractor(.a(32'b0),.b(data_divisor),.subtract(data_divisor[31]),.sum(flippedDivisor));
	CLAadder dividendSubtractor(.a(32'b0),.b(data_dividend),.subtract(data_dividend[31]),.sum(flippedDividend));
	//Align the divisor
	OneAligner aligner(.data_in(flippedDivisor),.data_out(alignedDivisor));
	
	// Make the pipelined divider steps
	genvar c;
	generate
	for (c=0;c<32 ;c=c+1) begin: divisorStepLoop
	//Feed the first multiplier from inputs
	if(c==31) begin
	PipelinedDividerStep firstStep(.clk(clk),.data_quotient_in(1'b0),.data_divisor_in({1'b0,alignedDivisor[31:1]}),.data_dividend_in(flippedDividend),.data_original_divisor_in({1'b0,flippedDivisor[31:1]}),
	                    .data_error_in((!(|data_divisor)|error_in)&ctrl_begin),.data_active_in(ctrl_begin),.data_quotient_out(quotientIn[(c*32-1):(c-1)*32]),.data_divisor_out(divisorIn[(c*32-1):(c-1)*32]),
	.data_dividend_out(dividendIn[(c*32-1):(c-1)*32]),.data_original_divisor_out(originalDivisorIn[(c*32-1):(c-1)*32]),.data_error_out(errorIn[c-1]),.data_active_out(activeIn[c-1]),.ctrl_reset(1'b0),
	.ctrl_negResult_in(data_dividend[31]^data_divisor[31]),.ctrl_negResult_out(negResultIn[c-1]));
	end else if (c==0) begin
	//Make the final product step
	PipelinedDividerStep finalStep(.clk(clk), .data_quotient_in(quotientIn[((c+1)*32-1):c*32]), .data_divisor_in(divisorIn[((c+1)*32-1):c*32]),.data_dividend_in(dividendIn[((c+1)*32-1):c*32]), 
	                                   .data_original_divisor_in(originalDivisorIn[((c+1)*32-1):c*32]),.data_error_in(errorIn[c]), .data_active_in(activeIn[c]), .data_quotient_out(unflippedResult),
	           .data_error_out(data_error),.data_active_out(data_ready),.ctrl_reset(1'b0),.ctrl_negResult_in(negResultIn[c]),.ctrl_negResult_out(negateResult));	
	end
	//Make all the in-betweens
	else begin
	PipelinedDividerStep middleSteps(.clk(clk), .data_quotient_in(quotientIn[((c+1)*32-1):c*32]), .data_divisor_in(divisorIn[((c+1)*32-1):c*32]),.data_dividend_in(dividendIn[((c+1)*32-1):c*32]), 
	                                   .data_original_divisor_in(originalDivisorIn[((c+1)*32-1):c*32]),.data_error_in(errorIn[c]), .data_active_in(activeIn[c]), .data_quotient_out(quotientIn[(c*32-1):(c-1)*32]),.data_divisor_out(divisorIn[(c*32-1):(c-1)*32]),
	.data_dividend_out(dividendIn[(c*32-1):((c-1)*32)]),.data_original_divisor_out(originalDivisorIn[(c*32-1):(c-1)*32]),.data_error_out(errorIn[c-1]),.data_active_out(activeIn[c-1]),.ctrl_reset(1'b0),
	.ctrl_negResult_in(negResultIn[c]),.ctrl_negResult_out(negResultIn[c-1]));
	end
	end
	endgenerate
	
	//Flip the product if required
	CLAadder resultSubtractor(.a(32'b0),.b(unflippedResult),.subtract(negateResult),.sum(data_result));
	
endmodule

//-----------------------------------------------
// A step in the 32 bit pipelined divider.
// status_decode: Verified
// clk -- the clock signal for this module (1 bit wide)
// data_quotient_in -- the quotient of the previous stage.(32 bits wide)
// data_divisor_in -- The divisor for this stage.(32 bits wide)
// data_dividend_in -- The dividend for this stage (32 bits wide)
// data_original_divisor_in -- original divisor for the module shifted right one bit (32 bits wide)
// data_error_in -- the old error signal (1 bit wide)
// data_active_in -- the old signal indicating if an operation is in progress in the current step (1 bit wide)
// data_quotient_out -- the output quotient of the division (32 bits wide)
// data_divisor_out -- the new divisor out for the next stage (32 bits wide)
// data_dividend_out -- the new dividend for the next stage (32 bits wide)
// data_original_divisor_out -- the original divisor for the module (32 bits wide)
// data_error_out -- the error signal for the stages (1 bit wide)
// data_active_out -- a bit indicating whether an active operation is being used in the step (1 bit wide)
// ctrl_reset -- reset the divider (1 bit wide)
// ctrl_negResult_in -- a bit indicating if the final result should be negative (1 bit)
// ctrl_negResult_out -- a bit indicating if the final result should be negative (1 bit out)
//-----------------------------------------------
module PipelinedDividerStep(clk, data_quotient_in, data_divisor_in, data_dividend_in, data_original_divisor_in,data_error_in,data_active_in,
                            data_quotient_out,data_divisor_out,data_dividend_out,data_original_divisor_out,data_error_out,data_active_out,ctrl_reset, ctrl_negResult_in,ctrl_negResult_out); 

	input clk, data_error_in, data_active_in,ctrl_reset,ctrl_negResult_in;
	input [31:0] data_quotient_in, data_divisor_in, data_dividend_in, data_original_divisor_in;
	output data_error_out,data_active_out, ctrl_negResult_out;
	output [31:0] data_quotient_out,data_divisor_out,data_dividend_out,data_original_divisor_out;
	
	wire [31:0] setDivisor,setRemainder, setQuotient, subtractionOut, selectedRemainder;
	wire divisorEqual;
	
	// Find out if the current divisor is equal to the original divisor shifted by 1 (indicating we should stop dividing)
	EqualsCheck equalsCheck(.data_a(data_divisor_in),.data_b(data_original_divisor_in),.data_isEquals(divisorEqual));
	
	// Perform subtraction with the divisor and remainder
	CLAadder divisorSubtractor(.a(data_dividend_in),.b(data_divisor_in),.subtract(1'b1),.sum(subtractionOut));
	// Select between the new and old remainder based on the sign of the result of the subtraction
	Mux2b32w subtractionMux(.inA(data_dividend_in),.inB(subtractionOut),.out(selectedRemainder),.select(subtractionOut[31]));

	
	// Make muxes to not set divisor, remainder, or quotient with new values if the data are equal
	Mux2b32w divisorMux(.inA(data_divisor_in), .inB({1'b0,data_divisor_in[31:1]}), .out(setDivisor), .select(divisorEqual));
	Mux2b32w remainderMux(.inA(data_dividend_in),.inB(selectedRemainder),.out(setRemainder),.select(divisorEqual));
	Mux2b32w quotientMux(.inA(data_quotient_in),.inB({data_quotient_in[30:0],!subtractionOut[31]}),.out(setQuotient),.select(divisorEqual));
	
	// Make the active and error and negative DFFs
	DFlip activeFlip(.data(data_active_in),.clk(clk),.reset(ctrl_reset),.out(data_active_out),.enable(1'b1));
	DFlip errorFlip(.data(data_error_in),.clk(clk),.reset(ctrl_reset),.out(data_error_out),.enable(1'b1));
	DFlip negFlip(.data(ctrl_negResult_in),.clk(clk),.reset(ctrl_reset),.out(ctrl_negResult_out),.enable(1'b1));
	
	genvar c;
	generate
	for (c=0;c<32;c=c+1) begin: divisionFlopLoop
	// Make the DFF to hold the divisor
	DFlip divisorDff(.data(setDivisor[c]),.clk(clk),.reset(ctrl_reset),.out(data_divisor_out[c]),.enable(data_active_in));
	// Make the DFF to hold the remainder
	DFlip remainderFlip(.data(setRemainder[c]),.clk(clk),.reset(ctrl_reset),.out(data_dividend_out[c]),.enable(data_active_in));
	// Make the DFF to hold the quotient
	DFlip quotientFlip(.data(setQuotient[c]),.clk(clk),.reset(ctrl_reset),.out(data_quotient_out[c]),.enable(data_active_in));
	// Make the DFF to hold the old divisor
	DFlip oldDivisorFlip(.data(data_original_divisor_in[c]),.clk(clk),.reset(ctrl_reset),.out(data_original_divisor_out[c]),.enable(data_active_in));
	end
	endgenerate	 
endmodule

//-----------------------------------------------
// A 32-bit pipelined multiplier that uses booth's modified encoding. Takes 32 cycles
// status_decode: Verified
// clk -- the clock signal for this module (1 bit wide)
// error_in -- error input signal (1 bit wide)
// data_multiplier -- the multiplier (32 bits wide)
// data_multiplicand -- the multiplicand (32 bits wide)
// ctrl_begin -- begin multiplication on the clock cycle (1 bit wide)
// data_ready -- indicates if a multiplication cycle has been completed (1 bit wide)
// data_error -- indicates an error in the computation (1 bit wide)
// data_result -- the result of the multiplication (32 bits wide)
//-----------------------------------------------
module PipelinedBoothMultiplier(clk,error_in,data_multiplier, data_multiplicand, ctrl_begin, data_ready, data_error, data_result);
	input clk,ctrl_begin,error_in;
	input [31:0] data_multiplier, data_multiplicand;
	output data_ready, data_error;
	output [31:0] data_result;
	
	
	wire[1023:0] multMultiplierIn,multMultiplicandIn;
	wire[1023:0] multProdIn;
	wire [63:0] multBoothsIn;
	wire [31:0] multErrorIn,multActiveIn;
	wire[63:0] finalResult;
	wire errorWire;
	// Make the pipelined multiplier steps
	genvar c;
	generate
	for (c=0;c<32 ;c=c+1) begin: multStepLoop
	//Feed the first multiplier from inputs
	if(c==31) begin
	PipelinedMultiplierStep firstStep(.clk(clk),.data_product_in(32'b0),.data_multiplier_in(data_multiplier),.data_multiplicand_in(data_multiplicand),
	                                 .data_boothBits_in({data_multiplier[0],1'b0}),.data_error_in(error_in),.data_active_in(ctrl_begin),.data_product_out(multProdIn[(c*32-1):(c-1)*32]),
	.data_multiplier_out(multMultiplierIn[(c*32-1):(c-1)*32]),.data_multiplicand_out(multMultiplicandIn[(c*32-1):(c-1)*32]),.data_boothBits_out(multBoothsIn[(c*2-1):(c-1)*2]),
	.data_error_out(multErrorIn[c-1]),.data_active_out(multActiveIn[c-1]));
	end else if (c==0) begin
	//Make the final product step
	PipelinedMultiplierStep finalStep(.clk(clk),.data_product_in(multProdIn[31:0]),.data_multiplier_in(multMultiplierIn[31:0]),.data_multiplicand_in(multMultiplicandIn[31:0]),
	                                 .data_boothBits_in(multBoothsIn[1:0]),.data_error_in(multErrorIn[0]),.data_active_in(multActiveIn[0]),.data_full_product(finalResult),
	.data_error_out(errorWire),.data_active_out(data_ready));
	
	end
	//Make all the in-betweens
	else begin
	PipelinedMultiplierStep multStep(.clk(clk), .data_product_in(multProdIn[((c+1)*32-1):c*32]), .data_multiplier_in(multMultiplierIn[((c+1)*32-1):c*32]),.data_multiplicand_in(multMultiplicandIn[((c+1)*32-1):c*32]), 
	                                .data_boothBits_in(multBoothsIn[((c+1)*2-1):c*2]),.data_error_in(multErrorIn[c]), .data_active_in(multActiveIn[c]), .data_product_out(multProdIn[(c*32-1):(c-1)*32]), 
	.data_multiplier_out(multMultiplierIn[(c*32-1):(c-1)*32]), .data_multiplicand_out(multMultiplicandIn[(c*32-1):(c-1)*32]), 
	.data_boothBits_out(multBoothsIn[(c*2-1):(c-1)*2]), .data_error_out(multErrorIn[c-1]), .data_active_out(multActiveIn[c-1]));
	end
	end
	endgenerate
	// An error will be thrown if there was an error in the computation or if there was overflow with the results of the computation
	assign data_error = errorWire|(|finalResult[63:32]&~&finalResult[63:32]);
	assign data_result = finalResult[31:0];
	
endmodule

//-----------------------------------------------
// A step in the 32 bit pipelined multiplier. Note that in internal error checking, we don't care about overflow as that will be found by the greater multiplication module
// status_decode: Verified
// clk -- the clock signal for this module (1 bit wide)
// data_product_in -- the product of the previous stage.(32 bits wide)
// data_multiplier_in -- The multiplier for this stage.(32 bits wide)
// data_multiplicand_in -- The multiplicand for this stage. Assumed to be adjusted by the previous stage (32 bits wide)
// data_boothBits_in -- the last 2 bits of the old multiplier combined with the LSB of the old booth bits (2 bits wide)
// data_error_in -- the old error signal (1 bit wide)
// data_active_in -- the old signal indicating if an operation is in progress in the current step (1 bit wide)
// data_product_out -- the output of the product of multiplication (32 bits wide)
// data_multiplicand_out -- the new multiplicand out for the next stage (32 bits wide)
// data_multiplier_out -- the new multiplier for the next stage (32 bits wide)
// data_boothBits_out -- the booth bits to be used by the next stage (2 bits wide)
// data_error_out -- the error signal for the stages (1 bit wide)
// data_active_out -- a bit indicating whether an active operation is being used in the step (1 bit wide)
// data_full_product-- the final product of the multiplication
//-----------------------------------------------
module PipelinedMultiplierStep(clk, data_product_in, data_multiplier_in,data_multiplicand_in, data_boothBits_in,data_error_in, data_active_in, data_product_out, data_multiplier_out,
	data_multiplicand_out, data_boothBits_out, data_error_out, data_active_out, data_full_product,ctrl_reset);
	input clk,ctrl_reset,data_error_in, data_active_in;
	input [31:0] data_multiplier_in,data_multiplicand_in;
	input [31:0] data_product_in;
	input [1:0] data_boothBits_in;
	output data_error_out, data_active_out;
	output [63:0] data_full_product;
	output [31:0] data_multiplier_out, data_multiplicand_out;
	output [31:0] data_product_out;
	output [1:0] data_boothBits_out;
	
	wire [31:0] productOut,multiplierOut;
	wire [31:0] adjustedMultiplier,addedProduct;
	
	wire sig_shift_select;
	wire sig_subtract;
	
	// Create the shifted versions of the multiplicand. Choose between shifted/unshifted/0 and + or -
	Mux2b32w multiplicandSelecter(.inA(data_multiplicand_in), .inB(32'b0),.out(adjustedMultiplier), .select(sig_shift_select));
	// Feed the shifted versions into the adder
	CLAadder productAdder(.a(data_product_in),.b(adjustedMultiplier),.subtract(sig_subtract),.sum(addedProduct));
	
	genvar c;
	generate
	for (c=0;c<32;c=c+1) begin: productLoop
	// Make the DFF to hold the product
	DFlip productDff(.data(addedProduct[c]),.clk(clk),.reset(ctrl_reset),.out(productOut[c]),.enable(data_active_in));
	// Make the DFF to hold the multiplier
	DFlip multiplierFlip(.data(data_multiplier_in[c]),.clk(clk),.reset(ctrl_reset),.out(multiplierOut[c]),.enable(data_active_in));
	// Make the DFF to hold the multiplicand
	DFlip multiplicandFlip(.data(data_multiplicand_in[c]),.clk(clk),.reset(ctrl_reset),.out(data_multiplicand_out[c]),.enable(data_active_in));
	end
	endgenerate
	// Make the active and error DFFs
	DFlip activeFlip(.data(data_active_in),.clk(clk),.reset(ctrl_reset),.out(data_active_out),.enable(1'b1));
	// Register an error if the signs of the input were the same but the sign of the output flipped. i.e. overflow
	DFlip errorFlip(.data(data_error_in),
	               .clk(clk),.reset(ctrl_reset),.out(data_error_out),.enable(1'b1));
	// Create the product out signals
	assign data_product_out = {productOut[31],productOut[31:1]};
	assign data_multiplier_out = {productOut[0],multiplierOut[31:1]};
	assign data_boothBits_out = {multiplierOut[1:0]};
	assign data_full_product = {productOut[31],productOut,multiplierOut[31:1]};
	// Make the control unit signals
	assign sig_subtract = data_boothBits_in[1]&!data_boothBits_in[0];
	assign sig_shift_select = !data_boothBits_in[1]&data_boothBits_in[0]|data_boothBits_in[1]&!data_boothBits_in[0];
	
endmodule
 

//-------------------------------------------
// An 8-bit CLAblock
// status_decode : Verified
// a -- the first input to add (8 bits wide)
// b -- the second input to add (8 bits wide)
// cin -- the carry in (1 bit wide)
// sum -- the sum (8 bits wide)
// gout -- the block's generate function (1 bit wide)
// pout -- the block's propogate function (1 bit wide)
// cout -- the carry out bit (1 bit wide)
// andout -- the and of individual bits (8 bits wide)
// orout -- the or of individual bits (8 bits wide)
//-------------------------------------------
module CLAblock(a,b,cin,sum,gout,pout,cout, andout, orout);
	input [7:0] a,b;
	input cin;
	output cout,gout,pout;
	output [7:0] sum, andout, orout;
	// Declare any buses needed for the component outputs
	wire [7:0] p, g;
	wire [8:0] c;
	// Make the generates and propogates
	genvar v;
	generate
	for (v = 0; v < 8; v = v + 1) begin: claloop
	assign g[v] = a[v]&b[v];
	assign p[v] = a[v]|b[v];
	xor(sum[v],c[v],a[v],b[v]);
	end
	endgenerate
	//Create the adder carry logic
	assign c[0] = cin;
	assign c[1] = g[0]|p[0]&c[0];
	assign c[2] = g[1]|p[1]&g[0]|p[1]&p[0]&c[0];
	assign c[3] = g[2]|p[2]&g[1]|p[2]&p[1]&g[0]|p[2]&p[1]&p[0]&c[0];
	assign c[4] = g[3]|p[3]&g[2]|p[3]&p[2]&g[1]|p[3]&p[2]&p[1]&g[0]|p[3]&p[2]&p[1]&p[0]&c[0];
	assign c[5] = g[4]|p[4]&g[3]|p[4]&p[3]&g[2]|p[4]&p[3]&p[2]&g[1]|p[4]&p[3]&p[2]&p[1]&g[0]|p[4]&p[3]&p[2]&p[1]&p[0]&c[0];
	assign c[6] = g[5]|p[5]&g[4]|p[5]&p[4]&g[3]|p[5]&p[4]&p[3]&g[2]|p[5]&p[4]&p[3]&p[2]&g[1]|p[5]&p[4]&p[3]&p[2]&p[1]&g[0]|p[5]&p[4]&p[3]&p[2]&p[1]&p[0]&c[0];
	assign c[7] = g[6]|p[6]&g[5]|p[6]&p[5]&g[4]|p[6]&p[5]&p[4]&g[3]|p[6]&p[5]&p[4]&p[3]&g[2]|p[6]&p[5]&p[4]&p[3]&p[2]&g[1]|p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&g[0]|p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&p[0]&c[0];
	assign c[8] = g[7]|p[7]&g[6]|p[7]&p[6]&g[5]|p[7]&p[6]&p[5]&g[4]|p[7]&p[6]&p[5]&p[4]&g[3]|p[7]&p[6]&p[5]&p[4]&p[3]&g[2]|p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&g[1]|p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&g[0]|
	             p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&p[0]&c[0];
	
	assign cout = c[8];
	assign pout = p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&p[0];
	assign gout = c[8];
	assign andout = g;
	assign orout = p;
endmodule


//-------------------------------------------
// A SRA operator
// status_decode : Verified
// data -- the data to shift (32 bits)
// shamt -- the amount to shift by (5 bits)
// out -- the output data
//-------------------------------------------
module SRA32b(data, shamt,out);
	input [31:0] data;
	input [4:0] shamt;
	output [31:0] out;
	
	wire [31:0] shift16, shift8, shift4, shift2, shift1;
	Mux2b32w shift16mux(.inA({{16{data[31]}},{data[31:16]}}),.inB(data), .out(shift16), .select(shamt[4]));
	Mux2b32w shift8mux(.inA({{8{shift16[31]}},{shift16[31:8]}}),.inB(shift16), .out(shift8), .select(shamt[3]));
	Mux2b32w shift4mux(.inA({{4{shift8[31]}},{shift8[31:4]}}),.inB(shift8), .out(shift4),.select(shamt[2]));
	Mux2b32w shift2mux(.inA({{2{shift4[31]}},{shift4[31:2]}}),.inB(shift4), .out(shift2),.select(shamt[1]));
	Mux2b32w shiftmux(.inA({{1{shift2[31]}},{shift2[31:1]}}),.inB(shift2),.out(out),.select(shamt[0]));
endmodule


//-------------------------------------------
// A SLL operator
// status_decode : Verified
// data -- the data to shift (32 bits)
// shamt -- the amount to shift by (5 bits)
// out -- the output data
//-------------------------------------------
module SLL32b(data, shamt,out);
	input [31:0] data;
	input [4:0] shamt;
	output [31:0] out;
	
	wire [31:0] shift16, shift8, shift4, shift2, shift1;
	Mux2b32w shift16mux(.inA({{data[15:0]},{16'b0}}),.inB(data), .out(shift16), .select(shamt[4]));
	Mux2b32w shift8mux(.inA({{shift16[23:0]},{8'b0}}),.inB(shift16), .out(shift8), .select(shamt[3]));
	Mux2b32w shift4mux(.inA({{shift8[27:0]},{4'b0}}),.inB(shift8), .out(shift4),.select(shamt[2]));
	Mux2b32w shift2mux(.inA({{shift4[29:0]},{2'b0}}),.inB(shift4), .out(shift2),.select(shamt[1]));
	Mux2b32w shiftmux(.inA({{shift2[30:0]},{1'b0}}),.inB(shift2),.out(out),.select(shamt[0]));
endmodule


//*******************************************************************************************************************
//
//SECTION : Accesory modules i.e. Multiplexers, Encoders, Buffers
//
//*******************************************************************************************************************

//-----------------------------------------------
// A module that shifts an entire number so its first incidence of a 1 is its MSB
// status_decode: Verified
// data_in: the input number (32 bits wide)
// data_out: the output adjusted number (32 bits wide)
//-----------------------------------------------
module OneAligner(data_in,data_out);

	input [31:0] data_in;
	output [31:0] data_out;
	
	wire [31:0] thermometerData;
	wire [5:0] shiftCount;
	// Make the thermometer encoded input
	ThermometerPrefixEncoder thermEncoder(.data_in(data_in),.data_out(thermometerData));
	// Convert the thermometer prefix into a binary count of required shifts
	ThermometerToBinary thermBinary(.data_in(thermometerData),.data_out(shiftCount));
	// Shift the number accordingly
	SLL32b shifter(.data(data_in),.shamt(shiftCount),.out(data_out));
endmodule


//-------------------------------------------
// A module that returns 1 if the input is equal to 0
// status_decode : Verified
// data -- the data to check (32 bits)
// out -- a bit indicating if input is equal to 0(1 bit)
//-------------------------------------------
module NotZeroCheck(data,out);
	input [31:0] data;
	output out;
	wire [31:0] tempBus;
	assign tempBus[0] = data[0];
	genvar c;
	generate
	for (c = 1; c<32;c=c+1) begin: bInvertLoop
	assign tempBus[c] = data[c]|tempBus[c-1];
	end
	endgenerate
	assign out = tempBus[31];
endmodule

//-----------------------------------------------
// A module that returns true if the two inputs are equal
// status_decode: Verified
// data_a: first operand (32 bits wide)
// data_b: second operand (32 bits wide)
// data_isEquals indication if a=b (1 bit wide)
//-----------------------------------------------
module EqualsCheck(data_a,data_b,data_isEquals);

	input [31:0] data_a, data_b;
	output data_isEquals;
	
	wire [31:0] equalsWire;
	
	genvar c;
	generate
	for (c=0;c<32 ;c=c+1) begin: equalsLoop
	assign equalsWire[c] = data_a[c] ~^ data_b[c];
	end
	endgenerate
	
	assign data_isEquals = &equalsWire;

endmodule

//-----------------------------------------------
// Inverted thermometer to binary encoder
// status_decode: Verified
// data_in -- input inverted thermometer code (32 bits wide)
// data_out -- output binary-encoding of # of 0's before 1 (6 bits wide)
//-----------------------------------------------
module ThermometerToBinary(data_in,data_out);

	input [0:31] data_in;
	output [5:0] data_out;
	//Compiler will minimize this ugliness
	assign data_out[0] = (data_in[0]&!data_in[1])|(data_in[2]&!data_in[3])|(data_in[4]&!data_in[5])|(data_in[6]&!data_in[7])|(data_in[8]&!data_in[9])|
	                    (data_in[10]&!data_in[11])|(data_in[12]&!data_in[13])|(data_in[14]&!data_in[15])|(&data_in[16]&!data_in[17])|(data_in[18]&!data_in[19])
	|(data_in[20]&!data_in[21])|(data_in[22]&!data_in[23])|(data_in[24]&!data_in[25])|(data_in[26]&!data_in[27])|(data_in[28]&!data_in[29])
	|(data_in[30]&!data_in[31]);
	assign data_out[1] = (data_in[1]&!data_in[2])|(data_in[2]&!data_in[3])|(data_in[5]&!data_in[6])|(data_in[6]&!data_in[7])|(data_in[9]&!data_in[10])|
	                    (data_in[10]&!data_in[11])|(data_in[13]&!data_in[14])|(data_in[14]&!data_in[15])|(&data_in[17]&!data_in[18])|(data_in[18]&!data_in[19])
	|(data_in[21]&!data_in[22])|(data_in[22]&!data_in[23])|(data_in[25]&!data_in[26])|(data_in[26]&!data_in[27])|(data_in[29]&!data_in[30])
	|(data_in[30]&!data_in[31]);
	assign data_out[2] = (data_in[3]&!data_in[4])|(data_in[4]&!data_in[5])|(data_in[5]&!data_in[6])|(data_in[6]&!data_in[7])|(data_in[11]&!data_in[12])|
	                    (data_in[12]&!data_in[13])|(data_in[13]&!data_in[14])|(data_in[14]&!data_in[15])|(&data_in[19]&!data_in[20])|(data_in[20]&!data_in[21])
	|(data_in[21]&!data_in[22])|(data_in[22]&!data_in[23])|(data_in[27]&!data_in[28])|(data_in[28]&!data_in[29])|(data_in[29]&!data_in[30])
	|(data_in[30]&!data_in[31]);
	assign data_out[3] = (data_in[7]&!data_in[8])|(data_in[8]&!data_in[9])|(data_in[9]&!data_in[10])|(data_in[10]&!data_in[11])|(data_in[11]&!data_in[12])|
	                    (data_in[12]&!data_in[13])|(data_in[13]&!data_in[14])|(data_in[14]&!data_in[15])|(&data_in[23]&!data_in[24])|(data_in[24]&!data_in[25])
	|(data_in[25]&!data_in[26])|(data_in[26]&!data_in[27])|(data_in[27]&!data_in[28])|(data_in[28]&!data_in[29])|(data_in[29]&!data_in[30])
	|(data_in[30]&!data_in[31]);	
	assign data_out[4] = (data_in[15]&!data_in[16])|(data_in[16]&!data_in[17])|(data_in[17]&!data_in[18])|(data_in[18]&!data_in[19])|(data_in[19]&!data_in[20])|
	                    (data_in[20]&!data_in[21])|(data_in[21]&!data_in[22])|(data_in[22]&!data_in[23])|(&data_in[23]&!data_in[24])|(data_in[24]&!data_in[25])
	|(data_in[25]&!data_in[26])|(data_in[26]&!data_in[27])|(data_in[27]&!data_in[28])|(data_in[28]&!data_in[29])|(data_in[29]&!data_in[30])
	|(data_in[30]&!data_in[31]);
	assign data_out[5] = &data_in[31];

endmodule

//-----------------------------------------------
// Thermometer prefix encoder
// status_decode: Verified
// data_in -- input value (32 bits wide)
// data_out -- thermometer-encoded prefix encoded output (32 bits wide)
//-----------------------------------------------
module ThermometerPrefixEncoder(data_in,data_out);
	input [31:0] data_in;
	output [31:0] data_out;
	
	genvar c,d;
	generate
	for (c=0;c<32;c=c+1) begin: prefixLoop
	assign data_out[c] = !(|data_in[31:c]);
	end	
	endgenerate
	
endmodule

//-----------------------------------------------
// A 2-1 mux. Select high selects the MSB of the input
// status_decode : Verified
// in --  input (2 bits wide)
// out -- output (1 bit wide)
// select -- select signal (1 bit wide)
//-----------------------------------------------
module Mux2b(in,out,select);
	input [1:0] in;
	input select;
	output out;
	
	assign out = (select&in[1])|(!select&in[0]);

endmodule

//-----------------------------------------------
// A 4-1 mux
// status_decode : Verified
// in --  input (4 bits wide)
// out -- output (1 bit wide)
// select -- select signal (2 bit wide)
//-----------------------------------------------
module Mux4b(in,out,select);

	input [3:0] in;
	input [1:0] select;
	output out;
	
	wire [1:0] interWire;
	
	Mux2b muxa(.in(in[3:2]),.out(interWire[1]),.select(select[0]));
	Mux2b muxb(.in(in[1:0]),.out(interWire[0]),.select(select[0]));
	Mux2b muxc(.in(interWire),.out(out),.select(select[1]));

endmodule

//-----------------------------------------------
// A 8-1 mux
// status_decode : Unverified
// in --  input (4 bits wide)
// out -- output (1 bit wide)
// select -- select signal (2 bit wide)
//-----------------------------------------------
module Mux8b(in,out,select);

	input [7:0] in;
	input [3:0] select;
	output out;
	
	wire [1:0] interWire;
	
	Mux4b muxa(.in(in[7:4]),.out(interWire[1]),.select(select[1:0]));
	Mux4b muxb(.in(in[3:0]),.out(interWire[0]),.select(select[1:0]));
	Mux2b muxc(.in(interWire),.out(out),.select(select[2]));

endmodule


//-----------------------------------------------
// A synchronous clear D-Flip Flop
// status_decode : Verified
// data -- data input (1 bit wide)
// clk -- clock signal (1 bit wide)
// reset -- synchronous reset signal (1 bit wide)
// out -- output signal (1 bit wide)
// enable -- write enable signal (1 bit wide)
//-----------------------------------------------
module DFlip(data,clk,reset,out,enable);
	input data, clk, reset, enable;
	output out;
	reg out;
	
	wire w0;
	
	Mux2b enableMux(.in({data,out}),.out(w0),.select(enable));
	
	always @(posedge clk) begin
	if(reset) begin
	out = 1'b0;
	end else begin
	out = w0;
	end
	end
endmodule


//-----------------------------------------------
// A 2-1 32-bit wide mux. Select high selects A
// status_decode : Verified
// inA --  input A (32 bits wide)
// inB -- input B (32 bits wide)
// out -- output (32 bits wide)
// select -- select signal (1 bit wide)
//-----------------------------------------------
module Mux2b32w(inA, inB, out, select);
	
	input [31:0] inA, inB;
	input select;
	output [31:0] out;
	
	genvar c;
	generate
	for(c = 0;c<32;c=c+1) begin: bigMuxLoop
	assign out[c] = (!select&inB[c])|(select&inA[c]);
	end
	endgenerate
	
endmodule

//-----------------------------------------------
// A 4-1 32-bit wide mux. 
// status_decode : Unverified
// inA --  input A (16 bits wide)
// inB -- input B (16 bits wide)
// inC -- input C (16 bits wide)
// inD -- input D (16 bits wide)
// out -- output (16 bits wide)
// select -- select signal (2 bits wide)
//-----------------------------------------------
module Mux4b32w(inA, inB, inC, inD, out, select);
	
	input [31:0] inA, inB, inC, inD;
	input [1:0] select;
	output [31:0] out;
	
	genvar c;
	generate
	for(c = 0;c<32;c=c+1) begin: bigMuxLoop
	Mux4b mux(.in({inA[c],inB[c],inC[c],inD[c]}),.out(out[c]),.select(select));
	end
	endgenerate
	
endmodule
//-----------------------------------------------
// A 8-1 32-bit wide mux. 
// status_decode : Unverified
// inA --  input A (16 bits wide)
// inB -- input B (16 bits wide)
// inC -- input C (16 bits wide)
// inD -- input D (16 bits wide)
//E
//F
//G
//H
// out -- output (16 bits wide)
// select -- select signal (2 bits wide)
//-----------------------------------------------
module Mux8b32w(inA, inB, inC, inD, inE, inF, inG, inH, out, select);
	
	input [31:0] inA, inB, inC, inD, inE, inF, inG, inH;
	input [2:0] select;
	output [31:0] out;
	
	genvar c;
	generate
	for(c = 0;c<32;c=c+1) begin: bigMuxLoop
	Mux8b mux(.in({inA[c],inB[c],inC[c],inD[c],inE[c],inF[c],inG[c],inH[c]}),.out(out[c]),.select(select));
	end
	endgenerate
	
endmodule

//-----------------------------------------------
// A 32-bit wide tri-state buffer
// status_decode : Verified
// in -- input signal (32 bits wide)
// out -- output signal (32 bits wide)
// oe -- output enable (1 bit wide)
//-----------------------------------------------
module TriBuff32(in,oe,out);
	input oe;
	input [31:0] in;
	output [31:0] out;
	
	genvar c;
	generate
	for(c = 0;c<32;c=c+1) begin: triLoop
	TriBuff buff(.in(in[c]),.oe(oe),.out(out[c]));
	end
	endgenerate
endmodule

//-----------------------------------------------
// A tri-state buffer
// status_decode : Verified
// in -- input signal (1 bit wide)
// oe -- output enable (1 bit wide)
// out -- output (1 bit wide)
//-----------------------------------------------
module TriBuff(in, oe, out);
	input in, oe;
	output out;
	
	assign out = oe ? in : 1'bz;
endmodule

// ----------------------------------------------
// A 5->32 bit decoder
// status_decode : Verified
// in - binary input (5 bits wide)
// out - binary output (32 bits wide)
//-----------------------------------------------
module Dec5b(in,out);

	input [4:0] in;
	output [31:0] out;
	wire [3:0] decEnable;
	
	
	Dec2b enableDec(.in(in[4:3]),.out(decEnable),.enable(1'b1));
	Dec3b dec0(.in(in[2:0]),.out(out[7:0]),.enable(decEnable[0]));
	Dec3b dec1(.in(in[2:0]),.out(out[15:8]),.enable(decEnable[1]));
	Dec3b dec2(.in(in[2:0]),.out(out[23:16]),.enable(decEnable[2]));
	Dec3b dec3(.in(in[2:0]),.out(out[31:24]),.enable(decEnable[3]));
	
endmodule
//-----------------------------------------------
// A 2->4 bit decoder
// status_decode : Verified
// in - binary input (2 bits wide)
// out - binary output (4 bits wide)
// enable - enable signal (1 bit wide)
//-----------------------------------------------
module Dec2b(in,out,enable);
	
	input [1:0] in;
	input enable;
	output [3:0] out;
	
	assign out[0] = enable&!in[0]&!in[1];
	assign out[1] = enable&in[0]&!in[1];
	assign out[2] = enable&!in[0]&in[1];
	assign out[3] = enable&in[0]&in[1];
	
endmodule
//-----------------------------------------------
// A 3->8 bit decoder
// status_decode : Verified
// in - binary input (3 bits wide)
// out - binary output (8 bits wide)
// enable - enable signal
//-----------------------------------------------
module Dec3b(in,out,enable);

	input [2:0] in;
	input enable;
	output [7:0] out;
	
	
	assign out[0] = enable&!in[0]&!in[1]&!in[2];
	assign out[1] = enable&in[0]&!in[1]&!in[2];
	assign out[2] = enable&!in[0]&in[1]&!in[2];
	assign out[3] = enable&in[0]&in[1]&!in[2];
	assign out[4] = enable&!in[0]&!in[1]&in[2];
	assign out[5] = enable&in[0]&!in[1]&in[2];
	assign out[6] = enable&!in[0]&in[1]&in[2];
	assign out[7] = enable&in[0]&in[1]&in[2];
	
endmodule

