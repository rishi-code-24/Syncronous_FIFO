// Code your testbench here
`timescale 1ns/1ps

module tb_synchronous_fifo;

                                                         // Parameters
  parameter Depth  = 16;
  parameter Dwidth = 16;

                                                         // DUT Signals
  reg                  clk;
  reg                  rst;
  reg                  wr_en;
  reg                  rd_en;
  reg     [Dwidth-1:0] din;
  wire    [Dwidth-1:0] dout;
  wire                 full;
  wire                 empty;

                                                          // Instantiate DUT
  synchronous_fifo #(
    .Depth(Depth),
    .Dwidth(Dwidth)
  ) dut (
    .clk   (clk),
    .rst   (rst),
    .wr_en (wr_en),
    .rd_en (rd_en),
    .din   (din),
    .dout  (dout),
    .full  (full),
    .empty (empty)
  );
     
                                     // Clock generation (10ns period)
    always #5 clk = ~clk;
  
  
  initial begin
   clk<=0;
    $dumpfile("synchronous_fifo.vcd");
    $dumpvars(0, tb_synchronous_fifo);
  
  end

initial
    begin
 
      rst = 1;
      wr_en = 0;
      rd_en = 0;
      din = 0;
      
   
     #10 
      rst = 0;
      
      $display("Start test");
      
      
      write_fifo; 
      read_fifo;
      
      $display("end test");
      
      #40 $finish;
    end

  
  // Reset task
  
  task reset_fifo;
    begin
      rst   = 1;
      wr_en = 0;
      rd_en = 0;
      din   = 0;
      
       
      if(rst)
        $display("[%0t] Reset test : pass" , $time);
      else
        $display("[%0t] Reset test : fail" , $time);

      
    end
  endtask

  
  // Write task
  
  
  task write_fifo;
    
       integer i;
    begin
      for(i=0; i< Depth; i=i+1)begin
        @(posedge clk);
              wr_en <= 1;
              din   <= $random + 1'b1;
         
        @(posedge clk);
           wr_en <= 0;
           
        
      end
    
      if(!full)
        $display("[%0t] Write test : pass" , $time);
      else
        $display("[%0t] Write test : fail" , $time);

    end
  endtask

  
  // Read task
  
  
  task read_fifo;
     integer i;
      begin
        for(i=0; i< Depth; i=i+1)
        begin     
          @(negedge clk) 
            rd_en = 1;
         
      
          @(negedge clk);
            rd_en = 0;
     
      end
      
        if(empty)
              $display("[%0t] Read test : pass" , $time);
           else
              $display("[%0t] Read test : fail" , $time);
      end
  endtask

 
   // overflow test
  
  
  task over_flow_fifo;
  
    integer i;
     begin
       for(i=0; i<Depth; i=i+1)begin
         @(posedge clk)
          wr_en <= 1;
          rd_en = 0;
          din   <= $random + 1'b1;
          
       end
          @(posedge clk)
            wr_en <= 0;
          
       $display("Start overflow write...");
         
       @(posedge clk)begin;
         wr_en <= 1;
         din   <= 16'hDEAD;
       end
       
       @(posedge clk)
       wr_en <= 0;
       
     if (full)
       $display("PASS: Overflow write blocked");
     else
       $display("FAIL: FIFO FULL deasserted during overflow");
         
         
         
    $display("Reading FIFO...");
       
        for (i = 0; i < Depth; i = i + 1) begin
           @(posedge clk)
             wr_en <= 0;
             rd_en <= 1;
    end

           @(posedge clk)
             rd_en <= 0;

    if (empty)
      $display("PASS: FIFO EMPTY after reads");
    else
      $display("FAIL: FIFO not EMPTY after reads");

          
      
     end
 endtask
  
  
  // Under flow test
  
  
  task under_flow_fifo;
      
    integer i;
     begin                                    // step-1: fill fifo
       for(i=0; i<Depth; i=i+1) begin
         @(posedge clk)begin
          wr_en <= 1;
          rd_en <= 0;
          din <= $random + 1'b1;
         end
       end   
       
         @(posedge clk)
           wr_en <= 0;
           rd_en <= 0;
     end
    
       if (!full)
         $display("[%0t] PASS: FIFOfull after Write test", $time);
      else
        $display("[%0t] FAIL: FIFO not full after writes", $time);
      
      // step-2: empty fifo
      
      $display("Attempting UNDERFLOW read...");
       
    for(i=0;i<Depth; i=i+1)begin
      @(posedge clk) begin
            rd_en <= 1;
            wr_en <= 0;
      end
    end
    @(posedge clk)begin
           rd_en = 0;
    end
   
    if (empty)
       $display("[%0t] PASS: FIFO EMPTY after reads", $time);
    else
       $display("[%0t] FAIL: FIFO not EMPTY after reads", $time);
    
    
    // step -3: Underflow read (extra read when empty)
   
    $display("[%0t] Attempting UNDERFLOW read...", $time);
    
    @(posedge clk) begin
      
      rd_en <=1;
    end
    
    @(posedge clk)begin
      
      rd_en <= 0;
      
    end
    
     if (empty)
      $display("[%0t] PASS: FIFO remains EMPTY during underflow", $time);
    else
      $display("[%0t] FAIL: FIFO EMPTY deasserted during underflow", $time);
    
    
  endtask
  
  
  // wrap test
  
  
  task wrap_around_fifo;
       integer i;
    begin                             // step-1: fill fifo
      
      $display("Attempting Wrap Around write...");         
      
      for(i=0; i< Depth; i=i+1)begin
        @(posedge clk)begin
              wr_en <= 1;
              rd_en <=0;
              din   <= $random + 1'b1;
        end
      end
      
      @(posedge clk)
      
           wr_en <= 0;
           rd_en <= 0;
      
      end
    
      if(!full)
        $display("[%0t] Write test : pass" , $time);
      else
        $display("[%0t] Write test : fail" , $time);
    
    
      // step-2: empty fifo
    
    $display("Attempting Wrap Around Read...");
    
    for(i=0; i<Depth; i=i+1)begin
      @(posedge clk)begin
        
        rd_en <= 1;
        wr_en <= 0;
      
      end
    end
      
    @(posedge clk)begin
      
      rd_en <= 0;
    
    end
    
      if (empty)
       $display("[%0t] PASS: FIFO EMPTY after reads", $time);
    else
       $display("[%0t] FAIL: FIFO not EMPTY after reads", $time);
    
    // step -3: Wrap around ( extra write Again)
    
    $display("Attempting Wrap Around Again write...");
    
    @(posedge clk)begin
      
      wr_en <= 1;
      din <= $random + 1'b1;
    end
    
    @(posedge clk) begin
      
      wr_en <=0;
      
    end
    
    if (!full)
      $display("[%0t] PASS: FIFO Again write ", $time);
    else
      $display("[%0t] FAIL: FIFO Not write again", $time);
    
    
    //Step -4: Wrap around ( extra read again) 
    
    $display("Attempting Wrap Around Again Read...");
    
    @(posedge clk) begin
      
      rd_en <= 1;
      
    end
    
    @(posedge clk) begin
      
      rd_en <= 0;
    end
      
      if (empty)
        $display("[%0t] PASS: FIFO remains EMPTY after read", $time);
    else
      $display("[%0t] FAIL: FIFO EMPTY deasserted after read", $time);
 
      
  endtask
  
  
endmodule
