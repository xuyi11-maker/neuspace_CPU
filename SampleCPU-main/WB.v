`include "lib/defines.vh"
//新增了一个 66 位的输入信号 mem_to_wb1，用于内存阶段传递额外的数据到写回阶段
//新增了两个 66 位的输出信号 wb_to_id_wf 和 wb_to_id_2，将写回阶段的数据传递到指令译码阶段
//以及一个 38 位的输出信号 wb_to_id_bus，用于将部分数据传递到指令译码阶段（ID）。
//新增了对高位寄存器（HI）和低位寄存器（LO）的支持，包括写使能信号和写数据。（高低位）
//扩展了时钟控制逻辑，以处理新增的 mem_to_wb1_r 寄存器。确保在复位或流水线暂停时清零，在流水线正常运行时更新。
module WB(
    input wire clk,//时钟信号
    input wire rst,//复位信号
    // input wire flush,
    input wire [`StallBus-1:0] stall,//流水线暂停信号

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,//内存传递到写回阶段的数据总线

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,//写回传递到寄存器文件的数据总线
    
    output wire [37:0] wb_to_id_bus,//写回到指令译码阶段的数据总线（38位）
    //调试用的
    output wire [31:0] debug_wb_pc,//程序计数器值
    output wire [3:0] debug_wb_rf_wen,//寄存器写使能信号
    output wire [4:0] debug_wb_rf_wnum,//寄存器写地址
    output wire [31:0] debug_wb_rf_wdata,//寄存器写数据
    
    input wire[65:0] mem_to_wb1 ,//从内存传递的写回阶段的额外数据总线（66）位
    output wire[65:0]wb_to_id_wf,//从写回传递到译码阶段的额外数据总线（66）位
    output wire[65:0] wb_to_id_2 //写回到译码阶段额外的数据总线
);
    //内部寄存器
    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;//暂存mem_to_wb_bus_r的值
    reg [65:0] mem_to_wb1_r;//暂存值
    //时钟逻辑控制
    always @ (posedge clk) begin
        if (rst) begin//复位信号有效时候清零所有寄存器
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
            mem_to_wb1_r <= 66'b0;
        end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin//流水线暂停时清0所有寄存器
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
            mem_to_wb1_r <= 66'b0;
        end
        else if (stall[4]==`NoStop) begin//流水线正常运行时，更新寄存器的值
            mem_to_wb_bus_r <= mem_to_wb_bus;
            mem_to_wb1_r <= mem_to_wb1;
        end
    end
// 从 mem_to_wb_bus_r 中解包出程序计数器值、寄存器写使能、写地址和写数据
    wire [31:0] wb_pc;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;
// 从 mem_to_wb1_r 中解包出高位寄存器写使能、低位寄存器写使能、高位寄存器写数据和低位寄存器写数据
    wire w_hi_we;
    wire w_lo_we;
    wire [31:0]hi_i;
    wire [31:0]lo_i;
    //解包mem_to_wb_bus_r
    assign {
        wb_pc,
        rf_we,
        rf_waddr,
        rf_wdata
    } = mem_to_wb_bus_r;
    // 解包 mem_to_wb1_r
    assign 
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    } = mem_to_wb1_r;
    // 将高位和低位寄存器的写使能信号和写数据打包输出到指令译码阶段
    assign wb_to_id_wf=
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    //用于额外的数据传递
    assign wb_to_id_2=
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    // 将寄存器写使能、写地址和写数据打包输出到寄存器文件
    // assign wb_to_rf_bus = mem_to_wb_bus_r[`WB_TO_RF_WD-1:0];
    assign wb_to_rf_bus = {
        rf_we,
        rf_waddr,
        rf_wdata
    };
    assign wb_to_id_bus = {
        rf_we,
        rf_waddr,
        rf_wdata
    };
    //调试信号赋值
    assign debug_wb_pc = wb_pc;//输出调试用的pc
    assign debug_wb_rf_wen = {4{rf_we}};//寄存器写使能信号
    assign debug_wb_rf_wnum = rf_waddr;//寄存器写地址
    assign debug_wb_rf_wdata = rf_wdata;//寄存器写数据

    
endmodule
