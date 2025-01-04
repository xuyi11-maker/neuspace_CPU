`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    input wire [`StallBus-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,
    input wire [31:0] data_sram_rdata,

    output wire [37:0] mem_to_id_bus,
    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    
    input wire [65:0] ex_to_mem1,
    /*
    从EX阶段传递到MEM阶段的额外总线，宽度为66位,包括：
    HI寄存器写使能信号
    LO寄存器写使能信号
    HI寄存器输入数据
    LO寄存器输入数据
    */
    output wire[65:0] mem_to_wb1,
    output wire[65:0] mem_to_id_2 
    //访存到写回和译码，格式同上
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;
    reg [65:0] ex_to_mem1_r;

    // 时钟上升沿触发的逻辑
    always @ (posedge clk) begin
        if (rst) begin  // 如果复位信号有效
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 清空总线寄存器
            ex_to_mem1_r <= 66'b0;                // 清空额外总线寄存器
        end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin  // 如果MEM阶段需要暂停
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;  // 清空总线寄存器
            ex_to_mem1_r <= 65'b0;                // 清空额外总线寄存器
        end
        else if (stall[3]==`NoStop) begin  // 如果MEM阶段不需要暂停
            ex_to_mem_bus_r <= ex_to_mem_bus;  // 将EX阶段的总线数据存储到寄存器
            ex_to_mem1_r <= ex_to_mem1;        // 将EX阶段的额外总线数据存储到寄存器
        end
    end

    wire [31:0] mem_pc;         // PC值
    wire data_ram_en;           // 数据存储器使能信号
    wire [3:0] data_ram_wen;    // 数据存储器写使能信号
    wire [3:0] data_ram_read;   // 数据存储器读信号
    wire sel_rf_res;            // 寄存器文件结果选择信号
    wire rf_we;                 // 寄存器文件写使能信号
    wire [4:0] rf_waddr;        // 寄存器文件写地址
    wire [31:0] rf_wdata;       // 寄存器文件写数据
    wire [31:0] ex_result;      // ALU计算结果
    wire [31:0] mem_result;     // 存储器读出的数据
    
     wire w_hi_we;
     wire w_lo_we;
     wire [31:0]hi_i;
     wire [31:0]lo_i;
  

    assign {
        mem_pc,         // 79:48
        data_ram_en,    // 47
        data_ram_wen,   // 46:43
        sel_rf_res,     // 42
        rf_we,          // 41
        rf_waddr,       // 40:36
        ex_result,      // 35:4
        data_ram_read   // 3:0
    } =  ex_to_mem_bus_r;
    
    assign 
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    }=ex_to_mem1_r ;
    
    assign mem_to_wb1 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };
    
    assign mem_to_id_2 =
    {
        w_hi_we,
        w_lo_we,
        hi_i,
        lo_i
    };

    assign mem_result = data_sram_rdata;

    assign rf_wdata =   (data_ram_read==4'b1111 && data_ram_en==1'b1) ? mem_result :
                        //加载字（LW）操作，直接将 mem_result（存储器读出的 32 位数据）赋值给 rf_wdata
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{24{mem_result[7]}},mem_result[7:0]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({{24{mem_result[15]}},mem_result[15:8]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{24{mem_result[23]}},mem_result[23:16]}):
                        (data_ram_read==4'b0001 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({{24{mem_result[31]}},mem_result[31:24]}):
                        //加载字节（LB）操作，根据 ex_result[1:0] 的值，选择存储器中的某个字节，并进行符号扩展：
                        //ex_result[1:0]==2'b00：选择最低字节 mem_result[7:0]，并将其符号扩展到 32 位
                        //ex_result[1:0]==2'b01：选择第二个字节 mem_result[15:8]，并将其符号扩展到 32 位
                        //ex_result[1:0]==2'b10：选择第三个字节 mem_result[23:16]，并将其符号扩展到 32 位
                        //ex_result[1:0]==2'b11：选择最高字节 mem_result[31:24]，并将其符号扩展到 32 位
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({24'b0,mem_result[7:0]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b01) ?({24'b0,mem_result[15:8]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({24'b0,mem_result[23:16]}):
                        (data_ram_read==4'b0010 && data_ram_en==1'b1 && ex_result[1:0]==2'b11) ?({24'b0,mem_result[31:24]}):
                        //加载字节无符号（LBU）操作，根据 ex_result[1:0] 的值，选择存储器中的某个字节，并进行无符号扩展，细则同上
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({{16{mem_result[15]}},mem_result[15:0]}):
                        (data_ram_read==4'b0011 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({{16{mem_result[31]}},mem_result[31:16]}):
                        //加载半字（LH）操作，根据 ex_result[1:0] 的值，选择存储器中的某个半字，并进行符号扩展：
                        //ex_result[1:0]==2'b00：选择最低半字 mem_result[15:0]，并将其符号扩展到 32 位
                        //ex_result[1:0]==2'b10：选择最高半字 mem_result[31:16]，并将其符号扩展到 32 位
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b00) ?({16'b0,mem_result[15:0]}):
                        (data_ram_read==4'b0100 && data_ram_en==1'b1 && ex_result[1:0]==2'b10) ?({16'b0,mem_result[31:16]}):
                        //加载半字无符号（LHU）操作，根据 ex_result[1:0] 的值，选择存储器中的某个半字，并进行无符号扩展：，细则同上
                        ex_result;
                        //如果以上条件都不满足，则直接将 ex_result（ALU 的计算结果）赋值给 rf_wdata

    assign mem_to_wb_bus = {
        mem_pc,     // 69:38
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };
    
    assign mem_to_id_bus = {
        rf_we,      // 37
        rf_waddr,   // 36:32
        rf_wdata    // 31:0
    };




endmodule
