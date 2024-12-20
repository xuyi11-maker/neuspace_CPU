`include "lib/defines.vh"
module CTRL(
    input wire rst,
    input wire stallreq_for_ex,      // 来自 EX 阶段的停顿请求
    input wire stallreq_for_load,    // 来自 load 指令的停顿请求
    input wire int_req,              // 外部中断请求

    output reg flush,                // 是否需要刷新流水线
    output reg [`StallBus-1:0] stall // 流水线停顿信号
);  
    always @ (*) begin
        if (rst) begin
            stall = `StallBus'b0;
            flush = 1'b0;
        end
        else begin
            // 处理外部中断请求
            if (int_req) begin
                flush = 1'b1;    // 外部中断时，刷新流水线
                stall = `StallBus'b0;  // 不需要停顿
            end
            else begin
                // 如果来自 EX 阶段或者 load 的停顿请求，发出停顿信号
                if (stallreq_for_ex || stallreq_for_load) begin
                    stall = `StallBus'b1;  // 停顿流水线
                end
                else begin
                    stall = `StallBus'b0;  // 正常运行，不停顿
                end
                flush = 1'b0;
            end
        end
    end

endmodule