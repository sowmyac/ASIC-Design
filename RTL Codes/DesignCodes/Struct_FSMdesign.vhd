library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_signed.all;
use ieee.numeric_std.all;

entity MSDAP is
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
end MSDAP;

architecture Behavioral of MSDAP is

component Controller is
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
		  end component;
		  
	  	  
begin
MSDAPBlock: Controller port map (Sclk=>Sclk, Dclk=>Dclk, Start=>Start, InReady=>InReady, Frame=>Frame, InputL=>InputL, InputR=>InputR, Reset_n=>Reset_n, OutputL=>OutputL , OutputR=>OutputR, OutReady=>OutReady);
end Behavioral;

