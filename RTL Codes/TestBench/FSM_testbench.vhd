-------------------- Library Declarations ---------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_textio.all;    -- for hread(), hwrite()
use IEEE.std_logic_unsigned.all;  -- for conv_integer()
use std.textio.all;               -- for file operations

entity testbench is
end testbench;

----------------- Architecture Declarations -------------------
architecture examine of testbench is

-- data clock frequency of 768KHz (1302ns) for 1 bit, 48KHz for 16 bits
constant DclkFreq_KHz : integer := 768;
constant SclkFreq_KHz : integer := 26888;

constant RjNum    : integer := 16;   
constant CoefNum  : integer := 512;        

constant DclkPeriod : time := 1 ms/DclkFreq_KHz;
constant SclkPeriod : time := 1 ms/SclkFreq_KHz;


constant Time16bit   : time := DclkPeriod*16;   -- 20832 ns
constant WaitInReady : time := DclkPeriod*3;    -- 3906 ns

constant StartBegin :time:=100 ns;                                              -- 100 ns
constant StartEnd   :time:=StartBegin+DclkPeriod;                               -- 1402 ns
constant TransBegin :time:=DclkPeriod+WaitInReady;                              -- 5208 ns
constant ResetBegin1:time:=TransBegin+Time16bit*(RjNum+CoefNum+4200)+10125 ns;  -- 98.279877 ms
constant ResetEnd1  :time:=ResetBegin1+DclkPeriod;                              -- 98.281179 ms
constant ResetBegin2:time:=ResetEnd1+WaitInReady+Time16bit*1799+6060 ns;        -- 135.767913 ms
constant ResetEnd2  :time:=ResetBegin2+DclkPeriod;                              -- 135.769215 ms

file inputfile     : text open read_mode  is "Midterm2.in";
file inputfile_ex  : text open read_mode  is "Midterm2_posted.out";
file outputfile    : text open write_mode is "Midterm_2compare.out";

-- Declare the entity under test.

component Controller
    port(
        Sclk     : in  std_logic;
        Dclk     : in  std_logic;
        Start    : in  std_logic;
        Reset_n  : in  std_logic;
        Frame    : in  std_logic;
        InputL   : in  std_logic;
        InputR   : in  std_logic;
        InReady  : out std_logic;
        OutReady : out std_logic;
        OutputL  : out std_logic;
		OutputR  : out std_logic
    );
end component Controller;


signal Sclk_tb     : std_logic := '1';
signal Dclk_tb     : std_logic := '1';
signal Dclk_tbb    : std_logic;
signal Dclk_tb_1   : std_logic;
signal Start_tb    : std_logic;
signal Reset_n_tb  : std_logic;
signal Frame_tb    : std_logic := '1';			--modified frame
signal InputL_tb   : std_logic := '0';
signal InputR_tb   : std_logic := '0';
signal InReady_tb  : std_logic := '0';
signal OutReady_tb : std_logic := '1';			--modified OutReady
signal OutputL_tb  : std_logic := '0';
signal OutputR_tb  : std_logic := '0';


