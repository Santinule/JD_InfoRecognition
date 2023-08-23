library(tidyverse)
#load data beginning from qialfifications
read_csv( "../data/final_df/ps_final_df2.csv")->ps_data

#Change classification to improve data quality for modeling
ps_data[1:4] %>%mutate(done = case_when( previous_column_number==2 & str_len>26 & !str_detect(text,"^\\d") ~1,# label column 1 from ps_df2
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

#get codes that we are not sure about whether they may be part of ps but previous algo taxonomized them as ps
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
  mutate(lag_text = lag(text, default = "line one"),
         lag_text2 = lag(lag_text, default = "line two"),
         lead_text = lead(text, default = "subsequent line one"),
         lead_text2 = lead(lead_text, default = "subsequent line two"))->ps_train2

#write_csv(ps_train2, "../data/pst2_df.csv")
read_csv("../data/pst2_df.csv")->train
read_csv( "../data/final_df/ps_final_df2.csv")->live

dim(train)
dim(live)

live[1:4]  %>% 
  mutate(entity_encode = str_sub(dsm, end = 2)) %>% 
  group_by(dsm) %>% 
  mutate(lag_text = lag(text, default = "line one"),
         lag_text2 = lag(lag_text, default = "line two"),
         lead_text = lead(text, default = "subsequent line one"),
         lead_text2 = lead(lead_text, default = "subsequent line two"))->ps_final2_lead

#write_csv(ps_final2_lead, "../data/final_df/ps_final2_lead.csv")