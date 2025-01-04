`define IF_TO_ID_WD 33
// PC值（pc_reg）：32 位
// 有效位（ce_reg）：1 位

`define ID_TO_EX_WD 231
// PC值（id_pc）：32 位
// 指令（inst）：32 位
// ALU操作码（alu_op）：12 位
// ALU源1选择信号（sel_alu_src1）：3 位
// ALU源2选择信号（sel_alu_src2）：4 位
// 数据存储器使能（data_ram_en）：1 位
// 数据存储器写使能（data_ram_wen）：4 位
// 寄存器文件写使能（rf_we）：1 位
// 寄存器文件写地址（rf_waddr）：5 位
// 寄存器文件结果选择信号（sel_rf_res）：1 位
// 寄存器文件读数据1（rdata1）：32 位
// 寄存器文件读数据2（rdata2）：32 位
// LO/HI读信号（lo_hi_r）：2 位
// LO/HI写信号（lo_hi_w）：2 位
// LO值（lo_o）：32 位
// HI值（hi_o）：32 位
// 数据存储器读信号（data_ram_read）：4 位

`define EX_TO_MEM_WD 80
// PC值（ex_pc）：32 位
// 数据存储器使能（data_ram_en）：1 位
// 数据存储器写使能（data_ram_wen）：4 位
// 寄存器文件结果选择信号（sel_rf_res）：1 位
// 寄存器文件写使能（rf_we）：1 位
// 寄存器文件写地址（rf_waddr）：5 位
// ALU结果（ex_result）：32 位
// 数据存储器读信号（data_ram_read）：4 位

`define MEM_TO_WB_WD 70
// PC值（mem_pc）：32 位
// 寄存器文件写使能（rf_we）：1 位
// 寄存器文件写地址（rf_waddr）：5 位
// 寄存器文件写数据（rf_wdata）：32 位

`define BR_WD 33
// 分支使能信号（br_e）：1 位
// 分支地址（br_addr）：32 位

`define DATA_SRAM_WD 69
// 数据存储器使能（data_sram_en）：1 位
// 数据存储器写使能（data_sram_wen）：4 位
// 数据存储器地址（data_sram_addr）：32 位
// 数据存储器写数据（data_sram_wdata）：32 位

`define WB_TO_RF_WD 38
// 寄存器文件写使能（rf_we）：1 位
// 寄存器文件写地址（rf_waddr）：5 位
// 寄存器文件写数据（rf_wdata）：32 位

`define StallBus 6
// 流水线各级暂停信号：6 位

`define NoStop 1'b0
// 流水线不需要暂停

`define Stop 1'b1
// 流水线需要暂停

`define ZeroWord 32'b0
// 32 位零值


// 除法器状态定义
`define DivFree 2'b00
// 除法器空闲状态

`define DivByZero 2'b01
// 除法器遇到除零错误

`define DivOn 2'b10
// 除法器正在执行除法操作

`define DivEnd 2'b11
// 除法器完成除法操作

`define DivResultReady 1'b1
// 除法结果已经准备好

`define DivResultNotReady 1'b0
// 除法结果尚未准备好

`define DivStart 1'b1
// 除法器开始执行除法操作

`define DivStop 1'b0
// 除法器停止执行除法操作
