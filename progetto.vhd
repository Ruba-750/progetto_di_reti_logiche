library IEEE;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;

entity project_reti_logiche is
port(
    i_clk : in std_logic;
    i_rst : in std_logic;
    i_start : in std_logic;
    i_add : in std_logic_vector(15 downto 0);
    i_k : in std_logic_vector(9 downto 0);
    
    o_done : out std_logic;
    o_mem_addr: out std_logic_vector(15 downto 0);
    i_mem_data: in std_logic_vector(7 downto 0);
    o_mem_data: out std_logic_vector(7 downto 0);
    o_mem_we: out std_logic;
    o_mem_en: out std_logic
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
     -- I segnali _nx servono per salvare i nuovi valori dei registri, aggiornati al successivo rising edge del clock 
     type state_type is (IDLE, CHECK_LENGHT, ASK_VALUE, READ_VALUE, WRITE_C, WRITE_VALUE, DONE);
     signal next_state, curr_state: state_type; 
     signal o_done_nx : std_logic := '0';
     signal o_mem_addr_nx : std_logic_vector(15 downto 0) := (others => '0');
     signal o_mem_data_nx : std_logic_vector(7 downto 0) := (others => '0');
     signal o_mem_en_nx : std_logic := '0';
     signal o_mem_we_nx : std_logic := '0';
     signal old_value_nx, old_value : std_logic_vector(7 DOWNTO 0) := (others => '0');
     signal old_c_nx, old_c : std_logic_vector(7 DOWNTO 0) := (others => '0');
     signal visited_words_nx, visited_words : std_logic_vector(9 DOWNTO 0) := (others => '0'); -- visited_words: numero di parole già visitate
     signal updated_add_nx, updated_add : std_logic_vector(15 DOWNTO 0) := (others => '0'); -- updated_add: indirizzo che verrà aggiornato e utilizzato per ogni lettura/scrittura
     signal first_nx, first: boolean := true; -- first: tiene traccia dell'inizio di una nuova elaborazione, per gestire il corner-case della stringa che inizia con 0 
     
begin

  process(i_clk, i_rst)
        begin
            if (i_rst = '1') then
              o_done <= '0';
              curr_state <= IDLE;
              o_mem_addr <= "0000000000000000";
              o_mem_data <= "00000000";
              o_mem_en <= '0';
              o_mem_we <= '0';
              old_c <= "00000000";
              old_value <= "00000000";
              first <= true;
            elsif (rising_edge(i_clk)) then
              curr_state <= next_state;
              o_done <= o_done_nx;
              o_mem_addr <= o_mem_addr_nx;
              o_mem_data <= o_mem_data_nx ;
              o_mem_en <= o_mem_en_nx;
              o_mem_we <= o_mem_we_nx;
              first <= first_nx; 
              updated_add <= updated_add_nx;
              visited_words <= visited_words_nx;
              old_value <= old_value_nx;
              old_c <= old_c_nx;
            end if;
     end process;

     
     process(first, old_value, old_c, visited_words, updated_add, i_start, i_add, i_k, i_mem_data, curr_state, visited_words_nx, updated_add_nx)
         begin
                o_done_nx <= '0';
                o_mem_data_nx <= "00000000";
                
                case curr_state is
                     when IDLE =>
                        o_mem_addr_nx <= "0000000000000000";
                        o_mem_data_nx <= "00000000";
                        o_mem_en_nx <= '0';
                        o_mem_we_nx <= '0';
                        o_done_nx <= '0';
                        next_state <= IDLE;
                        old_c_nx <= "00000000";
                        old_value_nx <= "00000000";
                        visited_words_nx <= (others => '0');
                        updated_add_nx <= (others => '0');                       
                        if(i_start = '1') then
                            next_state <= CHECK_LENGHT;
                            updated_add_nx <= i_add;
                        end if;
                        
                      when CHECK_LENGHT =>
                          if(unsigned (visited_words) = unsigned(i_k)) then 
                                o_mem_en_nx <= '1';
                                o_mem_we_nx <= '0';
                                o_mem_addr_nx <= updated_add; 
                            next_state <= DONE;
                          else 
                            next_state <= ASK_VALUE;
                            o_mem_en_nx <= '1';
                            o_mem_we_nx <= '0';
                            o_mem_addr_nx <= updated_add;                         
                            visited_words_nx <=  std_logic_vector(unsigned(visited_words) + 1);
                          end if;
                          
                     when ASK_VALUE =>
                        o_mem_en_nx <= '1';
                        o_mem_we_nx <= '0';
                        o_mem_addr_nx <= updated_add; 
                        next_state <= READ_VALUE;
                        
                     when READ_VALUE =>   
                         o_mem_en_nx <= '1';
                         o_mem_we_nx <= '0';
                         old_value_nx <= old_value;
                         old_c_nx <= old_c;
                         if(first) then
                            if(i_mem_data = "00000000") then
                                old_c_nx <= "00000000";
                            else
                               old_value_nx <= i_mem_data;
                               old_c_nx <= "00011111";
                            end if;
                            first_nx <= false;
                         elsif(i_mem_data = "00000000") then
                            if(old_c > "00000000") then
                                old_c_nx <= old_c - "00000001";
                            else
                                old_c_nx <= "00000000";
                            end if;
                         else
                            old_c_nx <=  "00011111";
                            old_value_nx <= i_mem_data;
                         end if;
                         next_state <=  WRITE_VALUE;
                         
                    when WRITE_C =>
                       o_mem_en_nx <= '1';
                       o_mem_we_nx <= '1';
                       o_mem_data_nx <= old_c;
                       o_mem_addr_nx <= updated_add;
                       updated_add_nx <= updated_add + "0000000000000001";
                       next_state <= CHECK_LENGHT;       
                        
                   when WRITE_VALUE =>
                       o_mem_en_nx <= '1';
                       o_mem_we_nx <= '1';
                       o_mem_data_nx <= old_value;
                       o_mem_addr_nx <= updated_add;
                       updated_add_nx <= updated_add + "0000000000000001";
                       next_state <= WRITE_C;
                      
                     
                   when DONE =>
                        o_done_nx <= '1';
                        o_mem_en_nx <= '0';
                        o_mem_we_nx <= '0';
                        old_c_nx <= "00000000";
                        old_value_nx <= "00000000";
                        o_mem_addr_nx <= "0000000000000000";
                        o_mem_data_nx <= "00000000";
                        if (i_start = '0') then
                            o_done_nx <= '0';
                            next_state <= IDLE;
                        end if;
                
                     
            end case;
          end process;

end Behavioral;