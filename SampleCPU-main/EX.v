`include "lib/defines.vh"
//CPU流水线中的执行阶段（EX阶段），负责执行算术逻辑运算（ALU操作）、乘法、除法等操作，并将结果传递到下一个阶段（MEM阶段）
module EX(
    input wire clk,//时钟信号
    input wire rst,//复位信号

    input wire [`StallBus-1:0] stall,//流水线暂停信号

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,//从id传递到ex阶段的总线信号

    output wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus,//从ex传递到mem阶段的总线信号

    output wire data_sram_en,//数据存储器使能信号
    output wire [3:0] data_sram_wen,//数据存储器写使能信号
    output wire [31:0] data_sram_addr,//数据存储器地址
    output wire [31:0] data_sram_wdata//数据存储器写数据
);
    //内置寄存器
    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;//存储从id传递到ex阶段总线信号

    //在时钟上升沿或复位时更新id_to_ex_bus_r
    always @ (posedge clk) begin
        if (rst) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;//复位时清零
        end

        else if (stall[2]==`Stop && stall[3]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;//ex阶段暂停时候清零
        end
        else if (stall[2]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;//ex阶段不暂停的时候更新总线信号
        end
    end
    //从id_to_ex_bus_r中提取各个控制信号和数据
    wire [31:0] ex_pc, inst;//当前指令pc值和指令内容
    wire [11:0] alu_op;//alu操作码
    wire [2:0] sel_alu_src1;//alu源操作数1选择信号
    wire [3:0] sel_alu_src2;//alu源操作数2选择信号
    wire data_ram_en;//数据存储器使能信号
    wire [3:0] data_ram_wen;//数据存储器写使能信号
    wire rf_we;//寄存器文件写使能信号
    wire [4:0] rf_waddr;//寄存器文件写地址
    wire sel_rf_res;//寄存器文件结果选择信号
    wire [31:0] rf_rdata1, rf_rdata2;//寄存器文件读数据1 和读数据2
    reg is_in_delayslot;//是否在延迟槽中

    // 将id_to_ex_bus_r中的信号分解到各个变量
    assign {
        ex_pc,          // 148:117
        inst,           // 116:85
        alu_op,         // 84:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata1,         // 63:32
        rf_rdata2          // 31:0
    } = id_to_ex_bus_r;

    //立即数扩展
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};//符号扩展
    assign imm_zero_extend = {16'b0, inst[15:0]};//0扩展
    assign sa_zero_extend = {27'b0,inst[10:6]};//移位量扩展

    //alu源操作数选择
    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc ://选pc
                      sel_alu_src1[2] ? sa_zero_extend : //选移位量
                      rf_rdata1;//默认选择寄存器文件读数据1

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend ://选符号扩展的立即数
                      sel_alu_src2[2] ? 32'd8 ://选常数8
                      sel_alu_src2[3] ? imm_zero_extend : //选0扩展的立即数
                      rf_rdata2;
    //alu实例化
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );

    assign ex_result = alu_result;//ex结果直接使用alu结果

    //ex结果传递到mem
    assign ex_to_mem_bus = {
        ex_pc,          // 75:44
        data_ram_en,    // 43
        data_ram_wen,   // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };

    // MUL part
    wire [63:0] mul_result;
    wire mul_signed; // 有符号乘法标记

    mul u_mul(
    	.clk        (clk            ),
        .resetn     (~rst           ),//复位信号（低电平有效）
        .mul_signed (mul_signed     ),
        .ina        (      ), // 乘法源操作数1
        .inb        (      ), // 乘法源操作数2
        .result     (mul_result     ) // 乘法结果 64bit
    );

    // DIV part
    wire [63:0] div_result;
    wire inst_div, inst_divu;//除法指令信号
    wire div_ready_i;//除法结果就绪信号
    reg stallreq_for_div;//流水线暂停请求
    assign stallreq_for_ex = stallreq_for_div;//将请求传递到ex阶段

    reg [31:0] div_opdata1_o;//除法操作数1
    reg [31:0] div_opdata2_o;
    reg div_start_o;//除法启动信号
    reg signed_div_o;//有符号除法标记

    div u_div(
    	.rst          (rst          ),
        .clk          (clk          ),
        .signed_div_i (signed_div_o ),
        .opdata1_i    (div_opdata1_o    ),
        .opdata2_i    (div_opdata2_o    ),
        .start_i      (div_start_o      ),
        .annul_i      (1'b0      ),//除法取消信号
        .result_o     (div_result     ), // 除法结果 64bit
        .ready_o      (div_ready_i      )
    );
    // 根据除法指令设置除法操作数和控制信号
    always @ (*) begin
        if (rst) begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
        end
        else begin
            stallreq_for_div = `NoStop;
            div_opdata1_o = `ZeroWord;
            div_opdata2_o = `ZeroWord;
            div_start_o = `DivStop;
            signed_div_o = 1'b0;
            case ({inst_div,inst_divu})
                2'b10:begin//有符号除法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b1;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                2'b01:begin//无符号除法
                    if (div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStart;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `Stop;
                    end
                    else if (div_ready_i == `DivResultReady) begin
                        div_opdata1_o = rf_rdata1;
                        div_opdata2_o = rf_rdata2;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                    else begin
                        div_opdata1_o = `ZeroWord;
                        div_opdata2_o = `ZeroWord;
                        div_start_o = `DivStop;
                        signed_div_o = 1'b0;
                        stallreq_for_div = `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end
    end

    // mul_result 和 div_result 可以直接使用
    
    
endmodule
