module axi_mesh
import cf_math_pkg::idx_width;
#(
  /// Configuration struct for the crossbar see `axi_pkg` for fields and definitions. crossbar的配置结构参见`axi_pkg`的字段和定义。
  parameter axi_pkg::xbar_cfg_t Cfg                                   = '0,
  /// Enable atomic operations support. 原子操作
  parameter bit  ATOPs                                                = 1'b1,
  /// Connectivity matrix 互联矩阵
  parameter bit [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts-1:0] Connectivity = '1,
  /// AXI4+ATOP AW channel struct type for the slave ports.
  parameter type slv_aw_chan_t                                        = logic,
  /// AXI4+ATOP AW channel struct type for the master ports.
  parameter type mst_aw_chan_t                                        = logic,
  /// AXI4+ATOP W channel struct type for all ports.
  parameter type w_chan_t                                             = logic,
  /// AXI4+ATOP B channel struct type for the slave ports.
  parameter type slv_b_chan_t                                         = logic,
  /// AXI4+ATOP B channel struct type for the master ports.
  parameter type mst_b_chan_t                                         = logic,
  /// AXI4+ATOP AR channel struct type for the slave ports.  
  parameter type slv_ar_chan_t                                        = logic,
  /// AXI4+ATOP AR channel struct type for the master ports.
  parameter type mst_ar_chan_t                                        = logic,
  /// AXI4+ATOP R channel struct type for the slave ports.  
  parameter type slv_r_chan_t                                         = logic,
  /// AXI4+ATOP R channel struct type for the master ports.
  parameter type mst_r_chan_t                                         = logic,
  /// AXI4+ATOP request struct type for the slave ports.
  parameter type slv_req_t                                            = logic,
  /// AXI4+ATOP response struct type for the slave ports.
  parameter type slv_resp_t                                           = logic,
  /// AXI4+ATOP request struct type for the master ports.
  parameter type mst_req_t                                            = logic,
  /// AXI4+ATOP response struct type for the master ports
  parameter type mst_resp_t                                           = logic,
  /// Maximum number of different IDs that can be in flight at each slave port.  Reads and writes
  /// are counted separately (except for ATOPs, which count as both read and write).
  ///
  /// It is legal for upstream to have transactions with more unique IDs than the maximum given by
  /// this parameter in flight, but a transaction exceeding the maximum will be stalled until all
  /// transactions of another ID complete.
  parameter int unsigned AxiSlvPortMaxUniqIds 						  = 32'd0,
  /// Maximum number of in-flight transactions with the same ID at the slave port.
  ///
  /// This parameter is only relevant if `AxiSlvPortMaxUniqIds <= 2**AxiMstPortIdWidth`.  In that
  /// case, this parameter is passed to [`axi_id_remap` as `AxiMaxTxnsPerId`
  /// parameter](module.axi_id_remap#parameter.AxiMaxTxnsPerId).
  parameter int unsigned AxiMaxTxnsPerId 					          = 32'd0,
  
  parameter int unsigned NoTiles									  = 32'd4,
  
  parameter type rule_t                                               = axi_pkg::xbar_rule_64_t
