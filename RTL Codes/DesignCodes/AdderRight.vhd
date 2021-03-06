library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_signed.all;
use ieee.numeric_std.all;


entity AdderRight is
Port (IN1 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		IN2 : in STD_LOGIC_VECTOR (39 DOWNTO 0);
		FLG : in STD_LOGIC;
		OUTADD : out STD_LOGIC_VECTOR (39 DOWNTO 0)
		);
end AdderRight;

architecture Behavioral of AdderRight is
begin
Add_process_Right: process (IN1, IN2, FLG)
begin
		if (FLG = '1') then
		OUTADD <= IN1 + IN2;
		end if;
end process;
end Behavioral;
