library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_signed.all;
use ieee.numeric_std.all;

entity FSM_design is
    Port (Sclk : in  STD_LOGIC;
		  Dclk : in  STD_LOGIC;
		  Start : in STD_LOGIC;
		  InReady : out STD_LOGIC := '0';
		  Frame : in STD_LOGIC;
		  InputL : in STD_LOGIC;
		  InputR : in STD_LOGIC;
		  Reset_n : in STD_LOGIC;
		  output_state : out  STD_LOGIC_VECTOR (3 DOWNTO 0);
		  OutputL : out STD_LOGIC;
		  OutputR : out STD_LOGIC;
		  dummy : out integer := 0;
		  sleep_dummy: out integer := 0;
		  OutReady : out STD_LOGIC := '1'
		  );
end FSM_design;

architecture Behavioral of FSM_design is

	type STATE_TYPE is (S0,S1,S2,S3,S4,S5,S6,S7,S8);
	signal state, current_state, next_state: STATE_TYPE;
	signal count: INTEGER := 0;
	type arraytype_Rj is array (0 to 15) of std_logic_vector (15 DOWNTO 0);
	type arraytype_Coeff is array (0 to 511) of std_logic_vector (15 DOWNTO 0); 	   -- Hard coded array size to coefficient count
	type arraytype_InputL_data is array (0 to 255) of std_logic_vector (39 DOWNTO 0);  -- Hard coded array size to input count
	type arraytype_Uj is array (0 to 15) of std_logic_vector (39 DOWNTO 0);
	signal Rj : arraytype_Rj; 														   -- Array to store Rj_Left
	signal RjR : arraytype_Rj; 														   -- Array to store Rj_Right
	signal Coeff : arraytype_Coeff;													   -- Array to store filter coefficients_left
	signal CoeffR : arraytype_Coeff;												   -- Array to store filter coefficients_Right
	signal InputL_data : arraytype_InputL_data :=  (others=> (others=>'0'));		   -- Array to store inputs_Left
	signal InputR_data : arraytype_InputL_data :=  (others=> (others=>'0'));		   -- Array to store inputs_Right
	signal Uj : arraytype_Uj :=  (others=> (others=>'0'));				               -- Array to store Uj
	signal UjR : arraytype_Uj :=  (others=> (others=>'0'));				               -- Array to store Uj_Right
	signal i : integer := 0; 														   -- Index used to receive Rj bits
	signal j : integer := 0; 														   -- Index used to receive filter coefficient bits
	signal k : integer := 0;														   -- Index used to receive input bits
	signal arrived : integer := 0;													   -- Flag indicating arrival of 16 input bits
	signal rj_complete : integer := 0;												   -- Flag indicating Rj receive completion
	signal coeff_complete : integer := 0;											   -- Flag indicating coefficients receive completion 
	signal sleep_detect : integer := 0;												   -- Flag indicating arrival of continuous zero inputs
	signal awake_flag : integer := 0;												   -- Flag indicating awake from sleep mode
	signal bi : integer := 15; 														   -- Bit index signal for inputs
	signal output_bi : integer := 39;
	signal ii : integer := 0; 														
	signal jj : integer := 0; 														
	signal kk : integer := 0;														
	-- Signals for output computation
	signal m : integer := 0;
	signal p : integer := 0;
	signal q : integer := 0;
	signal mR : integer := 0;
	signal pR : integer := 0;
	signal qR : integer := 0;
	signal shift_flag : integer := 0;
	signal shift_flagR : integer := 0;
	signal Output_Final : std_logic_vector (39 DOWNTO 0) := X"0000000000";
	signal Output_FinalR : std_logic_vector (39 DOWNTO 0) := X"0000000000";
	signal OutputTemp : std_logic_vector (39 DOWNTO 0) := X"0000000000";
	signal OutputTempR : std_logic_vector (39 DOWNTO 0) := X"0000000000";
	signal Outfinish1 : std_logic := '0';
	signal Outfinish2 : std_logic := '0';
	signal Outfinish1R : std_logic := '0';
	signal Outfinish2R : std_logic := '0';
	signal out_calc : std_logic := '0';
	signal out_calcR : std_logic := '0';
	signal sum_flag : integer := 0;
	signal sum_flagR : integer := 0;

