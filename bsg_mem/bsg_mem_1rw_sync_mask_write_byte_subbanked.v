/*
 *  bsg_mem_1rw_sync_mask_write_byte_subbanked.v
 *
 *  This module has the same interface/functionality as
    bsg_mem_1rw_sync_mask_write_byte.
 *
 *  - width_p : width of the total memory
 *  - els_p   : depth of the total memory
 *
 *  - num_subbank_p : Number of banks for the memory's width. width_p has
 *                    to be a multiple of this number.
 *
 */

`include "bsg_defines.v"

module bsg_mem_1rw_sync_mask_write_byte_subbanked
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter latch_last_read_p = 0
    , parameter num_subbank_p = 4

      // Don't support depth subbanks due to conflicts
    , localparam subbank_width_lp = width_p/num_subbank_p
    , localparam mask_width_lp = subbank_width_lp >>3
    , localparam els_lp = `BSG_SAFE_CLOG2(els_p)
  )
  (   input clk_i
  	, input reset_i
   	, input [num_subbank_p-1:0] v_i
  	, input w_i
  	, input [num_subbank_p-1:0][mask_width_lp-1:0] w_mask_i
  	, input [num_subbank_p-1:0][subbank_width_lp-1:0] data_i
  	, input [els_lp-1:0] addr_i
  	, output logic [num_subbank_p-1:0][subbank_width_lp-1:0] data_o
  );

    logic [num_subbank_p-1:0][subbank_width_lp-1:0] data_lo;
    logic [num_subbank_p-1:0][mask_width_lp-1:0] w_mask_lo;

    for (genvar i = 0; i < num_subbank_p; i++) begin
      for (genvar j = 0; j < mask_width_lp; j++) 
        assign w_mask_lo[i][j] = w_mask_i[i][j] & v_i[i];
    end // for (genvar i = 0; i < num_subbank_p; i++)

    bsg_mem_1rw_sync_mask_write_byte #(
      .data_width_p(width_p)
      ,.els_p(els_p)
      ,.latch_last_read_p(0)
    ) 
    bank 
    ( .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(|v_i)
      ,.w_i(|w_i)
      ,.addr_i(addr_i)
      ,.data_i(data_i)
      ,.write_mask_i(w_mask_lo)
      ,.data_o(data_lo)
    );

    wire [num_subbank_p-1:0] read_en;

    for (genvar i = 0; i < num_subbank_p; i++) begin 
      assign read_en[i] = v_i[i] & ~w_i;

      if (latch_last_read_p) begin: llr
        logic [num_subbank_p-1:0] read_en_r; 

        bsg_dff #(
          .width_p(1)
        ) read_en_dff (
          .clk_i(clk_i)
          ,.data_i(read_en[i])
          ,.data_o(read_en_r[i])
        );
        
        bsg_dff_en_bypass #(
          .width_p(subbank_width_lp)
        ) dff_bypass (
          .clk_i(clk_i)
          ,.en_i(read_en_r[i])
          ,.data_i(data_lo[i])
          ,.data_o(data_o[i])
        );
      end // (latch_last_read_p):llr
      
      else begin: no_llr
        assign data_o = data_lo;
      end
    
    end // for (genvar i = 0; i < num_subbank_p; i++)

    always@(*) begin
      assert (`BSG_IS_POW2(width_p) && `BSG_IS_POW2(els_p));
      assert (width_p%num_subbank_p == 0);
    end

endmodule
