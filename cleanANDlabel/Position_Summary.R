library(tidyverse)
library(officer)

#get file paths for jd's
Sys.glob("../data/JHH/*.docx")->files_word
Sys.glob("../data/sample_jd/*.docx")->files_word2
files_word <- c(files_word2,files_word[1:255])

#Generate df, get keys to later append data from jd
ps_df<-data.frame(files=files_word)
ps_df %>% 
  mutate(dsm= vectorized_get_dsm(ps_df$files))->ps_df

# extract data from JD calling get_text function

##Easier for analyzing text in view mode while cleaning
ps_df2 <- get_text(df= ps_df, pattern ="summary\\s*|summary|summary:$",name ="ps", nv=c(0,30,300), print_num =T)

##Pass it onto labeling jd
long_text_df(ps_df2)->ps_long


# Clean data and generate algorithm to automate labeling
ps_long %>% mutate(done = case_when( previous_column_number==2 & str_len>26 & !str_detect(text,"^\\d") ~1,# label column 1 from ps_df2
                                     previous_column_number==2 & str_len>26 & str_detect(text,"^\\d")~0,#label 0 for numerical first_lin
                                     T~ -1)) %>%
  mutate(mark = case_when(done== -1 & previous_column_number==2~"algo2_start", #Marks position summary regular
                          str_detect(text, "^competencies:|^Competencies|^COMPE") ~ "group", #Marks occurrences as group
                          str_detect(text, "^Essential|^ESSENTIAL")~ "group",
                          str_detect(text, "^Qualifications:|^QUALIFICATIONS")~ "group",
                          str_detect(text, "^Work Experience:|^WORK EXPERIENCE")~ "group",
                          str_detect(text, "^Education|^EDUCATION")~"group",
                          str_detect(text, "^Reporting Relationship:")~"group",
                          T~"other"))->ps_long2 #Everything else as other
ps_long2 %>% 
  group_by(dsm) %>% 
  mutate(cum = cumsum(previous_column_number)) %>% #find dsm for jd duplicates
  filter(previous_column_number==2 &cum>2)->repeated_dsm

ps_long2 %>% 
  filter(!(dsm %in% repeated_dsm$dsm)) %>% 
  filter(mark =="group")->dsm_conatinsGroup 

ps_long2 %>% 
  filter(!(dsm %in% repeated_dsm$dsm)) %>% 
  group_by(dsm) %>% 
  mutate(cumgroups = cumsum(mark =="group")) %>%
  mutate(done = case_when(mark == "other" & cumgroups==0 &
                            (dsm %in% dsm_conatinsGroup$dsm) ~1, #everything between ps_literal and either one of the group labels is 1 
                          str_detect(text, "Strategic Partnering Responsibilities:") |cumgroups>=1 | (str_len<30 & str_detect(text, ":$")) ~0,
                          T~done))->ps_long3

#get codes that we are not sure about whether they may be part of ps but previous algo txonomized them as ps
ps_long3 %>% 
  filter(previous_column_number>12& done ==1)->unsure_dones
#label codes as unknown; code -1
ps_long3 %>% 
  mutate( is_ps = case_when(dsm %in% unsure_dones$dsm ~ -1,
                            T~done), .before = done) %>% 
  select(names(.)[1:5])->ps_long4

#create text lags
ps_long4 %>% 
  mutate(entity_encode = str_sub(dsm, end = 2)) %>% 
  group_by(dsm) %>% 
  mutate(lag_text = lag(text, default = "first line"),
         lag_text2 = lag(lag_text, default = "second line"),
         lag_text3 = lag(lag_text2, default = "third line"),
         lag_text4 = lag(lag_text3, default = "fourth line"))->pstrain_df


#write_csv(pstrain_df, "../data/pst_df.csv")