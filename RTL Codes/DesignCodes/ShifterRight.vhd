library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_signed.all;
use ieee.numeric_std.all;

entity ShifterRight is
Port (INPUT : in  STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
      OUTPUT : out  STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
end ShifterRight;

architecture Behavioral of ShifterRight is

begin
Shiter_process_Right : process (INPUT,FLG)
begin
	if( FLG = '1' ) then
		OUTPUT <= std_logic_vector(shift_right(signed(INPUT), 1));
	end if;
end process;
end Behavioral;