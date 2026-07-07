`include "uvm_macros.svh"
import uvm_pkg::*;

// ---------- INTERFACE ----------
interface fifo_if(input clk);
  logic reset, rd_en, wt_en;
  logic [15:0] fifo_in, fifo_out;
  logic fifo_full, fifo_empty;
endinterface

// ---------- TRANSACTION ----------
class fifo_txn extends uvm_sequence_item;
  rand bit [15:0] data;
  rand bit rd_en, wt_en;
  bit reset;
  bit [15:0] out;
  bit full, empty;
  `uvm_object_utils(fifo_txn)
  function new(string name="txn"); super.new(name); endfunction
endclass

// ---------- SEQUENCES ----------
class reset_seq extends uvm_sequence #(fifo_txn);
  `uvm_object_utils(reset_seq)
  function new(string name="reset_seq"); super.new(name); endfunction
  task body();
    fifo_txn t;
    t=fifo_txn::type_id::create("t");
    start_item(t); t.reset=1; t.wt_en=0; t.rd_en=0; finish_item(t);
    t=fifo_txn::type_id::create("t");
    start_item(t); t.reset=0; finish_item(t);
  endtask
endclass

class write_seq extends uvm_sequence #(fifo_txn);
  `uvm_object_utils(write_seq)
  function new(string name="write_seq"); super.new(name); endfunction
  task body(); fifo_txn t;
    repeat(8) begin
      t=fifo_txn::type_id::create("t");
      start_item(t);
      assert(t.randomize() with {wt_en==1; rd_en==0;});
      finish_item(t);
    end
  endtask
endclass

class read_seq extends uvm_sequence #(fifo_txn);
  `uvm_object_utils(read_seq)
  function new(string name="read_seq"); super.new(name); endfunction
  task body(); fifo_txn t;
    repeat(5) begin
      t=fifo_txn::type_id::create("t");
      start_item(t); t.wt_en=0; t.rd_en=1; finish_item(t);
    end
  endtask
endclass

class simult_seq extends uvm_sequence #(fifo_txn);
  `uvm_object_utils(simult_seq)
  function new(string name="simult_seq"); super.new(name); endfunction
  task body(); fifo_txn t;
    repeat(2) begin
      t=fifo_txn::type_id::create("t");
      start_item(t);
      assert(t.randomize() with {wt_en==1; rd_en==1;});
      finish_item(t);
    end
  endtask
endclass



// ---------- DRIVER ----------