signal countRj     : integer range 0 to 16; 
signal countcoeff  : integer range 0 to 512;
signal countInput  : integer range 0 to 7000;
signal countOutput : integer range 0 to 6400;
signal countWrong  : integer range 0 to 6400;
signal correct_out : std_logic := '0';


 
begin    
   -- Apply to entity under test.
   UUT: Controller
        port map(
                  Sclk     => Sclk_tb,
                  Dclk     => Dclk_tbb,
                  Start    => Start_tb,
                  Reset_n  => Reset_n_tb,
                  Frame    => Frame_tb,
                  InputL   => InputL_tb,
                  InputR   => InputR_tb,
                  InReady  => InReady_tb,
                  OutReady => OutReady_tb,
                  OutputL  => OutputL_tb,
				  OutputR  => OutputR_tb	          
                 );

      
    Sclk_tb <= not Sclk_tb after SclkPeriod/2;
    Dclk_tb <= not Dclk_tb after DclkPeriod/2;
                
    -- If InReady='0', no Dclk, Frame and any input sample until InReady='1'.
    Dclk_tbb <= Dclk_tb when InReady_tb = '1' else '0';

    -- Generate one clock reference which is a little delay of Dclk.
    Dclk_tb_1 <= Dclk_tb'delayed(10 ns);

    Start_tb   <= '0', '1' after StartBegin,  '0' after StartEnd;   
    Reset_n_tb <= '1', '0' after ResetBegin1, '1' after ResetEnd1,
                       '0' after ResetBegin2, '1' after ResetEnd2;

    -- 1. Read each serial output word transmitting from the MSDAP chip bit by bit
    --    and store in a parallel vector. Then write this vector to an output file.
    -- 2. Wait a little delay of data clock to catch output data.
    WriteOutput : process (Start_tb,Sclk_tb)
        -- line is an access type predefined in the textio package.
        variable BufLineOut    : line;
        variable BufLineOut_ex : line;      
        
        variable OutputL_var    : std_logic_vector(39 downto 0);
        variable OutputR_var    : std_logic_vector(39 downto 0); 
        variable OutputL_var_ex : std_logic_vector(39 downto 0);
        variable OutputR_var_ex : std_logic_vector(39 downto 0);        

        variable countBit    : integer range 0 to 39;
        
        --variable countWrong  : integer range 0 to 2692;
    begin
        if rising_edge(Start_tb) then        
            countOutput <= 1;
            countWrong  <= 0;
            correct_out <= '0';
            
            write(BufLineOut, string'("// This is a generated output file."));
            writeline(outputfile, BufLineOut);
            write(BufLineOut, string'("//"));
            writeline(outputfile, BufLineOut);
            write(BufLineOut, string'("//         Obtained             |          Expected             |  Compare Result"));
            writeline(outputfile, BufLineOut); 
            write(BufLineOut, string'("// OutputL         OutputR      |  OutputL         OutputR      |  No."));
            writeline(outputfile, BufLineOut);      
              
        elsif falling_edge(Sclk_tb) then
            if OutReady_tb = '1' then
                countBit := 39;
                OutputL_var    := (others=>'0');
                OutputR_var    := (others=>'0'); 
                OutputL_var_ex := (others=>'0');
                OutputR_var_ex := (others=>'0');               
            elsif OutReady_tb ='0' then	
			   --modified frame
               --  1. OutReady='1' begins with the first bit of output.
               --  2. Frame aligns with the first bit of both each input and each output word.
               --     So Frame signal should be high at this moment, otherwise Error.
                if ((countBit = 39) and (Frame_tb = '1')) then	--modified frame
                    report "Frame and OutReady signals are not aligned!"
                    severity ERROR;
                end if;

                OutputL_var(countBit) := OutputL_tb;
                OutputR_var(countBit) := OutputR_tb;
 

                if countBit = 0 then
                    countBit := 39;
                    countOutput <= countOutput + 1;
                    readline(inputfile_ex, BufLineOut_ex);  -- read line from file                 
                          
                    hread(BufLineOut_ex, OutputL_var_ex);
                    hread(BufLineOut_ex, OutputR_var_ex);
                    
                    write(BufLineOut, string'("   "));
                    hwrite(BufLineOut, OutputL_var);
                    write(BufLineOut, string'("      "));
                    hwrite(BufLineOut, OutputR_var);
                    write(BufLineOut, string'("   |"));
                    
                    write(BufLineOut, string'("  "));
                    hwrite(BufLineOut, OutputL_var_ex);
                    write(BufLineOut, string'("      "));
                    hwrite(BufLineOut, OutputR_var_ex);        
                    write(BufLineOut, string'("   |"));             
                    
                    write(BufLineOut, string'("  // "));
                    write(BufLineOut, countOutput);
                    
                     if ((OutputL_var /= OutputL_var_ex) or (OutputR_var /= OutputR_var_ex)) then
                         write(BufLineOut, string'("   :mismatch"));
                         countWrong <= countWrong + 1;
                         correct_out <= '0';
                     else
                         correct_out <= '1';
                     end if;
                     
                    writeline(outputfile, BufLineOut);                    
                else
                    countBit := countBit - 1;
                end if;
            end if;      
        end if;     
    end process;


--print the final result after simulation.
WriteComment:process(countOutput)

variable BufLineOut    : line;

begin        
        if (countOutput>6393) then
            if(countWrong=0) then
              write(BufLineOut, string'("--------------------------------------------------------------------------------"));
              writeline(outputfile, BufLineOut); 
              write(BufLineOut, string'("Congratulations! Your output is 100% correct!"));
              writeline(outputfile, BufLineOut);  
            else
              write(BufLineOut, string'("--------------------------------------------------------------------------------"));
              writeline(outputfile, BufLineOut); 
              write(BufLineOut, string'("Your output: "));
              write(BufLineOut, countWrong);
              write(BufLineOut, string'(" mismatch!"));
              writeline(outputfile, BufLineOut);  
            end if;
        end if;
end process;
 

    -- Read each input word from an input file and feed to
    -- the input pin of the MSDAP chip in serial manner.
    ReadInput : 
        process
        -- line is an access type predefined in the textio package.
        variable BufLineIn : line;

        -- hread() needs them to be variable instead of signal.
        variable InputL_var       : std_logic_vector(15 downto 0);
        variable InputR_var       : std_logic_vector(15 downto 0);
        
        
        variable temp       : std_logic_vector(15 downto 0);
        variable sumRj      : integer range 0 to 65536;
        variable i          : integer range 0 to 16;

             
    begin

        InputL_var       := (others=>'0');
        InputR_var       := (others=>'0');
        temp             := (others=>'0');
      
        wait for TransBegin;
        -- After Start and enough time (close to the time of WaitInReady), InReady
        -- should be high on the rising_edge(Dclk), otherwise Error.
        if InReady_tb = '0' then
            report "InReady signal is missing!"
            severity ERROR;
            wait;  -- "wait" stops running code but ModelSim keeps going.
        end if;
         
        while not endfile(inputfile) loop
          
            readline(inputfile, BufLineIn);  -- read line from file                 
            if BufLineIn(1) = '/' then
                next;  -- skip this comment line in file            
            end if;
            
         
            Frame_tb <= '0';					--modified frame
            hread(BufLineIn, InputL_var);
            hread(BufLineIn, InputR_var);

                       
                                        
         -- Finish loading all coefficients. Then begin to count input.
          if  (countRj = 16) then
                sumRj       :=  conv_integer(temp);
             if  (countcoeff < sumRj) then
                   countcoeff  <=  countcoeff + 1;
             else
                   countInput  <=  countInput + 1;
             end if;
          else                
                  temp        :=  temp + InputL_var;
                  countRj     <=  countRj + 1;
          end if;
             
             
        i := 16;
          
 
 -- Reading 16 bit data  
         while (i > 0 ) loop
               i := i - 1;          
                -- It's better to catch NOW during a period of time instead of a moment only.
                if (((NOW >= ResetBegin1) and (NOW <= ResetEnd1)) or
                    ((NOW >= ResetBegin2) and (NOW <= ResetEnd2))) then

                    i := 0;
                    Frame_tb <= '1';			--modified frame

                    wait for (DclkPeriod + WaitInReady); 
                    -- After reset and enough time, InReady should be high at this moment,
                    -- otherwise Error.
                    if InReady_tb = '0' then
                       report "InReady signal is missing!"
                       severity ERROR;
                       wait;  -- "wait" stops running code but ModelSim keeps going.
                    end if;                                       
                 else
                    InputL_tb <= InputL_var(i);
                    InputR_tb <= InputR_var(i);
                    wait for DclkPeriod;
                    Frame_tb <= '1';				--modified frame
                end if;
          end loop;
              
        end loop;   
			

        report "Simulation is done!"
        severity NOTE;
      
        wait for DclkPeriod*5;  -- Flush out pipe line in hardware model.
        wait;  -- Stop simulation.
    end process;
    
    
 end examine;