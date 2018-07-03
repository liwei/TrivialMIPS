`include "cpu_defs.svh"

module cpu_id(
	input  rst,
	input  InstAddr_t pc,
	input  Inst_t     inst,

	input  Word_t     reg1_i,
	input  Word_t     reg2_i,

	output RegAddr_t  reg_raddr1,
	output RegAddr_t  reg_raddr2,

	// safe register values
	output Word_t     safe_rs,
	output Word_t     safe_rt,

	output Oper_t     op,
	output Word_t     reg1_o,
	output Word_t     reg2_o,
	// whether to write register
	output Bit_t      reg_we,
	// the address of register to be written
	output RegAddr_t  reg_waddr,

	input  RegWriteReq_t ex_wr,
	input  RegWriteReq_t mem_wr
);

// 6-bit primary operation code
logic [5:0] opcode;
// 5-bit specifier for the source/destination/target register
RegAddr_t rs, rd, rt;
// 16-bit immediate
HalfWord_t immediate;
// 26-bit index shifted left two bits to supply the low-order 28 bits of the jump target address
logic [25:0] instr_index;
// 5-bit shift amount
logic [4:0] sa;
// 6-bit function field used to specify functions within the primary opcode SPECIAL
logic [5:0] funct;

assign opcode = inst[31:26];
assign rs = inst[25:21];
assign rt = inst[20:16];
assign rd = inst[15:11];
assign immediate = inst[15:0];
assign instr_index = inst[25:0];
assign sa = inst[10:6];
assign funct = inst[5:0];

InstAddr_t safe_reg1, safe_reg2;
assign reg_raddr1 = rs;
assign reg_raddr2 = rt;
assign safe_rs = safe_reg1;
assign safe_rt = safe_reg2;

// the zero-extended/signed-extended immediate
Word_t imm_zero_ext, imm_signed_ext;
assign imm_zero_ext   = { 16'h0, immediate };
assign imm_signed_ext = { {16{immediate[15]}}, immediate };

// deal with the harzard
always_comb
begin
	if(rst == 1'b1)
	begin
		safe_reg1 = `ZERO_WORD;
	end else if(ex_wr.we && ex_wr.waddr == reg_raddr1) begin
		safe_reg1 = ex_wr.wdata;
	end else if(mem_wr.we && mem_wr.waddr == reg_raddr1) begin
		safe_reg1 = mem_wr.wdata;
	end else begin
		safe_reg1 = reg1_i;
	end

	if(rst == 1'b1)
	begin
		safe_reg2 = `ZERO_WORD;
	end else if(ex_wr.we && ex_wr.waddr == reg_raddr2) begin
		safe_reg2 = ex_wr.wdata;
	end else if(mem_wr.we && mem_wr.waddr == reg_raddr2) begin
		safe_reg2 = mem_wr.wdata;
	end else begin
		safe_reg2 = reg2_i;
	end
end

/* immediate (I-Type) instructions */
Oper_t op_type_i;
Bit_t unsigned_imm_type_i;
id_type_i id_type_i_instance(
	.opcode,
	.op(op_type_i),
	.unsigned_imm(unsigned_imm_type_i)
);

/* jump (J-Type) instructions */
Oper_t op_type_j;
id_type_j id_type_j_instance(
	.opcode,
	.op(op_type_j)
);

always_comb
begin
	if(op_type_i != OP_INVALID)
	begin
		op = op_type_i;
		reg1_o = safe_rs;
		reg2_o = unsigned_imm_type_i ? imm_zero_ext : imm_signed_ext;
		reg_we = 1'b1;
		reg_waddr = rt;
	end else if(op_type_j != OP_INVALID) begin
		op = op_type_j;
		reg1_o = `ZERO_WORD;
		reg2_o = `ZERO_WORD;

		// only two instructions: J (6'b000010) and JAL (6'b000011)
		// for J,   no write operation
		// for JAL, $31 <- $pc+8
		reg_we = opcode[0];
		reg_waddr = 5'd31;
	end else begin
		op = OP_INVALID;
		reg1_o = `ZERO_WORD;
		reg2_o = `ZERO_WORD;
		reg_we = 1'b0;
		reg_waddr = `ZERO_WORD;
	end
end

endmodule
