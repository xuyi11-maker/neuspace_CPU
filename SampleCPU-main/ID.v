`include "lib/defines.vh"  // 引入预定义的宏文件
module ID(
    input wire clk,  // 时钟信号
    input wire rst,  // 复位信号
    input wire [`StallBus-1:0] stall,  // 流水线暂停控制信号
    
    output wire stallreq_for_id,  // ID阶段的暂停请求
    
    output wire stallreq,  // 总的暂停请求信号
    
    input wire [37:0] ex_to_id_bus,  // EX阶段传递到ID阶段的总线数据
    
    input wire [37:0] mem_to_id_bus,  // MEM阶段传递到ID阶段的总线数据
    
    input wire [37:0] wb_to_id_bus,  // WB阶段传递到ID阶段的总线数据
    
    input wire [65:0] ex_to_id_2,  // EX阶段第二条数据总线
    
    input wire[65:0] mem_to_id_2,   // MEM阶段第二条数据总线
    
    input wire[65:0] wb_to_id_2,   // WB阶段第二条数据总线

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,  // IF阶段传递到ID阶段的总线数据

    input wire [31:0] inst_sram_rdata,  // 从SRAM读取的指令

    input wire inst_is_load,  // 当前指令是否为加载指令

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,  // WB阶段传递到寄存器文件的总线数据

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,  // ID阶段传递到EX阶段的总线数据
    

    output wire [`BR_WD-1:0] br_bus,  // 分支预测总线
    
    input wire [65:0] wb_to_id_wf,  // WB阶段的写回数据传递到ID阶段
    input wire ready_ex_to_id  // EX阶段到ID阶段的准备信号
);
    reg [31:0] inst_stall;  // 暂存的指令
    reg inst_stall_en;  // 指令暂存启用信号
    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;  // IF阶段到ID阶段的寄存器数据暂存
    wire [31:0] inst;  // 当前指令
    wire [31:0] id_pc;  // 当前ID阶段的PC值
    wire ce;  // 指令有效信号
    wire [31:0] inst_stall1;  // 输出的暂存指令
    wire inst_stall_en1;  // 暂存指令启用信号
    
    wire wb_rf_we;  // 写回阶段写寄存器使能信号
    wire [4:0] wb_rf_waddr;  // 写回阶段写寄存器地址
    wire [31:0] wb_rf_wdata;  // 写回阶段写寄存器数据

    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;   // 复位时清空IF到ID阶段的总线数据
        end
        
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;  // 暂停当前阶段，但允许后续阶段运行
//            wb_to_id_wf_r <= 66'b0;  // （注释）同时清空写回数据
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;  // 正常运行时更新总线数据
//          
        end
    end

    always @ (posedge clk) begin
        inst_stall_en <= 1'b0;  // 默认不启用暂存
        inst_stall <= 32'b0;  // 默认暂存数据为0
        if(stall[1] == 1'b1 & ready_ex_to_id == 1'b0) begin
            inst_stall <= inst;  // 暂停阶段时保存当前指令
            inst_stall_en <= 1'b1;  // 启用暂存
        end
    end

    assign inst_stall1 = inst_stall;  // 暂存的指令输出
    assign inst_stall_en1 = inst_stall_en;  // 暂存指令的启用信号输出

    assign inst = inst_stall_en1 ? inst_stall1 : inst_sram_rdata;  // 如果启用暂存，则使用暂存指令，否则使用SRAM指令
    assign {
        ce,  // 指令有效信号
        id_pc  // ID阶段的PC值
    } = if_to_id_bus_r;

    assign {
        wb_rf_we,  // 写寄存器使能
        wb_rf_waddr,  // 写寄存器地址
        wb_rf_wdata  // 写寄存器数据
    } = wb_to_rf_bus;

    wire [5:0] opcode;  // 操作码
    wire [4:0] rs, rt, rd, sa;  // 寄存器地址字段和移位量
    wire [5:0] func;  // 功能码
    wire [15:0] imm;  // 立即数
    wire [25:0] instr_index;  // 指令索引
    wire [19:0] code;  // 代码字段
    wire [4:0] base;  // 基地址
    wire [15:0] offset;  // 偏移量
    wire [2:0] sel;  // 选择信号

    wire [63:0] op_d, func_d;  // 操作码和功能码解码
    wire [31:0] rs_d, rt_d, rd_d, sa_d;  // 寄存器数据解码

    wire [2:0] sel_alu_src1;  // ALU第一个操作数选择
    wire [3:0] sel_alu_src2;  // ALU第二个操作数选择
    wire [11:0] alu_op;  // ALU操作类型

    wire data_ram_en;  // 数据RAM使能
    wire [3:0] data_ram_wen;  // 数据RAM写使能
    wire [3:0] data_ram_read;  // 数据RAM读信号
    
    wire rf_we;  // 写寄存器使能
    wire [4:0] rf_waddr;  // 写寄存器地址
    wire sel_rf_res;  // 写寄存器结果选择
    wire [2:0] sel_rf_dst;  // 写寄存器目标选择

    wire [31:0] rdata1, rdata2;  // 读取的寄存器数据
    
    wire w_hi_we;  // 写高位寄存器使能
    wire w_lo_we;  // 写低位寄存器使能
    wire [31:0] hi_i;  // 写入的高位数据
    wire [31:0] lo_i;  // 写入的低位数据
    
    wire r_hi_we;  // 读取高位寄存器使能
    wire r_lo_we;  // 读取低位寄存器使能
    wire [31:0] hi_o;  // 读取的高位数据
    wire [31:0] lo_o;  // 读取的低位数据
    
    wire [1:0] lo_hi_r;  // 低位和高位寄存器读取信号
    wire [1:0] lo_hi_w;  // 低位和高位寄存器写入信号
    
    wire inst_lsa;  // LSA（逻辑左移加法）指令信号
    
    assign 
    {
        w_hi_we,  // 写高位寄存器使能
        w_lo_we,  // 写低位寄存器使能
        hi_i,  // 高位输入数据
        lo_i  // 低位输入数据
    } = wb_to_id_wf;

    regfile u_regfile(  // 实例化寄存器文件
        .inst   (inst),  // 输入指令
    	.clk    (clk    ),  // 时钟
    	//read
        .raddr1 (rs ),  // 读取地址1
        .rdata1 (rdata1 ),  // 读取数据1
        .raddr2 (rt ),  // 读取地址2
        .rdata2 (rdata2 ),  // 读取数据2
        //store
        .we     (wb_rf_we     ),  // 写使能
        .waddr  (wb_rf_waddr  ),  // 写地址
        .wdata  (wb_rf_wdata  ),  // 写数据
        .ex_to_id_bus(ex_to_id_bus),  // EX阶段到ID阶段总线
        .mem_to_id_bus(mem_to_id_bus),  // MEM阶段到ID阶段总线
        .wb_to_id_bus(wb_to_id_bus),  // WB阶段到ID阶段总线
        .ex_to_id_2(ex_to_id_2),  // EX阶段到ID的第二总线
        .mem_to_id_2(mem_to_id_2),  // MEM阶段到ID的第二总线
        .wb_to_id_2(wb_to_id_2),  // WB阶段到ID的第二总线
        //write
        .w_hi_we  (w_hi_we),  // 写高位使能
        .w_lo_we  (w_lo_we),  // 写低位使能
        .hi_i(hi_i),  // 高位输入
        .lo_i(lo_i),  // 低位输入
        //read
        .r_hi_we (lo_hi_r[0]),  // 读取高位使能
        .r_lo_we (lo_hi_r[1]),  // 读取低位使能
        .hi_o(hi_o),  // 高位输出
        .lo_o(lo_o),  // 低位输出
        .inst_lsa(inst_lsa)  // LSA指令信号
    );

    assign opcode = inst[31:26];  // 提取操作码
    assign rs = inst[25:21];  // 提取rs字段
    assign rt = inst[20:16];  // 提取rt字段
    assign rd = inst[15:11];  // 提取rd字段
    assign sa = inst[10:6];  // 提取移位量
    assign func = inst[5:0];  // 提取功能码
    assign imm = inst[15:0];  // 提取立即数
    assign instr_index = inst[25:0];  // 提取指令索引
    assign code = inst[25:6];  // 提取代码字段
    assign base = inst[25:21];  // 提取基地址
    assign offset = inst[15:0];  // 提取偏移量

    assign sel = inst[2:0];  // 从指令inst中提取第2位到第0位，赋值给sel

assign stallreq_for_id = (inst_is_load == 1'b1 && (rs == ex_to_id_bus[36:32] || rt == ex_to_id_bus[36:32] ));  // 如果当前指令是加载指令且rs或rt与ex_to_id_bus中的寄存器冲突，则产生stall请求

// assign inst_stall =  (stallreq_for_id) ? inst : 32'b0;  // 如果stallreq_for_id为1，则inst_stall为inst，否则为0

//////////////////////////指令解码部分////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////

// 定义各种指令的wire信号
wire inst_ori, inst_lui, inst_addiu, inst_beq, inst_subu, inst_jr, inst_jal, inst_addu, inst_bne, inst_sll, inst_or,
     inst_lw, inst_sw, inst_xor ,inst_sltu, inst_slt, inst_slti, inst_sltiu, inst_j, inst_add, inst_addi ,inst_sub,
     inst_and , inst_andi, inst_nor, inst_xori, inst_sllv, inst_sra, inst_bgez, inst_bltz, inst_bgtz, inst_blez,
     inst_bgezal,inst_bltzal, inst_jalr, inst_mflo, inst_mfhi, inst_mthi, inst_mtlo, inst_div, inst_divi, inst_mult,
     inst_multu, inst_lb, inst_lbu, inst_lh, inst_lhu, inst_sb, inst_sh;

// 定义ALU操作的wire信号
wire op_add, op_sub, op_slt, op_sltu;
wire op_and, op_nor, op_or, op_xor;
wire op_sll, op_srl, op_sra, op_lui;

// 实例化6-64解码器，用于解码opcode
decoder_6_64 u0_decoder_6_64(
    .in  (opcode  ),  // 输入opcode
    .out (op_d )      // 输出解码后的信号
);

// 实例化6-64解码器，用于解码func
decoder_6_64 u1_decoder_6_64(
    .in  (func  ),  // 输入func
    .out (func_d )  // 输出解码后的信号
);

// 实例化5-32解码器，用于解码rs
decoder_5_32 u0_decoder_5_32(
    .in  (rs  ),  // 输入rs
    .out (rs_d )  // 输出解码后的信号
);

// 实例化5-32解码器，用于解码rt
decoder_5_32 u1_decoder_5_32(
    .in  (rt  ),  // 输入rt
    .out (rt_d )  // 输出解码后的信号
);

// 根据解码后的op_d信号，判断是否为ori指令
assign inst_ori     = op_d[6'b00_1101];

// 根据解码后的op_d信号，判断是否为lui指令
assign inst_lui     = op_d[6'b00_1111];

// 根据解码后的op_d信号，判断是否为addiu指令
assign inst_addiu   = op_d[6'b00_1001];

// 根据解码后的op_d信号，判断是否为beq指令
assign inst_beq     = op_d[6'b00_0100];

// 根据解码后的op_d和func_d信号，判断是否为subu指令
assign inst_subu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0011];

// 根据解码后的op_d和func_d信号，判断是否为jr指令
assign inst_jr      = op_d[6'b00_0000] & (inst[20:11]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b00_1000];

// 根据解码后的op_d信号，判断是否为jal指令
assign inst_jal     = op_d[6'b00_0011];

// 根据解码后的op_d和func_d信号，判断是否为addu指令
assign inst_addu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0001];

// 根据解码后的op_d和func_d信号，判断是否为sll指令
assign inst_sll     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0000];

// 根据解码后的op_d信号，判断是否为bne指令
assign inst_bne     = op_d[6'b00_0101];

// 根据解码后的op_d和func_d信号，判断是否为or指令
assign inst_or      = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0101];

// 根据解码后的op_d信号，判断是否为lw指令
assign inst_lw      = op_d[6'b10_0011];

// 根据解码后的op_d信号，判断是否为sw指令
assign inst_sw      = op_d[6'b10_1011];

// 根据解码后的op_d和func_d信号，判断是否为xor指令
assign inst_xor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0110];

// 根据解码后的op_d和func_d信号，判断是否为sltu指令
assign inst_sltu    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1011];

// 根据解码后的op_d和func_d信号，判断是否为slt指令
assign inst_slt     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_1010];

// 根据解码后的op_d信号，判断是否为slti指令
assign inst_slti    = op_d[6'b00_1010];

// 根据解码后的op_d信号，判断是否为sltiu指令
assign inst_sltiu   = op_d[6'b00_1011];

// 根据解码后的op_d信号，判断是否为j指令
assign inst_j       = op_d[6'b00_0010];

// 根据解码后的op_d和func_d信号，判断是否为add指令
assign inst_add     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0000];

// 根据解码后的op_d信号，判断是否为addi指令
assign inst_addi    = op_d[6'b00_1000];

// 根据解码后的op_d和func_d信号，判断是否为sub指令
assign inst_sub     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0010];     

// 根据解码后的op_d和func_d信号，判断是否为and指令
assign inst_and     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0100];

// 根据解码后的op_d信号，判断是否为andi指令
assign inst_andi    = op_d[6'b00_1100];

// 根据解码后的op_d和func_d信号，判断是否为nor指令
assign inst_nor     = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b10_0111];

// 根据解码后的op_d信号，判断是否为xori指令
assign inst_xori    = op_d[6'b00_1110];

// 根据解码后的op_d和func_d信号，判断是否为sllv指令
assign inst_sllv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0100];

// 根据解码后的op_d和func_d信号，判断是否为sra指令
assign inst_sra     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0011];

// 根据解码后的op_d和func_d信号，判断是否为srav指令
assign inst_srav    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0111];   

// 根据解码后的op_d和func_d信号，判断是否为srl指令
assign inst_srl     = op_d[6'b00_0000] & (rs==5'b0_0000) & func_d[6'b00_0010];

// 根据解码后的op_d和func_d信号，判断是否为srlv指令
assign inst_srlv    = op_d[6'b00_0000] & (sa==5'b0_0000) & func_d[6'b00_0110];  

// 根据解码后的op_d和rt信号，判断是否为bgez指令
assign inst_bgez    = op_d[6'b00_0001] & (rt==5'b0_0001);

// 根据解码后的op_d和rt信号，判断是否为bltz指令
assign inst_bltz    = op_d[6'b00_0001] & (rt==5'b0_0000);

// 根据解码后的op_d和rt信号，判断是否为bgtz指令
assign inst_bgtz    = op_d[6'b00_0111] & (rt==5'b0_0000);

// 根据解码后的op_d和rt信号，判断是否为blez指令
assign inst_blez    = op_d[6'b00_0110] & (rt==5'b0_0000);

// 根据解码后的op_d和rt信号，判断是否为bgezal指令
assign inst_bgezal  = op_d[6'b00_0001] & (rt==5'b1_0001);

// 根据解码后的op_d和rt信号，判断是否为bltzal指令
assign inst_bltzal  = op_d[6'b00_0001] & (rt==5'b1_0000);

// 根据解码后的op_d和func_d信号，判断是否为jalr指令
assign inst_jalr    = op_d[6'b00_0000] & (rt==5'b0_0000) & (sa==5'b0_0000) & func_d[6'b00_1001];

// 根据解码后的op_d和func_d信号，判断是否为mflo指令
assign inst_mflo    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0010];

// 根据解码后的op_d和func_d信号，判断是否为mfhi指令
assign inst_mfhi    = op_d[6'b00_0000] & (inst[25:16]==10'b0000000000) & (sa==5'b0_0000) & func_d[6'b01_0000];

// 根据解码后的op_d和func_d信号，判断是否为mthi指令
assign inst_mthi    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0001];

// 根据解码后的op_d和func_d信号，判断是否为mtlo指令
assign inst_mtlo    = op_d[6'b00_0000] & (inst[20:6]==10'b000000000000000)  & func_d[6'b01_0011];

// 根据解码后的op_d和func_d信号，判断是否为div指令
assign inst_div     = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1010];

// 根据解码后的op_d和func_d信号，判断是否为divu指令
assign inst_divu    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1011];

// 根据解码后的op_d和func_d信号，判断是否为mult指令
assign inst_mult    = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1000];

// 根据解码后的op_d和func_d信号，判断是否为multu指令
assign inst_multu   = op_d[6'b00_0000] & (inst[15:6]==10'b0000000000) & func_d[6'b01_1001];

// 根据解码后的op_d信号，判断是否为lb指令
assign inst_lb      = op_d[6'b10_0000];

// 根据解码后的op_d信号，判断是否为lbu指令
assign inst_lbu     = op_d[6'b10_0100];

// 根据解码后的op_d信号，判断是否为lh指令
assign inst_lh      = op_d[6'b10_0001];

// 根据解码后的op_d信号，判断是否为lhu指令
assign inst_lhu     = op_d[6'b10_0101];      

// 根据解码后的op_d信号，判断是否为sb指令
assign inst_sb      = op_d[6'b10_1000];

// 根据解码后的op_d信号，判断是否为sh指令
assign inst_sh      = op_d[6'b10_1001];

// 根据解码后的op_d信号，判断是否为lsa指令
assign inst_lsa     = op_d[6'b01_1100] & inst[10:8]==3'b111 & inst[5:0]==6'b11_0111;

// 根据指令类型选择ALU的源操作数1
assign sel_alu_src1[0] = inst_ori | inst_addiu | inst_subu | inst_addu | inst_or | inst_lw | inst_sw | inst_xor | inst_sltu | inst_slt
                            | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_xori
                            | inst_sllv | inst_srav | inst_srlv | inst_mthi | inst_mtlo | inst_div | inst_divu | inst_mult | inst_multu
                            | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lsa;

// 如果指令是jal、bgezal、bltzal或jalr，则选择PC作为ALU的源操作数1
assign sel_alu_src1[1] = inst_jal | inst_bgezal |inst_bltzal | inst_jalr;

// 如果指令是sll、sra或srl，则选择sa_zero_extend作为ALU的源操作数1
assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

// 根据指令类型选择ALU的源操作数2
assign sel_alu_src2[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and |
                          inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_div | inst_divu | inst_mult | inst_multu | inst_lsa;

// 如果指令是lui、addiu、lw、sw、slti、sltiu、addi、lb、lbu、lh、lhu、sb或sh，则选择imm_sign_extend作为ALU的源操作数2
assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw | inst_sw | inst_slti | inst_sltiu | inst_addi | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

// 如果指令是jal、bgezal、bltzal或jalr，则选择32'b8作为ALU的源操作数2
assign sel_alu_src2[2] = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;

// 如果指令是ori、andi或xori，则选择imm_zero_extend作为ALU的源操作数2
assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;

// 如果指令是mflo，则选择lo作为目标寄存器
assign lo_hi_r[0] = inst_mflo;

// 如果指令是mfhi，则选择hi作为目标寄存器
assign lo_hi_r[1] = inst_mfhi;

// 根据指令类型选择ALU的操作类型
assign op_add = inst_addiu | inst_jal | inst_addu | inst_lw | inst_sw | inst_add | inst_addi | inst_bgezal | inst_bltzal
     | inst_jalr | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lsa;
assign op_sub = inst_subu | inst_sub;
assign op_slt = inst_slt | inst_slti;
assign op_sltu = inst_sltu | inst_sltiu;
assign op_and = inst_and | inst_andi;
assign op_nor = inst_nor;
assign op_or = inst_ori | inst_or;
assign op_xor = inst_xor | inst_xori;
assign op_sll = inst_sll | inst_sllv;
assign op_srl = inst_srl | inst_srlv;
assign op_sra = inst_sra | inst_srav ;
assign op_lui = inst_lui;

// 将ALU的操作类型编码为alu_op信号
assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                 op_and, op_nor, op_or, op_xor,
                 op_sll, op_srl, op_sra, op_lui};

// 如果指令是lw、sw、lb、lbu、lh、lhu、sb或sh，则使能数据存储器
assign data_ram_en = inst_lw | inst_sw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh;

// 如果指令是sw，则设置数据存储器的写使能信号为4'b1111，否则为4'b0000
assign data_ram_wen = inst_sw ? 4'b1111 : 4'b0000;

// 根据指令类型选择数据存储器的读模式
assign data_ram_read    =  inst_lw  ? 4'b1111 :
                           inst_lb  ? 4'b0001 :
                           inst_lbu ? 4'b0010 :
                           inst_lh  ? 4'b0011 :
                           inst_lhu ? 4'b0100 :
                           inst_sb  ? 4'b0101 :
                           inst_sh  ? 4'b0111 :
                           4'b0000;

// 根据指令类型设置寄存器文件的写使能信号
assign rf_we = inst_ori | inst_lui | inst_addiu | inst_subu | inst_jal |inst_addu | inst_sll | inst_or | inst_xor | inst_lw | inst_sltu
  | inst_slt | inst_slti | inst_sltiu | inst_add | inst_addi | inst_sub | inst_and | inst_andi | inst_nor | inst_sllv | inst_xori | inst_sra
  | inst_srav | inst_srl | inst_srlv | inst_bgezal | inst_bltzal | inst_jalr  | inst_mfhi | inst_mflo | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lsa;

// 根据指令类型选择目标寄存器为rd
assign sel_rf_dst[0] = inst_subu | inst_addu | inst_sll | inst_or | inst_xor | inst_sltu | inst_slt | inst_add | inst_sub | inst_and | inst_nor
                         | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv | inst_jalr | inst_mflo | inst_mfhi | inst_lsa;

// 根据指令类型选择目标寄存器为rt
assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_andi | inst_xori | inst_lb | inst_lbu | inst_lh | inst_lhu;

// 根据指令类型选择目标寄存器为31
assign sel_rf_dst[2] = inst_jal | inst_bgezal | inst_bltzal ;

// 如果指令是mtlo，则选择lo作为目标寄存器
assign lo_hi_w[0] = inst_mtlo;

// 如果指令是mthi，则选择hi作为目标寄存器
assign lo_hi_w[1] = inst_mthi ;

// 根据sel_rf_dst信号选择目标寄存器地址
assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                | {5{sel_rf_dst[1]}} & rt
                | {5{sel_rf_dst[2]}} & 32'd31;

// 如果指令是lw、lb或lbu，则选择ld_res作为寄存器文件的写入数据，否则选择alu_res
assign sel_rf_res = (inst_lw | inst_lb | inst_lbu) ? 1'b1 : 1'b0; 

// 定义id_to_ex_bus信号，用于将ID阶段的信息传递到EX阶段
assign id_to_ex_bus = {
    id_pc,          // 158:127  // 当前指令的PC值
    inst,           // 126:95   // 当前指令
    alu_op,         // 94:83    // ALU操作类型
    sel_alu_src1,   // 82:80    // ALU源操作数1选择信号
    sel_alu_src2,   // 79:76    // ALU源操作数2选择信号
    data_ram_en,    // 75       // 数据存储器使能信号
    data_ram_wen,   // 74:71    // 数据存储器写使能信号
    rf_we,          // 70       // 寄存器文件写使能信号
    rf_waddr,       // 69:65    // 寄存器文件写入地址
    sel_rf_res,     // 64       // 寄存器文件写入数据选择信号
    rdata1,         // 63:32    // rs寄存器的值
    rdata2,          // 31:0    // rt寄存器的值
    lo_hi_r,                        // 读取lo/hi寄存器的信号
    lo_hi_w,                        // 写入lo/hi寄存器的信号
    lo_o,                           // lo寄存器的值
    hi_o,                            // hi寄存器的值
    data_ram_read                   // 数据存储器读模式
};

// 定义br_e信号，表示是否发生分支
wire br_e;

// 定义br_addr信号，表示分支目标地址
wire [31:0] br_addr;

// 定义rs_eq_rt信号，表示rs和rt寄存器的值是否相等
wire rs_eq_rt;

// 定义rs_ge_z信号，表示rs寄存器的值是否大于等于0
wire rs_ge_z;

// 定义rs_gt_z信号，表示rs寄存器的值是否大于0
wire rs_gt_z;

// 定义rs_le_z信号，表示rs寄存器的值是否小于等于0
wire rs_le_z;

// 定义rs_lt_z信号，表示rs寄存器的值是否小于0
wire rs_lt_z;

// 定义pc_plus_4信号，表示当前PC值加4
wire [31:0] pc_plus_4;

// 定义re_bne_rt信号，表示rs和rt寄存器的值是否不相等
wire re_bne_rt;

// 计算pc_plus_4的值
assign pc_plus_4 = id_pc + 32'h4;

// 判断rs和rt寄存器的值是否相等
assign rs_eq_rt = (rdata1 == rdata2);

// 判断rs和rt寄存器的值是否不相等
assign re_bne_rt = (rdata1 != rdata2);

// 判断rs寄存器的值是否大于等于0
assign re_bgez_rt = (rdata1[31] == 1'b0);

// 判断rs寄存器的值是否小于0
assign re_bltz_rt = (rdata1[31] == 1'b1);     

// 判断rs寄存器的值是否小于等于0
assign re_blez_rt = (rdata1[31] == 1'b1 || rdata1 == 32'b0);

// 判断rs寄存器的值是否大于0
assign re_bgtz_rt = (rdata1[31] == 1'b0 && rdata1 != 32'b0);

// 判断是否发生分支
assign br_e = (inst_beq && rs_eq_rt) | inst_jr | inst_jal | (inst_bne && re_bne_rt) | inst_j |(inst_bgez && re_bgez_rt)
                 | (inst_bltz && re_bltz_rt) |(inst_bgtz && re_bgtz_rt) | (inst_blez && re_blez_rt) | (inst_bgezal && re_bgez_rt)
                 | (inst_bltzal && re_bltz_rt) | inst_jalr;

// 根据指令类型计算分支目标地址
assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 
inst_jr ? (rdata1) :
inst_jal ? ({pc_plus_4[31:28],inst[25:0],2'b0}):
inst_bne ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
inst_bgez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :   
inst_bgtz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :  
inst_bltz ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :   
inst_blez ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
inst_bgezal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :
inst_bltzal ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) :  
inst_j   ?  ({pc_plus_4[31:28],inst[25:0],2'b0}):
inst_jalr ? (rdata1) :
32'b0;

// 定义br_bus信号，用于传递分支信息
assign br_bus = {
    br_e,      // 是否发生分支
    br_addr    // 分支目标地址
};

endmodule
