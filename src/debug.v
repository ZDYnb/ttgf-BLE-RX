module debug(
    input wire clk,                                 // 16MHz clock    
    input wire rst,                                 // reset                         
    input wire [3:0] I_BPF,                         // I_BPF input
    output reg clk_Debug,
    output reg [3:0] I_Debug                       // I_BPF passthrough
    
    );
    
    always@(posedge clk or negedge rst)begin     
        if (!rst) begin
            I_Debug <= 0;
        end 
        else begin
            I_Debug <= I_BPF;
        end
    end
    always@ * begin
        clk_Debug <= ~clk;
    end
endmodule