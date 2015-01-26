LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use IEEE.std_logic_textio.all;    -- for hread(), hwrite()
use IEEE.std_logic_unsigned.all;  -- for conv_integer()
use std.textio.all; 			  -- for file operations
 
ENTITY FSM_testbench IS
END FSM_testbench;
 
ARCHITECTURE behavior OF FSM_testbench IS 

	file inputfile : text open read_mode  is "Midterm2.in";
	file outputfile : text open write_mode  is "Midterm_2.out";
 
	-- Component Declaration for the Unit Under Test (UUT)
	COMPONENT FSM_design
		PORT(Sclk : IN  std_logic;
			Dclk : IN  std_logic;
			Start : IN  std_logic;
			InReady : OUT  std_logic;
			Frame : IN  std_logic;
			InputL : IN  std_logic;
			InputR : IN std_logic; --
			Reset_n : IN  std_logic;
			OutReady : OUT std_logic;
			OutputL : out std_logic;
			OutputR : out std_logic;
			dummy : out integer;
			sleep_dummy: out integer;
			output_state : OUT  std_logic_vector(3 downto 0)
			);
	END COMPONENT;
    
	signal Sclk : std_logic := '0';
	signal Dclk : std_logic := '0';
	signal Start : std_logic := '0';
	signal Reset_n : std_logic := '1';
	signal Frame : std_logic := '1';
	signal InReady : std_logic;
	signal InputL : std_logic := '0';
	signal InputR : std_logic := '0'; --
	signal output_state : std_logic_vector(3 downto 0);
	signal OutReady : std_logic ;
	signal OutputL : std_logic;
	signal OutputR : std_logic;
	signal dummy : integer;
	signal sleep_dummy: integer := 0;
	signal count_rj : integer := 0;
	signal count_coeffs : integer := 512;
	signal bit_count : integer := 15;
	signal OutVec : std_logic_vector(39 downto 0);
	signal OutVecR : std_logic_vector(39 downto 0);
	signal Outbc : integer := 39;
	signal inputCount : integer := 0;

	-- Clock period definitions
	-- constant HALFSCLK : time := 18.6011905 ns; -- Half period of system clock at 26.880 MHZ
	constant HALFSCLK : time := ((1000 ms/26880000)/2);
	-- constant HALFDCLK : time := 651.041667 ns; -- Half period of data clock at 768 kHz
	constant HALFDCLK : time := ((1000 ms/768000)/2);
 
	BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
	uut: FSM_design PORT MAP (
		Sclk => Sclk,
		Dclk => Dclk,
		Start => Start,
		InReady => InReady,
		Frame => Frame,
		InputL => InputL,
		InputR => InputR,
		Reset_n => Reset_n,
		OutReady => OutReady,
		OutputL => OutputL,
		OutputR => OutputR,
		dummy => dummy,
		sleep_dummy => sleep_dummy,
		output_state => output_state
		);

	-- Clock process definitions
	Dclk_process : process
	begin
		Dclk <= '1';
		wait for HALFDCLK;
		Dclk <= '0';
		wait for HALFDCLK;
	end process;

	Sclk_process :process
	begin
		Sclk <= '0';
		wait for HALFSCLK;
		Sclk <= '1';
		wait for HALFSCLK;
	end process;
	
	trigger_process: process
	begin
		Start <= '1';
		wait for HALFSCLK*2;
		Start <= '0';
		wait for HALFSCLK*2;
		wait;
	end process;
		
	reset_process: process
	begin
		wait until (inputCount = 4201 and bit_count = 13);
		Reset_n <= '0';
		wait for HALFDCLK * 4;
		Reset_n <= '1';
		wait until (inputCount = 6001 and bit_count = 10);
		Reset_n <= '0';
		wait for HALFDCLK * 4;
		Reset_n <= '1';
		wait;
	end process;
	
	-- Stimulus process
	stim_proc: process
	variable temp : std_logic_vector(15 downto 0);
	variable tempR : std_logic_vector(15 downto 0);
	variable outline : line;
	variable inline: line;
	begin
		----------- READ RJ VALUES -----------
		while (InReady /= '1') loop
			wait for HALFDCLK*2;
		end loop;
		Frame <= '0';
		wait for HALFDCLK;
		while (count_rj < 16) loop
			readline(inputfile,outline);
			if outline(1) = '/' then
				next;              
			end if;
			Frame <= '0';
			hread(outline,temp);
			hread(outline,tempR); -- newly added		
			while (bit_count >= 0) loop
				InputL <= temp(bit_count);
				InputR <= tempR(bit_count);
				bit_count <= bit_count - 1;
				if(bit_count = 0) then
					exit;
				else
					wait for HALFDCLK;
					Frame <= '1';
					wait for HALFDCLK;
				end if;
			end loop;
			count_rj <= count_rj+1;
			bit_count <= 15;
			wait for HALFDCLK;
			if(count_rj < 16) then
				Frame <= '0';
			end if;
			wait for HALFDCLK;
		end loop;
		count_rj <= 0;
		----------- READ COEFFICIENTS -----------
		wait for HALFDCLK; -- wait for positive edge
		while (InReady /= '1') loop
			wait for HALFDCLK*2;
		end loop;
		Frame <= '0';
		wait for HALFDCLK;
		while (count_rj < count_coeffs) loop
			readline(inputfile,outline);
			if outline(1) = '/' then
				next;             
			end if;
			Frame <= '0';
			hread(outline,temp);
			hread(outline,tempR); -- newly added
			while (bit_count >= 0) loop
				InputL <= temp(bit_count);
				InputR <= tempR(bit_count);
				bit_count <= bit_count - 1;
				if(bit_count = 0) then
					exit;
				else
					wait for HALFDCLK;
					Frame <= '1';
					wait for HALFDCLK;
				end if;
			end loop;
			count_rj <= count_rj+1;
			bit_count <= 15;
			wait for HALFDCLK;
			if(count_rj < count_coeffs) then
				Frame <= '0';
			end if;
			wait for HALFDCLK;
		end loop;
		count_rj <= 0;
		----------- READ INPUTS -----------
		wait for HALFDCLK;
		while (InReady /= '1') loop
			wait for HALFDCLK*2;
		end loop;
		Frame <= '0';
		wait for HALFDCLK;
		while not endfile(inputfile) loop
			readline(inputfile,outline);
			if outline(1) = '/' then
				next;              
			end if;
			inputCount <= inputCount + 1;
			Frame <= '0';
			hread(outline,temp);
			hread(outline,tempR);		
			while (bit_count >= 0) loop
				InputL <= temp(bit_count);	
				InputR <= tempR(bit_count);
				bit_count <= bit_count - 1;
				if(bit_count = 0) then
					exit;
				else
					wait for HALFDCLK;
					Frame <= '1';
					wait for HALFDCLK;
				end if;
				if(Reset_n = '0') then
					exit;
				end if;
			end loop;
			count_rj <= count_rj+1;
			bit_count <= 15;
			while(Reset_n = '0') loop
				wait for HALFDCLK*2;
			end loop;
			wait for HALFDCLK;
			frame <= '0';
			wait for HALFDCLK;
		end loop;
		frame <= '1';
		wait;
	end process;

	Output_process :process (Sclk)
	variable out_line : line;
	begin
		if (falling_edge(Sclk)) then
			if(OutReady = '0') then
				OutVec(Outbc) <= OutputL;
				OutVecR(Outbc) <= OutputR;
				Outbc <= Outbc - 1;
			end if;
			if(outbc < 0) then
				write(out_line, "   ");
				hwrite(out_line, OutVec);
				write(out_line, "      ");
				hwrite(out_line, OutVecR);
				writeline(outputfile, out_line);
				outbc <= 39;
			end if;
			if(Reset_n = '0') then
				Outbc <= 39;
				OutVec <= X"0000000000";
				OutVecR <= X"0000000000";
			end if;
		end if;
	end process;

END;
