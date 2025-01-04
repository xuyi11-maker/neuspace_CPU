`include "lib/defines.vh" 

module mycpu_core(
    input wire clk,               // 时钟信号
    input wire rst,               // 复位信号
    input wire [5:0] int,         // 中断信号

    output wire inst_sram_en,     // 指令存储器使能信号
    output wire [3:0] inst_sram_wen,  // 指令存储器写使能信号
    output wire [31:0] inst_sram_addr,  // 指令存储器地址
    output wire [31:0] inst_sram_wdata, // 指令存储器写数据
    input wire [31:0] inst_sram_rdata,  // 指令存储器读数据

    output wire data_sram_en,     // 数据存储器使能信号
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr, 
    output wire [31:0] data_sram_wdata,
    input wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,  // 调试用的写回阶段PC值
    output wire [3:0] debug_wb_rf_wen,  // 调试用的寄存器文件写使能信号
    output wire [4:0] debug_wb_rf_wnum, // 调试用的寄存器文件写地址
    output wire [31:0] debug_wb_rf_wdata  // 调试用的寄存器文件写数据
);

    // 定义模块之间的总线信号
    wire [`IF_TO_ID_WD-1:0] if_to_id_bus;  // IF阶段到ID阶段的总线，宽度为33位
    wire [`ID_TO_EX_WD-1:0] id_to_ex_bus;  // ID阶段到EX阶段的总线，宽度为231位
    wire [`EX_TO_MEM_WD-1:0] ex_to_mem_bus;  // EX阶段到MEM阶段的总线，宽度为80位
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;  // MEM阶段到WB阶段的总线，宽度为70位
    wire [`BR_WD-1:0] br_bus;  // 分支控制信号总线，宽度为33位
    wire [`DATA_SRAM_WD-1:0] ex_dt_sram_bus;  // EX阶段到数据存储器的总线，宽度为69位
    wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus;  // WB阶段到寄存器文件的总线，宽度为38位
    wire [`StallBus-1:0] stall;  // 流水线暂停信号，宽度为6位
    wire [37:0] ex_to_id_bus;  // EX阶段到ID阶段的总线，宽度为38位
    wire [37:0] mem_to_id_bus;  // MEM阶段到ID阶段的总线，宽度为38位
    wire [37:0] wb_to_id_bus;  // WB阶段到ID阶段的总线，宽度为38位
    wire inst_is_load;  // 当前指令是否为加载指令
    wire [65:0] ex_to_mem1;  // EX阶段到MEM阶段的额外总线，宽度为66位
    wire [65:0] mem_to_wb1;  // MEM阶段到WB阶段的额外总线，宽度为66位
    wire [65:0] wb_to_id_wf;  // WB阶段到ID阶段的额外总线，宽度为66位
    wire [65:0] ex_to_id_2;  // EX阶段到ID阶段的额外总线，宽度为66位
    wire [65:0] mem_to_id_2;  // MEM阶段到ID阶段的额外总线，宽度为66位
    wire [65:0] wb_to_id_2;  // WB阶段到ID阶段的额外总线，宽度为66位
    wire stallreq_for_ex;  // EX阶段请求暂停信号
    wire ready_ex_to_id;  // EX阶段到ID阶段的数据准备好信号

    IF u_IF(
        .clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );

    ID u_ID(
        .clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .stallreq        (stallreq        ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_rdata (inst_sram_rdata ),
        .wb_to_rf_bus    (wb_to_rf_bus    ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_id_bus    (ex_to_id_bus    ),
        .mem_to_id_bus   (mem_to_id_bus   ),
        .wb_to_id_bus    (wb_to_id_bus    ),
        .br_bus          (br_bus          ),
        .stallreq_for_id (stallreq_for_id ),
        .inst_is_load    (inst_is_load    ),
        .wb_to_id_wf     (wb_to_id_wf     ),
        .ex_to_id_2      (ex_to_id_2      ),
        .mem_to_id_2     (mem_to_id_2     ),
        .wb_to_id_2      (wb_to_id_2      ),
        .ready_ex_to_id  (ready_ex_to_id  )
    );

    EX u_EX(
        .clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .ex_to_id_bus    (ex_to_id_bus    ),
        .data_sram_en    (data_sram_en    ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata ),
        .inst_is_load    (inst_is_load    ),
        .ex_to_mem1      (ex_to_mem1      ),
        .ex_to_id_2      (ex_to_id_2      ),
        .stallreq_for_ex (stallreq_for_ex ),
        .ready_ex_to_id  (ready_ex_to_id  )
    );

    MEM u_MEM(
        .clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .ex_to_mem_bus   (ex_to_mem_bus   ),
        .mem_to_id_bus   (mem_to_id_bus   ),
        .data_sram_rdata (data_sram_rdata ),
        .mem_to_wb_bus   (mem_to_wb_bus   ),
        .ex_to_mem1      (ex_to_mem1      ),
        .mem_to_wb1      (mem_to_wb1      ),
        .mem_to_id_2     (mem_to_id_2     )
    );

    WB u_WB(
        .clk               (clk               ),
        .rst               (rst               ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_id_bus      (wb_to_id_bus      ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata ),
        .mem_to_wb1        (mem_to_wb1        ),
        .wb_to_id_wf       (wb_to_id_wf       ),
        .wb_to_id_2        (wb_to_id_2        )
    );

    CTRL u_CTRL(
        .rst               (rst               ),
        .stall             (stall             ),
        .stallreq_for_id   (stallreq_for_id   ),
        .stallreq_for_ex   (stallreq_for_ex   )
    );

endmodule