`ifdef VCS
  , localparam int unsigned MstPortsIdxWidth =
      (Cfg.NoMstPorts == 32'd1) ? 32'd1 : unsigned'($clog2(Cfg.NoMstPorts))
`endif
) (
  /// Clock, positive edge triggered.
  input  logic                                                          clk_i,
  /// Asynchronous reset, active low.  
  input  logic                                                          rst_ni,
  /// Testmode enable, active high.
  input  logic                                                          test_i,
  /// AXI4+ATOP requests to the slave ports.  
  input  slv_req_t  [NoTiles-1:0]                                       slv_ports_req_i,
  /// AXI4+ATOP responses of the slave ports.  
  output slv_resp_t [NoTiles-1:0]                                       slv_ports_resp_o,
  /// AXI4+ATOP requests of the master ports.  
  output mst_req_t  [NoTiles-1:0]                                       mst_ports_req_o,
  /// AXI4+ATOP responses to the master ports.  
  input  mst_resp_t [NoTiles-1:0]                                       mst_ports_resp_i,
  
  input  rule_t     [Cfg.NoAddrRules-1:0]                               addr_map_i,
  /// Enable default master port.
  input  logic      [Cfg.NoSlvPorts-1:0]                                en_default_mst_port_i,
`ifdef VCS
    
  input  logic      [Cfg.NoSlvPorts-1:0][MstPortsIdxWidth-1:0]          default_mst_port_i
`else
  
  input  logic      [Cfg.NoSlvPorts-1:0][idx_width(Cfg.NoMstPorts)-1:0] default_mst_port_i
`endif
);

localparam int unsigned AxiIdWidthMstPorts = Cfg.AxiIdWidthSlvPorts + 3;//$clog2(Cfg.NoSlvPorts);

/////////////////////////////////////////////
// addr_map rule

rule_t [Cfg.NoAddrRules-1:0] addr_map_00;
rule_t [Cfg.NoAddrRules-1:0] addr_map_01;
rule_t [Cfg.NoAddrRules-1:0] addr_map_10;
rule_t [Cfg.NoAddrRules-1:0] addr_map_11;

assign addr_map_00 = '{
'{idx: 0, start_addr: 32'h0000_0000, end_addr: 32'h0000_2000},
 
'{idx: 1, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},
'{idx: 2, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},

'{idx: 3, start_addr: 32'h0000_4000, end_addr: 32'h0000_6000},
'{idx: 4, start_addr: 32'h0000_2000, end_addr: 32'h0000_4000},
'{idx: 4, start_addr: 32'h0000_6000, end_addr: 32'h0000_8000}
};

assign addr_map_01 = '{
'{idx: 0, start_addr: 32'h0000_2000, end_addr: 32'h0000_4000},
 
'{idx: 1, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},

'{idx: 2, start_addr: 32'h0000_0000, end_addr: 32'h0000_2000},
'{idx: 2, start_addr: 32'h0000_4000, end_addr: 32'h0000_6000},
'{idx: 3, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},

'{idx: 4, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff}
};

assign addr_map_10 = '{
'{idx: 0, start_addr: 32'h0000_4000, end_addr: 32'h0000_6000}, 
'{idx: 1, start_addr: 32'h0000_0000, end_addr: 32'h0000_2000},

'{idx: 2, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},
'{idx: 3, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},

'{idx: 4, start_addr: 32'h0000_6000, end_addr: 32'h0000_8000},
'{idx: 4, start_addr: 32'h0000_2000, end_addr: 32'h0000_4000}
};

assign addr_map_11 = '{
'{idx: 0, start_addr: 32'h0000_6000, end_addr: 32'h0000_8000}, 
'{idx: 1, start_addr: 32'h0000_2000, end_addr: 32'h0000_4000},
'{idx: 2, start_addr: 32'h0000_4000, end_addr: 32'h0000_6000},
'{idx: 2, start_addr: 32'h0000_0000, end_addr: 32'h0000_2000},

'{idx: 3, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff},
'{idx: 4, start_addr: 32'h8000_0000, end_addr: 32'hffff_ffff}
};

/////////////////////////////////////////////
// Interconnect

  // xbar master ports
  mst_req_t  [Cfg.NoMstPorts-1:0] xbar_mst_req_00;
  mst_req_t  [Cfg.NoMstPorts-1:0] xbar_mst_req_01;
  mst_req_t  [Cfg.NoMstPorts-1:0] xbar_mst_req_10;
  mst_req_t  [Cfg.NoMstPorts-1:0] xbar_mst_req_11;
  mst_resp_t [Cfg.NoMstPorts-1:0] xbar_mst_resp_00;
  mst_resp_t [Cfg.NoMstPorts-1:0] xbar_mst_resp_01;
  mst_resp_t [Cfg.NoMstPorts-1:0] xbar_mst_resp_10;
  mst_resp_t [Cfg.NoMstPorts-1:0] xbar_mst_resp_11;

  // xbar slave ports
  slv_req_t  [Cfg.NoSlvPorts-1:0] xbar_slv_req_00;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xbar_slv_req_01;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xbar_slv_req_10;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xbar_slv_req_11;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xbar_slv_resp_00;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xbar_slv_resp_01;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xbar_slv_resp_10;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xbar_slv_resp_11;
  
  // xp master ports
  slv_req_t  [Cfg.NoSlvPorts-1:0] xp_mst_req_00;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xp_mst_req_01;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xp_mst_req_10;
  slv_req_t  [Cfg.NoSlvPorts-1:0] xp_mst_req_11;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xp_mst_resp_00;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xp_mst_resp_01;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xp_mst_resp_10;
  slv_resp_t [Cfg.NoSlvPorts-1:0] xp_mst_resp_11;
  
  ///////////////////// 
  // (0,0) ==> (0,1) 
  assign xbar_slv_req_01[2] = xp_mst_req_00[4];
  assign xp_mst_resp_00[4]  = xbar_slv_resp_01[2];
  // (0,0) <== (0,1)
  assign xbar_slv_req_00[4] = xp_mst_req_01[2];
  assign xp_mst_resp_01[2]  = xbar_slv_resp_00[4];
  
  ///////////////////// 
  // (0,0) ==> (1,0) 
  assign xbar_slv_req_10[1] = xp_mst_req_00[3];
  assign xp_mst_resp_00[3]  = xbar_slv_resp_10[1];
  // (0,0) <== (1,0)
  assign xbar_slv_req_00[3] = xp_mst_req_10[1];
  assign xp_mst_resp_10[1]  = xbar_slv_resp_00[3];
  
  ///////////////////// 
  // (0,1) ==> (1,1) 
  assign xbar_slv_req_11[1] = xp_mst_req_01[3];
  assign xp_mst_resp_01[3]  = xbar_slv_resp_11[1];
  // (0,1) <== (1,1)
  assign xbar_slv_req_01[3] = xp_mst_req_11[1];
  assign xp_mst_resp_11[1]  = xbar_slv_resp_01[3];
  
  ///////////////////// 
  // (1,0) ==> (1,1) 
  assign xbar_slv_req_11[2] = xp_mst_req_10[4];
  assign xp_mst_resp_10[4]  = xbar_slv_resp_11[2];
  // (1,0) <== (1,1)
  assign xbar_slv_req_10[4] = xp_mst_req_11[2];
  assign xp_mst_resp_11[2]  = xbar_slv_resp_10[4];
  
  /////////////////////////////////////////////
  // input/output with Tiles

  assign xbar_slv_req_00[0]  = slv_ports_req_i[0];
  assign slv_ports_resp_o[0] = xbar_slv_resp_00[0];
  assign mst_ports_req_o[0]  = xbar_mst_req_00[0];
  assign xbar_mst_resp_00[0] = mst_ports_resp_i[0];
  
  assign xbar_slv_req_01[0]  = slv_ports_req_i[1];
  assign slv_ports_resp_o[1] = xbar_slv_resp_01[0];
  assign mst_ports_req_o[1]  = xbar_mst_req_01[0];
  assign xbar_mst_resp_01[0] = mst_ports_resp_i[1];
  
  assign xbar_slv_req_10[0]  = slv_ports_req_i[2];
  assign slv_ports_resp_o[2] = xbar_slv_resp_10[0];
  assign mst_ports_req_o[2]  = xbar_mst_req_10[0];
  assign xbar_mst_resp_10[0] = mst_ports_resp_i[2];
  
  assign xbar_slv_req_11[0]  = slv_ports_req_i[3];
  assign slv_ports_resp_o[3] = xbar_slv_resp_11[0];
  assign mst_ports_req_o[3]  = xbar_mst_req_11[0];
  assign xbar_mst_resp_11[0] = mst_ports_resp_i[3];
  

/////////////////////////////////////////////
//xp(0,0)

axi_xbar #(
    .Cfg            ( Cfg            ),
    .ATOPs          ( ATOPs          ),
    .Connectivity   ( Connectivity   ),
    .slv_aw_chan_t  ( slv_aw_chan_t  ),
    .mst_aw_chan_t  ( mst_aw_chan_t  ),
    .w_chan_t       ( w_chan_t       ),
    .slv_b_chan_t   ( slv_b_chan_t   ),
    .mst_b_chan_t   ( mst_b_chan_t   ),
    .slv_ar_chan_t  ( slv_ar_chan_t  ),
    .mst_ar_chan_t  ( mst_ar_chan_t  ),
    .slv_r_chan_t   ( slv_r_chan_t   ),
    .mst_r_chan_t   ( mst_r_chan_t   ),
    .slv_req_t      ( slv_req_t      ),
    .slv_resp_t     ( slv_resp_t     ),
    .mst_req_t      ( mst_req_t      ),
    .mst_resp_t     ( mst_resp_t     ),
    .rule_t         ( rule_t         )
  ) i_xbar_00 (
    .clk_i,
    .rst_ni,
    .test_i                 ( test_en_i                               ),
    .slv_ports_req_i        ( xbar_slv_req_00                         ),
    .slv_ports_resp_o       ( xbar_slv_resp_00                        ),
    .mst_ports_req_o        ( xbar_mst_req_00                         ),
    .mst_ports_resp_i       ( xbar_mst_resp_00                        ),
    .addr_map_i				( addr_map_00							  ),
    .en_default_mst_port_i  ( '0                                      ),
    .default_mst_port_i     ( '0                                      )
  );
  
  for (genvar i = 1; i < Cfg.NoMstPorts; i++) begin : gen_remap_00
    axi_id_remap #(
      .AxiSlvPortIdWidth    ( AxiIdWidthMstPorts     ),
      .AxiSlvPortMaxUniqIds ( AxiSlvPortMaxUniqIds   ),
      .AxiMaxTxnsPerId      ( AxiMaxTxnsPerId        ),
      .AxiMstPortIdWidth    ( Cfg.AxiIdWidthSlvPorts ),
      .slv_req_t            ( mst_req_t              ),
      .slv_resp_t           ( mst_resp_t             ),
      .mst_req_t            ( slv_req_t              ),
      .mst_resp_t           ( slv_resp_t             )
    ) i_axi_id_remap_00 (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( xbar_mst_req_00[i]   ),
      .slv_resp_o ( xbar_mst_resp_00[i]  ),
      .mst_req_o  ( xp_mst_req_00[i]     ),
      .mst_resp_i ( xp_mst_resp_00[i]    )
    );
  end
  
  
 /////////////////////////////////////////////
//xp(0,1)

axi_xbar #(
    .Cfg            ( Cfg            ),
    .ATOPs          ( ATOPs          ),
    .Connectivity   ( Connectivity   ),
    .slv_aw_chan_t  ( slv_aw_chan_t  ),
    .mst_aw_chan_t  ( mst_aw_chan_t  ),
    .w_chan_t       ( w_chan_t       ),
    .slv_b_chan_t   ( slv_b_chan_t   ),
    .mst_b_chan_t   ( mst_b_chan_t   ),
    .slv_ar_chan_t  ( slv_ar_chan_t  ),
    .mst_ar_chan_t  ( mst_ar_chan_t  ),
    .slv_r_chan_t   ( slv_r_chan_t   ),
    .mst_r_chan_t   ( mst_r_chan_t   ),
    .slv_req_t      ( slv_req_t      ),
    .slv_resp_t     ( slv_resp_t     ),
    .mst_req_t      ( mst_req_t      ),
    .mst_resp_t     ( mst_resp_t     ),
    .rule_t         ( rule_t         )
  ) i_xbar_01 (
    .clk_i,
    .rst_ni,
    .test_i                 ( test_en_i                               ),
    .slv_ports_req_i        ( xbar_slv_req_01                         ),
    .slv_ports_resp_o       ( xbar_slv_resp_01                        ),
    .mst_ports_req_o        ( xbar_mst_req_01                         ),
    .mst_ports_resp_i       ( xbar_mst_resp_01                        ),
    .addr_map_i				( addr_map_01							  ),
    .en_default_mst_port_i  ( '0                                      ),
    .default_mst_port_i     ( '0                                      )
  );
  
  for (genvar i = 1; i < Cfg.NoMstPorts; i++) begin : gen_remap_01
    axi_id_remap #(
      .AxiSlvPortIdWidth    ( AxiIdWidthMstPorts     ),
      .AxiSlvPortMaxUniqIds ( AxiSlvPortMaxUniqIds   ),
      .AxiMaxTxnsPerId      ( AxiMaxTxnsPerId        ),
      .AxiMstPortIdWidth    ( Cfg.AxiIdWidthSlvPorts ),
      .slv_req_t            ( mst_req_t              ),
      .slv_resp_t           ( mst_resp_t             ),
      .mst_req_t            ( slv_req_t              ),
      .mst_resp_t           ( slv_resp_t             )
    ) i_axi_id_remap_01 (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( xbar_mst_req_01[i]   ),
      .slv_resp_o ( xbar_mst_resp_01[i]  ),
      .mst_req_o  ( xp_mst_req_01[i]     ),
      .mst_resp_i ( xp_mst_resp_01[i]    )
    );
  end
  
  
/////////////////////////////////////////////
//xp(1,0)

axi_xbar #(
    .Cfg            ( Cfg            ),
    .ATOPs          ( ATOPs          ),
    .Connectivity   ( Connectivity   ),
    .slv_aw_chan_t  ( slv_aw_chan_t  ),
    .mst_aw_chan_t  ( mst_aw_chan_t  ),
    .w_chan_t       ( w_chan_t       ),
    .slv_b_chan_t   ( slv_b_chan_t   ),
    .mst_b_chan_t   ( mst_b_chan_t   ),
    .slv_ar_chan_t  ( slv_ar_chan_t  ),
    .mst_ar_chan_t  ( mst_ar_chan_t  ),
    .slv_r_chan_t   ( slv_r_chan_t   ),
    .mst_r_chan_t   ( mst_r_chan_t   ),
    .slv_req_t      ( slv_req_t      ),
    .slv_resp_t     ( slv_resp_t     ),
    .mst_req_t      ( mst_req_t      ),
    .mst_resp_t     ( mst_resp_t     ),
    .rule_t         ( rule_t         )
  ) i_xbar_10 (
    .clk_i,
    .rst_ni,
    .test_i                 ( test_en_i                               ),
    .slv_ports_req_i        ( xbar_slv_req_10                         ),
    .slv_ports_resp_o       ( xbar_slv_resp_10                        ),
    .mst_ports_req_o        ( xbar_mst_req_10                         ),
    .mst_ports_resp_i       ( xbar_mst_resp_10                        ),
    .addr_map_i				( addr_map_00							  ),
    .en_default_mst_port_i  ( '0                                      ),
    .default_mst_port_i     ( '0                                      )
  );
  
  for (genvar i = 1; i < Cfg.NoMstPorts; i++) begin : gen_remap_10
    axi_id_remap #(
      .AxiSlvPortIdWidth    ( AxiIdWidthMstPorts     ),
      .AxiSlvPortMaxUniqIds ( AxiSlvPortMaxUniqIds   ),
      .AxiMaxTxnsPerId      ( AxiMaxTxnsPerId        ),
      .AxiMstPortIdWidth    ( Cfg.AxiIdWidthSlvPorts ),
      .slv_req_t            ( mst_req_t              ),
      .slv_resp_t           ( mst_resp_t             ),
      .mst_req_t            ( slv_req_t              ),
      .mst_resp_t           ( slv_resp_t             )
    ) i_axi_id_remap_10 (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( xbar_mst_req_10[i]   ),
      .slv_resp_o ( xbar_mst_resp_10[i]  ),
      .mst_req_o  ( xp_mst_req_10[i]     ),
      .mst_resp_i ( xp_mst_resp_10[i]    )
    );
  end
  
  
/////////////////////////////////////////////
//xp(1,1)

axi_xbar #(
    .Cfg            ( Cfg            ),
    .ATOPs          ( ATOPs          ),
    .Connectivity   ( Connectivity   ),
    .slv_aw_chan_t  ( slv_aw_chan_t  ),
    .mst_aw_chan_t  ( mst_aw_chan_t  ),
    .w_chan_t       ( w_chan_t       ),
    .slv_b_chan_t   ( slv_b_chan_t   ),
    .mst_b_chan_t   ( mst_b_chan_t   ),
    .slv_ar_chan_t  ( slv_ar_chan_t  ),
    .mst_ar_chan_t  ( mst_ar_chan_t  ),
    .slv_r_chan_t   ( slv_r_chan_t   ),
    .mst_r_chan_t   ( mst_r_chan_t   ),
    .slv_req_t      ( slv_req_t      ),
    .slv_resp_t     ( slv_resp_t     ),
    .mst_req_t      ( mst_req_t      ),
    .mst_resp_t     ( mst_resp_t     ),
    .rule_t         ( rule_t         )
  ) i_xbar_11 (
    .clk_i,
    .rst_ni,
    .test_i                 ( test_en_i                               ),
    .slv_ports_req_i        ( xbar_slv_req_11                         ),
    .slv_ports_resp_o       ( xbar_slv_resp_11                        ),
    .mst_ports_req_o        ( xbar_mst_req_11                         ),
    .mst_ports_resp_i       ( xbar_mst_resp_11                        ),
    .addr_map_i				( addr_map_11							  ),
    .en_default_mst_port_i  ( '0                                      ),
    .default_mst_port_i     ( '0                                      )
  );
  
  for (genvar i = 1; i < Cfg.NoMstPorts; i++) begin : gen_remap_11
    axi_id_remap #(
      .AxiSlvPortIdWidth    ( AxiIdWidthMstPorts     ),
      .AxiSlvPortMaxUniqIds ( AxiSlvPortMaxUniqIds   ),
      .AxiMaxTxnsPerId      ( AxiMaxTxnsPerId        ),
      .AxiMstPortIdWidth    ( Cfg.AxiIdWidthSlvPorts ),
      .slv_req_t            ( mst_req_t              ),
      .slv_resp_t           ( mst_resp_t             ),
      .mst_req_t            ( slv_req_t              ),
      .mst_resp_t           ( slv_resp_t             )
    ) i_axi_id_remap_11 (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( xbar_mst_req_11[i]   ),
      .slv_resp_o ( xbar_mst_resp_11[i]  ),
      .mst_req_o  ( xp_mst_req_11[i]     ),
      .mst_resp_i ( xp_mst_resp_11[i]    )
    );
  end
  
endmodule
  
`include "axi/assign.svh"
`include "axi/typedef.svh"
  
module axi_mesh_intf
import cf_math_pkg::idx_width;
#(
  parameter int unsigned AXI_USER_WIDTH =  0,
  parameter axi_pkg::xbar_cfg_t Cfg     = '0,
  parameter bit ATOPS                   = 1'b1,
  parameter bit [Cfg.NoSlvPorts-1:0][Cfg.NoMstPorts-1:0] CONNECTIVITY = '1,
  parameter type rule_t                 = axi_pkg::xbar_rule_64_t
`ifdef VCS
  , localparam int unsigned MstPortsIdxWidth =
        (Cfg.NoMstPorts == 32'd1) ? 32'd1 : unsigned'($clog2(Cfg.NoMstPorts))
`endif
) (
  input  logic                                                      clk_i,
  input  logic                                                      rst_ni,
  input  logic                                                      test_i,
  AXI_BUS.Slave                                                     slv_ports [3:0],
  AXI_BUS.Master                                                    mst_ports [3:0],
  input  rule_t [Cfg.NoAddrRules-1:0]                               addr_map_i,
  input  logic  [Cfg.NoSlvPorts-1:0]                                en_default_mst_port_i,
`ifdef VCS
  input  logic  [Cfg.NoSlvPorts-1:0][MstPortsIdxWidth-1:0]          default_mst_port_i
`else
  input  logic  [Cfg.NoSlvPorts-1:0][idx_width(Cfg.NoMstPorts)-1:0] default_mst_port_i
`endif
);

  localparam int unsigned AxiIdWidthMstPorts = Cfg.AxiIdWidthSlvPorts + $clog2(Cfg.NoSlvPorts);

  typedef logic [AxiIdWidthMstPorts     -1:0] id_mst_t;
  typedef logic [Cfg.AxiIdWidthSlvPorts -1:0] id_slv_t;
  typedef logic [Cfg.AxiAddrWidth       -1:0] addr_t;
  typedef logic [Cfg.AxiDataWidth       -1:0] data_t;
  typedef logic [Cfg.AxiDataWidth/8     -1:0] strb_t;
  typedef logic [AXI_USER_WIDTH         -1:0] user_t;

  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, id_mst_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, id_slv_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, addr_t, id_mst_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, addr_t, id_slv_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, data_t, id_mst_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, data_t, id_slv_t, user_t)
  `AXI_TYPEDEF_REQ_T(mst_req_t, mst_aw_chan_t, w_chan_t, mst_ar_chan_t)
  `AXI_TYPEDEF_REQ_T(slv_req_t, slv_aw_chan_t, w_chan_t, slv_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(mst_resp_t, mst_b_chan_t, mst_r_chan_t)
  `AXI_TYPEDEF_RESP_T(slv_resp_t, slv_b_chan_t, slv_r_chan_t)
  
  localparam int unsigned NoTiles = 32'd4;

  mst_req_t   [NoTiles-1:0]  mst_reqs;
  mst_resp_t  [NoTiles-1:0]  mst_resps;
  slv_req_t   [NoTiles-1:0]  slv_reqs;
  slv_resp_t  [NoTiles-1:0]  slv_resps;

  for (genvar i = 0; i < NoTiles; i++) begin : gen_assign_mst
    `AXI_ASSIGN_FROM_REQ(mst_ports[i], mst_reqs[i])
    `AXI_ASSIGN_TO_RESP(mst_resps[i], mst_ports[i])
  end

  for (genvar i = 0; i < NoTiles; i++) begin : gen_assign_slv
    `AXI_ASSIGN_TO_REQ(slv_reqs[i], slv_ports[i])
    `AXI_ASSIGN_FROM_RESP(slv_ports[i], slv_resps[i])
  end

  axi_mesh #(
    .Cfg  (Cfg),
    .ATOPs                   ( ATOPS         ),
    .Connectivity            ( CONNECTIVITY  ),
	.AxiSlvPortMaxUniqIds    ( 16            ),
	.AxiMaxTxnsPerId         ( 128           ),
	.NoTiles                 ( NoTiles       ),
    .slv_aw_chan_t           ( slv_aw_chan_t ),
    .mst_aw_chan_t           ( mst_aw_chan_t ),
    .w_chan_t                ( w_chan_t      ),
    .slv_b_chan_t            ( slv_b_chan_t  ),
    .mst_b_chan_t            ( mst_b_chan_t  ),
    .slv_ar_chan_t           ( slv_ar_chan_t ),
    .mst_ar_chan_t           ( mst_ar_chan_t ),
    .slv_r_chan_t            ( slv_r_chan_t  ),
    .mst_r_chan_t            ( mst_r_chan_t  ),
    .slv_req_t               ( slv_req_t     ),
    .slv_resp_t              ( slv_resp_t    ),
    .mst_req_t               ( mst_req_t     ),
    .mst_resp_t              ( mst_resp_t    ),
    .rule_t                  ( rule_t        )
  ) i_mesh (
    .clk_i,
    .rst_ni,
    .test_i,
    .slv_ports_req_i  (slv_reqs ),
    .slv_ports_resp_o (slv_resps),
    .mst_ports_req_o  (mst_reqs ),
    .mst_ports_resp_i (mst_resps),
    .addr_map_i('0),
    .en_default_mst_port_i,
    .default_mst_port_i
  );

endmodule
  