begin

	state_process : process (Sclk, Reset_n, Start, next_state)
	begin
		if(Start = '1') then
			current_state <= S0;
		elsif(Reset_n = '0') then
			current_state <= S7;
		else
			current_state <= next_state;
		end if;
	end process;

	Sclk_process : process (Sclk)
	begin
		if (falling_edge(Sclk)) then
			------------- S0 -------------
			if (current_state = S0) then 
				next_state <= S1;
				output_state <= "0000";
			------------- S1 -------------
			elsif (current_state = S1) then 
				-- Waiting to receive Rj
				InReady <= '1';
				if (Frame = '0') then
					next_state <= S2;
					InReady <= '1'; -- Change and Check
				end if;
				output_state <= "0001";
			------------- S2 -------------
			elsif (current_state = S2) then 
				if (rj_complete = 1) then
					next_state <= S3;
				end if;
				output_state <= "0010";
			------------- S3 -------------
			elsif (current_state = S3) then 
				-- Waiting to receive coefficients
				InReady <= '1';
				if (Frame = '0') then
					next_state <= S4;
					InReady <= '1'; -- Change and Check
				end if;
				output_state <= "0011";
			------------- S4 -------------
			elsif (current_state = S4) then 
				if (coeff_complete = 1) then
					next_state <= S5;
				end if;
				output_state <= "0100";
			------------- S5 -------------
			elsif (current_state = S5) then 
				-- Waiting to receive inputs
				InReady <= '1';
				if (Frame = '0') then
					next_state <= S6;
					InReady <= '1'; -- Change and Check
				end if;
				output_state <= "0101";
			------------- S6 -------------
			elsif (current_state = S6) then 
				-- Output computation -- Begin --
				-- Left Channel --
				if (arrived = 1 and out_calc = '0') then
					if ((k-1-conv_integer(Coeff(m) and X"00FF")) >= 0) then 	
						if ((Coeff(m) and X"0100") = X"0100") then
							Uj(0) <= Uj(0) - InputL_data(k-1-conv_integer(Coeff(m) and X"00FF"));
						else
							Uj(0) <= Uj(0) + InputL_data(k-1-conv_integer(Coeff(m) and X"00FF"));
						end if;
					end if;
					m <= m + 1;
					q <= 1;
					out_calc <= '1';
					dummy <= m;
				end if;
				-- Right Channel --
				if (arrived = 1 and out_calcR = '0') then
					if ((k-1-conv_integer(CoeffR(mR) and X"00FF")) >= 0) then 	
						if ((CoeffR(mR) and X"0100") = X"0100") then
							UjR(0) <= UjR(0) - InputR_data(k-1-conv_integer(CoeffR(mR) and X"00FF"));
						else
							UjR(0) <= UjR(0) + InputR_data(k-1-conv_integer(CoeffR(mR) and X"00FF"));
						end if;
					end if;
					mR <= mR + 1;
					qR <= 1;
					out_calcR <= '1';
					dummy <= mR;
				end if;
				-- Left Channel --
				if(out_calc = '1') then
					if (p < 16) then
						if (q < conv_integer(Rj(p))) then
							if ((k-1-conv_integer(Coeff(m) and X"00FF")) >= 0) then 	
								if ((Coeff(m) and X"0100") = X"0100") then
									Uj(p) <= Uj(p) - InputL_data(k-1-conv_integer(Coeff(m) and X"00FF"));
								else
									Uj(p) <= Uj(p) + InputL_data(k-1-conv_integer(Coeff(m) and X"00FF"));
								end if;
							end if;
							m <= m+1;
							q <= q+1;
							dummy <= m;
						end if;
					end if;

					if (p < 16) then
						if (q = conv_integer(Rj(p)) - 1) then
							q <= 0;				
							p <= p+1;
							dummy <= 15;
						end if;
					end if;

					if(p > sum_flag and shift_flag = 0) then
						Output_Final <= Output_Final + Uj(sum_flag);
						shift_flag <= 1;
						dummy <= 255;
					end if;

					if (shift_flag = 1) then
						Output_Final <= std_logic_vector(shift_right(signed(Output_Final), 1));
						shift_flag <= 0;
						sum_flag <= sum_flag + 1;
						dummy <= 4095;
						if(sum_flag = 15) then
							dummy <= 65535;
							Outfinish1 <= '1';
							Outfinish2 <= '1';
							p <= 0;
							q <= 0;
							m <= 0;
							out_calc <= '0';
							sum_flag <= 0;
							Uj(0) <= X"0000000000";
							Uj(1) <= X"0000000000";
							Uj(2) <= X"0000000000";
							Uj(3) <= X"0000000000";
							Uj(4) <= X"0000000000";
							Uj(5) <= X"0000000000";
							Uj(6) <= X"0000000000";
							Uj(7) <= X"0000000000";
							Uj(8) <= X"0000000000";
							Uj(9) <= X"0000000000";
							Uj(10) <= X"0000000000";
							Uj(11) <= X"0000000000";
							Uj(12) <= X"0000000000";
							Uj(13) <= X"0000000000";
							Uj(14) <= X"0000000000";
							Uj(15) <= X"0000000000";
						end if;
					end if;
				end if;
				-- Right Channel --
				if(out_calcR = '1') then
					if (pR < 16) then
						if (qR < conv_integer(RjR(pR))) then
							if ((k-1-conv_integer(CoeffR(mR) and X"00FF")) >= 0) then 	
								if ((CoeffR(mR) and X"0100") = X"0100") then
									UjR(pR) <= UjR(pR) - InputR_data(k-1-conv_integer(CoeffR(mR) and X"00FF"));
								else
									UjR(pR) <= UjR(pR) + InputR_data(k-1-conv_integer(CoeffR(mR) and X"00FF"));
								end if;
							end if;
							mR <= mR+1;
							qR <= qR+1;
							dummy <= mR;
						end if;
					end if;

					if (pR < 16) then
						if (qR = conv_integer(RjR(pR)) - 1) then
							qR <= 0;				
							pR <= pR+1;
							dummy <= 15;
						end if;
					end if;

					if(pR > sum_flagR and shift_flagR = 0) then
						Output_FinalR <= Output_FinalR + UjR(sum_flagR);
						shift_flagR <= 1;
						dummy <= 255;
					end if;

					if (shift_flagR = 1) then
						Output_FinalR <= std_logic_vector(shift_right(signed(Output_FinalR), 1));
						shift_flagR <= 0;
						sum_flagR <= sum_flagR + 1;
						dummy <= 4095;
						if(sum_flagR = 15) then
							dummy <= 65535;
							Outfinish1R <= '1';
							Outfinish2R <= '1';
							pR <= 0;
							qR <= 0;
							mR <= 0;
							out_calcR <= '0';
							sum_flagR <= 0;
							UjR(0) <= X"0000000000";
							UjR(1) <= X"0000000000";
							UjR(2) <= X"0000000000";
							UjR(3) <= X"0000000000";
							UjR(4) <= X"0000000000";
							UjR(5) <= X"0000000000";
							UjR(6) <= X"0000000000";
							UjR(7) <= X"0000000000";
							UjR(8) <= X"0000000000";
							UjR(9) <= X"0000000000";
							UjR(10) <= X"0000000000";
							UjR(11) <= X"0000000000";
							UjR(12) <= X"0000000000";
							UjR(13) <= X"0000000000";
							UjR(14) <= X"0000000000";
							UjR(15) <= X"0000000000";
						end if;
					end if;
				end if;
				-- Output computation -- End
			
				-- Store output
				-- Left Channel
				if(Outfinish1 = '1') then
					OutputTemp <= Output_Final;
					Output_Final <= X"0000000000";
					Outfinish1 <= '0';
				end if;
				-- Right Channel
				if(Outfinish1R = '1') then
					OutputTempR <= Output_FinalR;
					Output_FinalR <= X"0000000000";
					Outfinish1R <= '0';
				end if;
			
				-- Send output -- Begin
				if(Frame = '0' and Outfinish2 = '1' and Outfinish2R = '1') then -- Send first bit
					sleep_dummy <= k;
					OutputL <= OutputTemp(output_bi);
					OutputR <= OutputTempR(output_bi);
					output_bi <= output_bi - 1;
					Outfinish2 <= '0';
					Outfinish2R <= '0';
					OutReady <= '0';
				end if;
						
				if(output_bi < 39 and output_bi >= 0) then -- Send remaining bits
					OutputL <= OutputTemp(output_bi);
					OutputR <= OutputTempR(output_bi);
					output_bi <= output_bi - 1;
				end if;

				if(output_bi < 0) then -- Make output 0
					OutputL <= '0';
					OutputR <= '0';
					output_bi <= 39;
					OutReady <= '1';
					OutputTemp <= X"0000000000";
					OutputTempR <= X"0000000000";
				end if;			
				-- Send output -- End

				if (Reset_n = '0') then
					next_state <= S7;
				end if;
			
				if(sleep_detect = 1) then
					next_state <= S8;
				end if;
				output_state <= "0110";
			------------- S7 -------------
			elsif (current_state = S7) then   
				-- Clearing all input samples in memories to 0
				InReady <= '0'; -- Change and Check
				OutReady <= '1';
				p <= 0; 					pR <= 0;
				q <= 0; 					qR <= 0;
				m <= 0; 					mR <= 0;
				out_calc <= '0'; 			out_calcR <= '0';
				sum_flag <= 0;				sum_flagR <= 0;
				shift_flag <= 0;			shift_flagR <= 0;
				Outfinish1 <= '0';			Outfinish1R <= '0';
				Outfinish2 <= '0';			Outfinish2R <= '0';
				Uj(0) <= X"0000000000";
				Uj(1) <= X"0000000000";
				Uj(2) <= X"0000000000";
				Uj(3) <= X"0000000000";
				Uj(4) <= X"0000000000";
				Uj(5) <= X"0000000000";
				Uj(6) <= X"0000000000";
				Uj(7) <= X"0000000000";
				Uj(8) <= X"0000000000";
				Uj(9) <= X"0000000000";
				Uj(10) <= X"0000000000";
				Uj(11) <= X"0000000000";
				Uj(12) <= X"0000000000";
				Uj(13) <= X"0000000000";
				Uj(14) <= X"0000000000";
				Uj(15) <= X"0000000000";
				UjR(0) <= X"0000000000";
				UjR(1) <= X"0000000000";
				UjR(2) <= X"0000000000";
				UjR(3) <= X"0000000000";
				UjR(4) <= X"0000000000";
				UjR(5) <= X"0000000000";
				UjR(6) <= X"0000000000";
				UjR(7) <= X"0000000000";
				UjR(8) <= X"0000000000";
				UjR(9) <= X"0000000000";
				UjR(10) <= X"0000000000";
				UjR(11) <= X"0000000000";
				UjR(12) <= X"0000000000";
				UjR(13) <= X"0000000000";
				UjR(14) <= X"0000000000";
				UjR(15) <= X"0000000000";
				Output_final <= X"0000000000";
				Output_finalR <= X"0000000000";
				next_state <= S5;
				output_state <= "0111";
			------------- S8 -------------
			elsif (current_state = S8) then 
				if(Frame = '0' and Outfinish2 = '1' and Outfinish2R = '1') then -- Send first bit
					OutputL <= OutputTemp(output_bi);
					OutputR <= OutputTempR(output_bi);
					output_bi <= output_bi - 1;
					OutReady <= '0';
				end if;
				if(output_bi < 39 and output_bi >= 0) then -- Send remaining bits
					OutputL <= OutputTemp(output_bi);
					OutputR <= OutputTempR(output_bi);
					output_bi <= output_bi - 1;
				end if;
			
				if(output_bi < 0) then -- Make output 0
					output_bi <= 39;
					OutputL <= '0';
					OutputR <= '0';
					OutReady <= '1';
					OutputTemp <= X"0000000000";
					OutputTempR <= X"0000000000";
					Outfinish2 <= '0';
					Outfinish2R <= '0';
				end if;
				if (awake_flag = 1) then
					next_state <= S6;
				end if;
				output_state <= "1000";
			end if;
		end if;
	end process;

	Dclk_process : process (Dclk)
	begin
		if (falling_edge(Dclk)) then
		------------- S0 -------------
			if (current_state = S0) then
				for ii in 0 to 15 loop
					Rj(ii) <= X"0000";
					RjR(ii) <= X"0000";
				end loop;
				for jj in 0 to 511 loop
					Coeff(jj) <= X"0000";
					CoeffR(jj) <= X"0000";
				end loop;
				for kk in 0 to 256 - 1 loop
					InputL_data(kk) <= X"0000000000";
					InputR_data(kk) <= X"0000000000";
			end loop;
			------------- S2 -------------
			elsif (current_state = S2) then
				if(bi >= 0) then
					Rj(i)(bi) <= InputL;
					RjR(i)(bi) <= InputR;
					bi <= bi - 1;
				end if;
				if(bi = 0) then
					i <= i+1;
					bi <= 15;
				if(i = 15) then
					rj_complete <= 1;
				end if;
			end if;
			------------- S4 -------------
			elsif (current_state = S4) then
				if(bi >= 0) then
					Coeff(j)(bi) <= InputL;
					CoeffR(j)(bi) <= InputR;				
					bi <= bi - 1;
				end if;
				if(bi = 0) then
					j <= j+1;
					bi <= 15;
				if(j = 511) then
					coeff_complete <= 1;
				end if;
			end if;
			------------- S6 -------------
			elsif (current_state = S6) then
				if (bi >= 0) then
					if (bi = 15 and InputL = '1') then
						InputL_data(k)(39 DOWNTO 32) <= X"FF";
					end if;
					if (bi = 15 and InputR = '1') then
						InputR_data(k)(39 DOWNTO 32) <= X"FF";
					end if;
					InputL_data(k)(bi+16) <= InputL;
					InputR_data(k)(bi+16) <= InputR;
					bi <= bi -1 ;
				end if;

				if (bi = 0) then
					k <= k + 1;
					bi <= 15;
					if(InputL_data(k) = X"0000000000" and InputL ='0' and InputR_data(k) = X"0000000000" and InputR = '0') then
						count <= count + 1;
						if (count = 800 - 1) then
							count <= 0;
							sleep_detect <= 1;
						end if;
					else
						count <= 0;
					end if;
					arrived <= 1;
				end if;

				if (arrived = 1) then -- Right Channel to be added
					arrived <= 0;
				end if;
			
				if (awake_flag = 1) then
					awake_flag <= 0;
				end if;
			------------- S7 -------------
			elsif (current_state <= S7) then
				for i in 0 to 255 loop
					InputL_data(i) <= X"0000000000";
					InputR_data(i) <= X"0000000000";
				end loop;
				arrived <= 0;
				k <= 0;
				bi <= 15;
			------------- S8 -------------
			elsif (current_state = S8) then
				if (bi >= 0) then
					if (bi = 15 and InputL = '1') then
						InputL_data(k)(39 DOWNTO 32) <= X"FF";
						InputR_data(k)(39 DOWNTO 32) <= X"FF";
					end if;
					InputL_data(k)(bi+16) <= InputL;
					InputR_data(k)(bi+16) <= InputR;
					bi <= bi -1 ;
					end if;
			
				if (bi = 0) then
					k <= k + 1;
					bi <= 15;
					if (InputL_data(k) /= X"0000000000" or InputL = '1' or InputR_data(k) /= X"0000000000" or InputR = '1' ) then
						arrived <= 1;
						awake_flag <= 1;
					end if;
				end if;
				sleep_detect <= 0;
			end if;
		end if;
	end process;

end Behavioral;