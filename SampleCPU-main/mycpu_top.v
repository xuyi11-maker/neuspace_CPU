`include "lib/defines.vh"
module mycpu_top(
    input wire clk,               // 时钟信号
    input wire resetn,            // 复位信号（低电平有效）
    input wire [5:0] ext_int,     // 外部中断信号

    output wire inst_sram_en,     // 指令存储器使能信号
    output wire [3:0] inst_sram_wen,  // 指令存储器写使能信号
    output wire [31:0] inst_sram_addr,  // 指令存储器地址
    output wire [31:0] inst_sram_wdata, // 指令存储器写数据
    input wire [31:0] inst_sram_rdata,  // 指令存储器读数据

    output wire data_sram_en,     // 数据存储器使能信号
    output wire [3:0] data_sram_wen,  // 数据存储器写使能信号
    output wire [31:0] data_sram_addr,  // 数据存储器地址
    output wire [31:0] data_sram_wdata, // 数据存储器写数据
    input wire [31:0] data_sram_rdata,  // 数据存储器读数据

    output wire [31:0] debug_wb_pc,  // 调试用的写回阶段PC值
    output wire [3:0] debug_wb_rf_wen,  // 调试用的寄存器文件写使能信号
    output wire [4:0] debug_wb_rf_wnum, // 调试用的寄存器文件写地址
    output wire [31:0] debug_wb_rf_wdata  // 调试用的寄存器文件写数据
);

    // 定义虚拟地址信号
    wire [31:0] inst_sram_addr_v, data_sram_addr_v;

    // mycpu_core模块实例化
    mycpu_core u_mycpu_core(
    	.clk               (clk               ),
        .rst               (~resetn           ),
        .int               (ext_int           ),
        .inst_sram_en      (inst_sram_en      ),
        .inst_sram_wen     (inst_sram_wen     ),
        .inst_sram_addr    (inst_sram_addr_v  ),
        .inst_sram_wdata   (inst_sram_wdata   ),
        .inst_sram_rdata   (inst_sram_rdata   ),
        .data_sram_en      (data_sram_en      ),
        .data_sram_wen     (data_sram_wen     ),
        .data_sram_addr    (data_sram_addr_v  ),
        .data_sram_wdata   (data_sram_wdata   ),
        .data_sram_rdata   (data_sram_rdata   ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    // MMU模块实例化（指令存储器）
    mmu u0_mmu(
    	.addr_i (inst_sram_addr_v ),
        .addr_o (inst_sram_addr   )
    );

    // MMU模块实例化（数据存储器）
    mmu u1_mmu(
    	.addr_i (data_sram_addr_v ),
        .addr_o (data_sram_addr   )
    );
    
endmodule 
