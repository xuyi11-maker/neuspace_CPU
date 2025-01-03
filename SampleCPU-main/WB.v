`include "lib/defines.vh"
//实现了一个简单的写回阶段模块，负责将内存阶段的结果写回到寄存器文件中。它通过时钟信号和流水线暂停信号来控制数据的流动，并提供了调试用的输出信号
//将执行结果写回到寄存器文件中
module WB(
    input wire clk,//时钟信号方便复位操作
    input wire rst,//复位信号用于初始化模块
    // input wire flush,
    input wire [`StallBus-1:0] stall,//流水线暂停

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,//内存传递到写回阶段的数据总线

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,//写回阶段传递到寄存器文件的数据总线
    //调试用的
    output wire [31:0] debug_wb_pc,//程序计数器PC值
    output wire [3:0] debug_wb_rf_wen,//寄存器写使能信号
    output wire [4:0] debug_wb_rf_wnum,//寄存器写地址
    output wire [31:0] debug_wb_rf_wdata //寄存器写数据
);
    //内部寄存器
    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;//暂存从内存传递过来的数据

    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;//如果复位信号有效，将 mem_to_wb_bus_r 清零
        end
        // else if (flush) begin
        //     mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        // end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;//第4位为 Stop 且第5位为 NoStop，则清零 mem_to_wb_bus_r
        end
        else if (stall[4]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;//第4位为 NoStop，则将 mem_to_wb_bus 的值赋给 mem_to_wb_bus_r
        end
    end
    //信号解包
    wire [31:0] wb_pc;
    wire rf_we;
    wire [4:0] rf_waddr;
    wire [31:0] rf_wdata;

    assign {
        wb_pc,//从 mem_to_wb_bus_r 中提取的程序计数器值。
        rf_we,//寄存器写使能信号。
        rf_waddr,//寄存器写地址
        rf_wdata//寄存器写数据
    } = mem_to_wb_bus_r;
    //输出信号赋值
    assign wb_to_rf_bus = {//将寄存器写使能、写地址和写数据打包输出到寄存器文件。
        rf_we,
        rf_waddr,
        rf_wdata
    };
//输出调试用的
    assign debug_wb_pc = wb_pc;//程序计数器值
    assign debug_wb_rf_wen = {4{rf_we}};//寄存器写使能信号（扩展为4位）
    assign debug_wb_rf_wnum = rf_waddr;//寄存器写地址
    assign debug_wb_rf_wdata = rf_wdata;//寄存器写数据

    
endmodule
