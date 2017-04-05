-- #################################################################################################
-- #  << NEO430 - Instruction memory ("IMEM") >>                                                   #
-- # ********************************************************************************************* #
-- #  This file includes the in-place executable image of the application. See the                 #
-- #  processor's documentary to get more information.                                             #
-- #  Note: IMEM is split up into two 8-bit memories - some EDA tools have problems to synthesize  #
-- #  an pre-initialized 16-bit memory with byte-enable signals.                                   #
-- # ********************************************************************************************* #
-- # This file is part of the NEO430 Processor project: https://github.com/stnolting/neo430        #
-- # Copyright by Stephan Nolting: stnolting@gmail.com                                             #
-- #                                                                                               #
-- # This source file may be used and distributed without restriction provided that this copyright #
-- # statement is not removed from the file and that any derivative work contains the original     #
-- # copyright notice and the associated disclaimer.                                               #
-- #                                                                                               #
-- # This source file is free software; you can redistribute it and/or modify it under the terms   #
-- # of the GNU Lesser General Public License as published by the Free Software Foundation,        #
-- # either version 3 of the License, or (at your option) any later version.                       #
-- #                                                                                               #
-- # This source is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;      #
-- # without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.     #
-- # See the GNU Lesser General Public License for more details.                                   #
-- #                                                                                               #
-- # You should have received a copy of the GNU Lesser General Public License along with this      #
-- # source; if not, download it from https://www.gnu.org/licenses/lgpl-3.0.en.html                #
-- # ********************************************************************************************* #
-- #  Stephan Nolting, Hannover, Germany                                               23.02.2017  #
-- #################################################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.neo430_package.all;
use work.neo430_application_image.all; -- this file is generated by the image generator

entity neo430_imem is
  generic (
    IMEM_SIZE   : natural := 4*1024; -- internal IMEM size in bytes
    IMEM_AS_ROM : boolean := false -- implement IMEM as read-only memory?
  );
  port (
    clk_i  : in  std_ulogic; -- global clock line
    rden_i : in  std_ulogic; -- read enable
    wren_i : in  std_ulogic_vector(01 downto 0); -- write enable
    upen_i : in  std_ulogic; -- update enable
    addr_i : in  std_ulogic_vector(15 downto 0); -- address
    data_i : in  std_ulogic_vector(15 downto 0); -- data in
    data_o : out std_ulogic_vector(15 downto 0)  -- data out
  );
end neo430_imem;

architecture neo430_imem_rtl of neo430_imem is

  -- ROM types --
  type init_file_t is array (0 to IMEM_SIZE/2-1) of std_ulogic_vector(15 downto 0);
  type imem_file8_t is array (0 to IMEM_SIZE/2-1) of std_ulogic_vector(07 downto 0);

  -- init function --
  impure function init_imem(init : application_init_image_t) return init_file_t is
    variable mem_v : init_file_t;
  begin
    for i in 0 to (IMEM_SIZE/2-1) loop
      mem_v(i) := init(i);
    end loop; -- i
    return mem_v;
  end function init_imem;

  -- split 1x16 memory into 2x8 memories --
  function split_imem(hilo: boolean; img_in: init_file_t) return imem_file8_t is
    variable mem_v : imem_file8_t;
  begin
    for i in 0 to (IMEM_SIZE/2-1) loop
      if (hilo = false) then -- low byte
        mem_v(i) := img_in(i)(07 downto 00);
      else -- high byte
        mem_v(i) := img_in(i)(15 downto 08);
      end if;
    end loop; -- i
    return mem_v;
  end function split_imem;

  -- local signals --
  signal acc_en : std_ulogic;
  signal rdata  : std_ulogic_vector(15 downto 0);
  signal rden   : std_ulogic;
  signal addr   : natural range 0 to IMEM_SIZE/2-1;

  -- ROM --
  constant imem_init_file : init_file_t := init_imem(application_init_image);

  -- internal ROM type --
  signal imem_file_l : imem_file8_t := split_imem(false, imem_init_file);
  signal imem_file_h : imem_file8_t := split_imem(true,  imem_init_file);

  --- RAM attribute to inhibit bypass-logic - Altera only! ---
  attribute ramstyle : string;
  attribute ramstyle of imem_file_l : signal is "no_rw_check";
  attribute ramstyle of imem_file_h : signal is "no_rw_check";

begin

  -- Access Control -----------------------------------------------------------
  -- -----------------------------------------------------------------------------
  acc_en <= '1' when (addr_i >= imem_base_c) and (addr_i < std_ulogic_vector(unsigned(imem_base_c) + IMEM_SIZE)) else '0';
  addr <= to_integer(unsigned(addr_i(index_size(IMEM_SIZE/2) downto 1))); -- word aligned


  -- Memory Access ------------------------------------------------------------
  -- -----------------------------------------------------------------------------
  imem_file_access: process(clk_i)
  begin
    if rising_edge(clk_i) then
      rden <= rden_i and acc_en;
      if (IMEM_AS_ROM = false) then
        if (acc_en = '1') and (wren_i(0) = '1') and (upen_i = '1') then -- write low byte
          imem_file_l(addr) <= data_i(07 downto 0);
        end if;
        if (acc_en = '1') and (wren_i(1) = '1') and (upen_i = '1') then -- write high byte
          imem_file_h(addr) <= data_i(15 downto 8);
        end if;
      end if;
      rdata <= imem_file_h(addr) & imem_file_l(addr);
    end if;
  end process imem_file_access;

  -- output gate --
  data_o <= rdata when (rden = '1') else x"0000";


end neo430_imem_rtl;