class fifo_driver extends uvm_driver #(fifo_txn);
  `uvm_component_utils(fifo_driver)
  virtual fifo_if vif;

  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    void'(uvm_config_db#(virtual fifo_if)::get(this,"","vif",vif));
  endfunction

 task run_phase(uvm_phase phase);
  fifo_txn t;

  forever begin
    seq_item_port.get_next_item(t);

    @(posedge vif.clk);
    vif.reset   <= t.reset;
    vif.wt_en   <= t.wt_en;
    vif.rd_en   <= t.rd_en;   
    vif.fifo_in <= t.data;

    @(posedge vif.clk);
    vif.wt_en <= 0;
    vif.rd_en <= 0;

    seq_item_port.item_done();
  end
endtask
endclass

// ---------- MONITOR ----------

class fifo_monitor extends uvm_component;
  `uvm_component_utils(fifo_monitor)

  virtual fifo_if vif;
  uvm_analysis_port #(fifo_txn) ap;

  function new(string name,uvm_component parent);
    super.new(name,parent);
    ap=new("ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    void'(uvm_config_db#(virtual fifo_if)::get(this,"","vif",vif));
  endfunction

  task run_phase(uvm_phase phase);
    fifo_txn t;
    bit prev_rd;  

    forever begin
      @(posedge vif.clk);

      t = fifo_txn::type_id::create("t");

      t.reset = vif.reset;
      t.wt_en = vif.wt_en;
      t.rd_en = vif.rd_en;
      t.data  = vif.fifo_in;
      t.full  = vif.fifo_full;
      t.empty = vif.fifo_empty;

    
      if(prev_rd)
        t.out = vif.fifo_out;

      prev_rd = vif.rd_en;

      
      `uvm_info("MON",
        $sformatf("RST=%0b WR=%0b RD=%0b DIN=%0d DOUT=%0d FULL=%0b EMPTY=%0b",
        t.reset, t.wt_en, t.rd_en, t.data, t.out, t.full, t.empty),
        UVM_LOW)

      ap.write(t);
    end
  endtask

endclass

class fifo_sequencer extends uvm_sequencer #(fifo_txn);
  `uvm_component_utils(fifo_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass



// ---------- SCOREBOARD ----------

class fifo_scoreboard extends uvm_component;
  `uvm_component_utils(fifo_scoreboard)

  uvm_analysis_imp #(fifo_txn,fifo_scoreboard) imp;

  bit [15:0] q[$];
  bit rd_d;   

  function new(string name,uvm_component parent);
    super.new(name,parent);
    imp=new("imp",this);
  endfunction

  function void write(fifo_txn t);

    // ---------------- RESET ----------------
   
    if(t.reset) begin 
      q.delete(); 
      rd_d = 0;
      `uvm_info("SB","RESET: Queue cleared",UVM_LOW) 
      return; 
    end

   
    if(rd_d) begin
      if(q.size() > 0 && !t.empty) begin
        bit [15:0] exp = q.pop_front();

        
        `uvm_info("SB",
          $sformatf("READ: EXP=%0d ACT=%0d QSIZE=%0d",
            exp, t.out, q.size()),
          UVM_LOW)

        if(exp !== t.out)
          `uvm_error("SB",
            $sformatf("MISMATCH: EXP=%0d ACT=%0d",
              exp, t.out))
      end
      else begin
        `uvm_warning("SB",
          $sformatf("UNDERFLOW: QSIZE=%0d EMPTY=%0b",
            q.size(), t.empty))
      end
    end

    
    
      if(t.wt_en && !t.full) begin
      q.push_back(t.data);

      
      `uvm_info("SB",
        $sformatf("WRITE: DATA=%0d QSIZE=%0d",
          t.data, q.size()),
        UVM_LOW)
    end

      rd_d = t.rd_en;

  endfunction

endclass

// ---------- AGENT ----------

class fifo_agent extends uvm_component;
  `uvm_component_utils(fifo_agent)
  fifo_monitor mon; fifo_driver drv; fifo_sequencer seqr;

  function new(string name,uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    mon=fifo_monitor::type_id::create("mon",this);
    drv=fifo_driver::type_id::create("drv",this);
    seqr=fifo_sequencer::type_id::create("seqr",this);
  endfunction

  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(seqr.seq_item_export);
  endfunction
endclass
      
      
  class fifo_coverage extends uvm_component;
  `uvm_component_utils(fifo_coverage)

  uvm_analysis_imp #(fifo_txn, fifo_coverage) imp;
  fifo_txn t;

  covergroup cg;

    option.per_instance = 1;

    // basic operations
    cp_wr    : coverpoint t.wt_en;
    cp_rd    : coverpoint t.rd_en;

    // status flags
    cp_full  : coverpoint t.full;
    cp_empty : coverpoint t.empty;

    // simultaneous operation
    cross_wr_rd : cross t.wt_en, t.rd_en;

  endgroup

    
    
  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    imp = new("imp", this);
  endfunction

  function void write(fifo_txn tx);
    t = tx;
    cg.sample();
  endfunction

  function void final_phase(uvm_phase phase);
    `uvm_info("COV",
      $sformatf("FUNCTIONAL COVERAGE = %0.2f%%", cg.get_coverage()),
      UVM_LOW)
  endfunction

endclass

class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)

  fifo_agent agt;
  fifo_scoreboard sb;
  fifo_coverage cov;

  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agt = fifo_agent::type_id::create("agt", this);
    sb  = fifo_scoreboard::type_id::create("sb", this);
    cov = fifo_coverage::type_id::create("cov", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    agt.mon.ap.connect(sb.imp);
    agt.mon.ap.connect(cov.imp);
  endfunction

endclass
      
      
      
// ---------- TEST ----------
      
class fifo_test extends uvm_test;
  `uvm_component_utils(fifo_test)

  fifo_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    env = fifo_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);

    reset_seq rst;
    write_seq w;
    read_seq r;
    simult_seq s;  

    phase.raise_objection(this);

    rst = reset_seq::type_id::create("rst");
    w   = write_seq::type_id::create("w");
    r   = read_seq::type_id::create("r");
    s   = simult_seq::type_id::create("s"); 

    // 1. Reset
    rst.start(env.agt.seqr);

    // 2. Write operations
    w.start(env.agt.seqr);

    // 3. Read operations
    r.start(env.agt.seqr);

    // 4. Simultaneous read/write 
    s.start(env.agt.seqr);

    phase.drop_objection(this);

  endtask

endclass
  
      
// ---------- TOP ----------

      
module top;
  bit clk=0; always #5 clk=~clk;
  fifo_if vif(clk);

  syn_fifo dut(
    .clk(clk), .reset(vif.reset),
    .wt_en(vif.wt_en), .rd_en(vif.rd_en),
    .fifo_in(vif.fifo_in), .fifo_out(vif.fifo_out),
    .fifo_full(vif.fifo_full), .fifo_empty(vif.fifo_empty)
  );

  initial begin
    uvm_config_db#(virtual fifo_if)::set(null,"*","vif",vif);
    run_test("fifo_test");
  end

  
 
  initial begin
    $dumpfile("fifo.vcd");
    $dumpvars(0, top);
  end

endmodule
