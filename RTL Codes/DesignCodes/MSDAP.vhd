library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_signed.all;
use ieee.numeric_std.all;

entity Controller is
    Port (Sclk : in  STD_LOGIC;
		  Dclk : in  STD_LOGIC;
		  Start : in STD_LOGIC;
		  InReady : out STD_LOGIC;
		  Frame : in STD_LOGIC;
		  InputL : in STD_LOGIC;
		  InputR : in STD_LOGIC;
		  Reset_n : in STD_LOGIC;
		  OutputL : out STD_LOGIC;
		  OutputR : out STD_LOGIC;
		  OutReady : out STD_LOGIC
		  );
end Controller;

architecture Behavioral of Controller is

component Adder is
Port (IN1 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		IN2 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
		OUTADD : out STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
		end component;
		
component Shifter is
Port (INPUT : in  STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
      OUTPUT : out  STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
		end component;
		
component AdderRight is
Port (IN1 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		IN2 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
		OUTADD : out STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
		end component;
		
component ShifterRight is
Port (INPUT : in  STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
      OUTPUT : out  STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
		end component;
		


type STATE_TYPE is (S0,S1,S2,S3,S4,S5,S6,S7,S8);
signal state, current_state, next_state: STATE_TYPE;
signal count: INTEGER;

type arraytype_Rj is array (0 to 15) of std_logic_vector (15 DOWNTO 0);
type arraytype_Coeff is array (0 to 511) of std_logic_vector (15 DOWNTO 0); -- Hard coded array size to coefficient count
type arraytype_InputL is array (0 to 255) of std_logic_vector (39 DOWNTO 0);  -- Hard coded array size to input count
type arraytype_Uj is array (0 to 15) of std_logic_vector (39 DOWNTO 0);
signal Rj : arraytype_Rj; 														-- Array to store Rj_Left
signal RjR : arraytype_Rj; 													-- Array to store Rj_Right
signal Coeff : arraytype_Coeff;												-- Array to store filter coefficients_left
signal CoeffR : arraytype_Coeff;												-- Array to store filter coefficients_Right
signal InputL_data : arraytype_InputL;		-- Array to store inputs_Left
signal InputR_data : arraytype_InputL;		-- Array to store inputs_Right
signal TempL : std_logic_vector (39 DOWNTO 0);
signal TempR : std_logic_vector (39 DOWNTO 0);
signal Uj : arraytype_Uj;						-- Array to store Uj
signal UjR : arraytype_Uj;						-- Array to store Uj_Right
signal i : integer; 														-- Index used to receive Rj bits
signal j : integer; 														-- Index used to receive filter coefficient bits
signal k : integer;														-- Index used to receive input bits
signal arrived : std_logic;												-- Flag indicating arrival of 16 input bits
signal rj_complete : std_logic;											-- Flag indicating Rj receive completion
signal coeff_complete : std_logic;										-- Flag indicating coefficients receive completion 
signal sleep_detect : std_logic;										-- Flag indicating arrival of continuous zero inputs
signal awake_flag : std_logic;											-- Flag indicating awake from sleep mode
signal bi : integer; 													-- Bit index signal for inputs
signal output_bi : integer;
signal m : integer;
signal p : integer;
signal q : integer;
signal mR : integer;
signal pR : integer;
signal qR : integer;
signal shift_flag : std_logic;
signal shift_flag1 : std_logic;
signal shift_flagR : std_logic;
signal shift_flag1R : std_logic;
signal Output_Final : std_logic_vector (39 DOWNTO 0);
signal Output_FinalR : std_logic_vector (39 DOWNTO 0);
signal OutputTemp : std_logic_vector (39 DOWNTO 0);
signal OutputTempR : std_logic_vector (39 DOWNTO 0);
signal Outfinish1 : std_logic;
signal Outfinish2 : std_logic;
signal Outfinish1R : std_logic;
signal Outfinish2R : std_logic;
signal out_calc : std_logic;
signal out_calcR : std_logic;
signal sum_flag : integer;
signal sum_flagR : integer;
signal UjL : std_logic_vector (39 DOWNTO 0);
signal LAdderIn2 : std_logic_vector (39 DOWNTO 0);
signal OPTemp : std_logic_vector (39 DOWNTO 0);
signal OPTShift : std_logic_vector (39 DOWNTO 0);
signal UjRight : std_logic_vector (39 DOWNTO 0);
signal RAdderIn2 : std_logic_vector (39 DOWNTO 0);
signal OPTempR : std_logic_vector (39 DOWNTO 0);
signal OPTShiftR : std_logic_vector (39 DOWNTO 0);
signal coeffCount : std_logic_vector (15 DOWNTO 0);



begin
AdderBlock : Adder port map (IN1=>UjL, IN2=>LAdderIn2, FLG=>shift_flag1, OUTADD=>OPTemp);
ShifterBlock : Shifter port map (INPUT=>OPTemp, FLG=>shift_flag, OUTPUT=>OPTShift);
AdderBlockRight : AdderRight port map (IN1=>UjRight, IN2=>RAdderIn2, FLG=>shift_flag1R, OUTADD=>OPTempR);
ShifterBlockRight : ShifterRight port map (INPUT=>OPTempR, FLG=>shift_flagR, OUTPUT=>OPTShiftR);



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
	if (rising_edge(Sclk)) then
		------------- S0 -------------
		if (current_state = S0) then
            if(Start = '1') then
                next_state <= S1;
            else
                next_state <= S0;
            end if;
			output_bi <= 39;
			p <= 0; 					pR <= 0;
			q <= 0; 					qR <= 0;
			m <= 0; 					mR <= 0;
			shift_flag <= '0'; shift_flag1 <= '0';	shift_flagR <= '0'; shift_flag1R <= '0'; 
			UjRight <= X"0000000000"; UjL <= X"0000000000"; LAdderIn2 <= X"0000000000"; RAdderIn2 <= X"0000000000";
			Output_Final <= X"0000000000";
			Output_FinalR <= X"0000000000";
			OutputTemp <= X"0000000000";
			OutputTempR <= X"0000000000";
			Outfinish1 <= '0';	Outfinish1R <= '0';
			Outfinish2 <= '0';	Outfinish2R <= '0';
			out_calc <= '0'; 		out_calcR <= '0';
			sum_flag <= 0;			sum_flagR <= 0;
					Uj <= (others => (others => '0'));
					UjR <= (others => (others => '0'));
			InReady <= '0';
			OutReady <= '1';
		
		------------- S1 -------------
		elsif (current_state = S1) then 
			-- Waiting to receive Rj
			InReady <= '1';
			if (Frame = '0') then
				next_state <= S2;
			else
				next_state <= S1;
			end if;
			OutReady <= '1';
		------------- S2 -------------
		elsif (current_state = S2) then 
			if (rj_complete = '1') then
				next_state <= S3;
			else
				next_state <= S2;
			end if;
			InReady <= '1';
			OutReady <= '1';
		------------- S3 -------------
		elsif (current_state = S3) then 
			-- Waiting to receive coefficients
			InReady <= '1';
			if (Frame = '0') then
				next_state <= S4;
			else
				next_state <= S3;
			end if;
			OutReady <= '1';
		------------- S4 -------------
		elsif (current_state = S4) then 
			if (coeff_complete = '1') then
				next_state <= S5;
			else
				next_state <= S4;
			end if;
			InReady <= '1';
			OutReady <= '1';
		------------- S5 -------------
		elsif (current_state = S5) then 
			-- Waiting to receive inputs
			InReady <= '1';
			if (Frame = '0') then
				next_state <= S6;
			else
				next_state <= S5;
			end if;
			OutReady <= '1';
		------------- S6 -------------
		elsif (current_state = S6) then 
			-- Output computation -- Begin
			---------------
			-- Left Channel
			if (arrived = '1' and out_calc = '0') then
				if ((k-1-conv_integer(Coeff(m) and X"00FF")) >= 0) then 	
					if ((Coeff(m) and X"0100") = X"0100") then
						Uj(0) <= Uj(0) - InputL_data((k-1-conv_integer(Coeff(m) and X"00FF")) mod 256);
					else
						Uj(0) <= Uj(0) + InputL_data((k-1-conv_integer(Coeff(m) and X"00FF")) mod 256);
					end if;
				end if;
				m <= m + 1;
				q <= 1;
				out_calc <= '1';	
			end if;
			-- Right Channel
			if (arrived = '1' and out_calcR = '0') then
				if ((k-1-conv_integer(CoeffR(mR) and X"00FF")) >= 0) then 	
					if ((CoeffR(mR) and X"0100") = X"0100") then
						UjR(0) <= UjR(0) - InputR_data((k-1-conv_integer(CoeffR(mR) and X"00FF")) mod 256);
					else
						UjR(0) <= UjR(0) + InputR_data((k-1-conv_integer(CoeffR(mR) and X"00FF")) mod 256);
					end if;
				end if;
				mR <= mR + 1;
				qR <= 1;
				out_calcR <= '1';
			end if;
			---------------
			-- Left Channel
			if(out_calc = '1') then
				if (p < 16) then
					if (q < conv_integer(Rj(p))) then
						if ((k-1-conv_integer(Coeff(m) and X"00FF")) >= 0) then 	
							if ((Coeff(m) and X"0100") = X"0100") then
								Uj(p) <= Uj(p) - InputL_data((k-1-conv_integer(Coeff(m) and X"00FF")) mod 256);
							else
								Uj(p) <= Uj(p) + InputL_data((k-1-conv_integer(Coeff(m) and X"00FF")) mod 256);
							end if;
						end if;
						m <= m+1;
						q <= q+1;
					end if;
				end if;

				if (p < 16) then
					if (q = conv_integer(Rj(p)) - 1) then 
						q <= 0;				
						p <= p+1;
					end if;
				end if;

				if(p > sum_flag and shift_flag = '0') then
					if(shift_flag1 = '0') then
						shift_flag1 <= '1';
						UjL <= Uj(sum_flag);
						LAdderIn2 <= Output_final;
					else
						shift_flag <= '1';
						shift_flag1 <= '0';
					end if;
				end if;

				if (shift_flag = '1') then
					Output_Final <= OPTShift;
					shift_flag <= '0';
					sum_flag <= sum_flag + 1;			
					if(sum_flag = 15) then
						Outfinish1 <= '1';
						Outfinish2 <= '1';
						p <= 0;
						q <= 0;
						m <= 0;
						out_calc <= '0';
						sum_flag <= 0;
						Uj <= (others => (others => '0'));
					end if;
				end if;
			end if;
			-- Right Channel
			if(out_calcR = '1') then
				if (pR < 16) then
					if (qR < conv_integer(RjR(pR))) then
						if ((k-1-conv_integer(CoeffR(mR) and X"00FF")) >= 0) then 	
							if ((CoeffR(mR) and X"0100") = X"0100") then
								UjR(pR) <= UjR(pR) - InputR_data((k-1-conv_integer(CoeffR(mR) and X"00FF")) mod 256);
							else
								UjR(pR) <= UjR(pR) + InputR_data((k-1-conv_integer(CoeffR(mR) and X"00FF")) mod 256);
							end if;
						end if;
						mR <= mR+1;
						qR <= qR+1;
					end if;
				end if;

				if (pR < 16) then
						if (qR = conv_integer(RjR(pR)) - 1) then
						qR <= 0;				
						pR <= pR+1;
					end if;
				end if;

				if(pR > sum_flagR and shift_flagR = '0') then
					if(shift_flag1R = '0') then
						shift_flag1R <= '1';
						UjRight <= UjR(sum_flagR);
						RAdderIn2 <= Output_FinalR;
					else
						shift_flagR <= '1';
						shift_flag1R <= '0';
					end if;
				end if;

				if (shift_flagR = '1') then
					Output_FinalR <= OPTShiftR;
					shift_flagR <= '0';
					sum_flagR <= sum_flagR + 1;
					if(sum_flagR = 15) then
						Outfinish1R <= '1';
						Outfinish2R <= '1';
						pR <= 0;
						qR <= 0;
						mR <= 0;
						out_calcR <= '0';
						sum_flagR <= 0;
							UjR <= (others => (others => '0'));
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
			
			if(sleep_detect = '1') then
				next_state <= S8;
			end if;
			-- output_state <= "0110";
		------------- S7 -------------
		elsif (current_state = S7) then   
			-- Clearing all input samples in memories to 0
			InReady <= '0'; -- Change and Check
			OutReady <= '1';
			p <= 0; 					pR <= 0;
			q <= 0; 					qR <= 0;
			m <= 0; 					mR <= 0;
			out_calc <= '0'; 		out_calcR <= '0';
			sum_flag <= 0;			sum_flagR <= 0;
			shift_flag <= '0';	shift_flagR <= '0';
			shift_flag1 <= '0';
			Outfinish1 <= '0';	Outfinish1R <= '0';
			Outfinish2 <= '0';	Outfinish2R <= '0';
				Uj <= (others => (others => '0'));
				UjR <= (others => (others => '0'));
			Output_Final <= X"0000000000";
			Output_FinalR <= X"0000000000";
			OutputTemp <= X"0000000000";
			OutputTempR <= X"0000000000";
			next_state <= S5;
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
			if (awake_flag = '1') then
				next_state <= S6;
			end if;
		end if;
	end if;
end process;

Dclk_process : process (Dclk, current_state, Start)
begin
	-- if (falling_edge(Sclk)) then
		   ------------- S0 -------------
		if (Start = '1') then
					Rj <= (others => (others => '0'));
					RjR <= (others => (others => '0'));
					Coeff <= (others => (others => '0'));
					CoeffR <= (others => (others => '0'));
					InputL_data <= (others => (others => '0'));
					InputR_data <= (others => (others => '0'));
			TempL <= X"0000000000";
			TempR <= X"0000000000";
			i <= 0; j <= 0; k <= 0;
			arrived <= '0';
			rj_complete <= '0';
			coeff_complete <= '0';
			sleep_detect <= '0';
			awake_flag <= '0';
			bi <= 15;
			count <= 0;
			coeffCount <= X"0000";
		end if;

	if (falling_edge(Dclk)) then

		------------- S2 -------------
		if (current_state = S2) then
			if(bi >= 0) then
				Rj(i)(bi) <= InputL;
				RjR(i)(bi) <= InputR;
				bi <= bi - 1;
			end if;
			if(bi = 0) then
				i <= i+1;
				bi <= 15;
				if(i = 15) then
					rj_complete <= '1';
				end if;
			end if;
			if(bi = 15 and i > 0) then
				coeffCount <= coeffCount + Rj(i-1);
			end if;
		------------- S4 -------------
		elsif (current_state = S4) then
			if(i = 16) then
				coeffCount <= coeffCount + Rj(15);
				i <= 30;
			end if;
			if(bi >= 0) then
				Coeff(j)(bi) <= InputL;
				CoeffR(j)(bi) <= InputR;				
				bi <= bi - 1;
			end if;
			if(bi = 0) then
				j <= j+1;
				bi <= 15;
				if(j = conv_integer(coeffCount) - 1) then
					coeff_complete <= '1';
				end if;
			end if;
		------------- S6 -------------
		elsif (current_state = S6) then
			if (bi >= 0) then
				if (bi = 15 and InputL = '1') then
					TempL(39 DOWNTO 32) <= X"FF"; -- changed
				elsif (bi = 15 and InputL = '0') then
					TempL(39 DOWNTO 32) <= X"00"; -- changed
				end if;
				if (bi = 15 and InputR = '1') then
					TempR(39 DOWNTO 32) <= X"FF";
				elsif (bi = 15 and InputR = '0') then
					TempR(39 DOWNTO 32) <= X"00"; -- changed
				end if;
				TempL(bi+16) <= InputL;
				TempR(bi+16) <= InputR;				
				bi <= bi -1 ;
			end if;

			if (bi = 0) then
				k <= k + 1;
				bi <= 15;
				-- Assigning temp to inputs
				InputL_data(k mod 256) <= TempL;
				InputL_data(k mod 256)(16) <= InputL;
				InputR_data(k mod 256) <= TempR;
				InputR_data(k mod 256)(16) <= InputR;
				
				if(TempL(39 DOWNTO 17) = "00000000000000000000000" and InputL ='0' and TempR(39 DOWNTO 17) = "00000000000000000000000" and InputR = '0') then
					count <= count + 1;
					if (count = 800 - 1) then
						count <= 0;
						sleep_detect <= '1';
					end if;
				else
					count <= 0;
				end if;
				arrived <= '1';
			end if;

			if (arrived = '1') then -- Right Channel to be added
				arrived <= '0';
			end if;
			
			if (awake_flag = '1') then
				awake_flag <= '0';
			end if;
		------------- S7 -------------
		elsif (current_state <= S7) then
			for i in 0 to 256 - 1 loop -- was k before
				InputL_data(i) <= X"0000000000";
				InputR_data(i) <= X"0000000000";
			end loop;
			arrived <= '0';
			k <= 0;
			bi <= 15;
			sleep_detect <= '0';
			awake_flag <= '0';
		------------- S8 -------------
		elsif (current_state = S8) then
			if (bi >= 0) then
				if (bi = 15 and InputL = '1') then
					TempL(39 DOWNTO 32) <= X"FF";
				elsif (bi = 15 and InputL = '0') then
					TempL(39 DOWNTO 32) <= X"00";
				end if;
				if (bi = 15 and InputR = '1') then
					TempR(39 DOWNTO 32) <= X"FF";
				elsif (bi = 15 and InputR = '0') then
					TempR(39 DOWNTO 32) <= X"00";
				end if;
				TempL(bi+16) <= InputL;
				TempR(bi+16) <= InputR;
				bi <= bi - 1 ;
				end if;
			
			if (bi = 0) then
				k <= k + 1;
				bi <= 15;
				-- Assigning temp to inputs
				InputL_data(k mod 256) <= TempL;
				InputL_data(k mod 256)(16) <= InputL;
				InputR_data(k mod 256) <= TempR;
				InputR_data(k mod 256)(16) <= InputR;
				if (TempL(39 DOWNTO 17) /= "00000000000000000000000" or InputL = '1' or TempR(39 DOWNTO 0) /= "00000000000000000000000" or InputR = '1' ) then
					arrived <= '1';
					awake_flag <= '1';
				end if;
			end if;
			sleep_detect <= '0';
		end if;
	end if;
end process;

end Behavioral;
