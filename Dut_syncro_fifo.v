// Code your design here

module synchronous_fifo #
  ( parameter Depth = 8, parameter Dwidth = 16 
  )(
    input clk,
    input rst,
    input wr_en,
    input rd_en,
    input [Dwidth-1:0] din,
    output reg [Dwidth-1:0] dout,
    output full, 
    output empty 
  );
  
       reg [$clog2(Depth)-1:0] wptr,rptr;
       reg [$clog2(Depth):0] count;
      
       reg [Dwidth-1:0]mem[0:Depth-1]; 
  
  always @(posedge clk) begin 
   
    if (rst) 
      begin
         wptr <= 0; 
         count <= 0;
         rptr <= 0; 
         dout <= 0; 
      end  
    else begin
      if(wr_en && !full) begin
        mem[wptr]<= din; 
        wptr <= wptr + 1'b1;
        count <= count + 1'b1;
      end 
    end 
    if (rd_en && !empty) begin
      dout <= mem[rptr];
      rptr <= rptr + 1'b1;
      count <= count - 1'b1;
    end 
  end
  
  assign empty = (count == 1'b0);
  
  assign full = (count == Depth); 

endmodule
