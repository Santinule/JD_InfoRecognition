library(tidyverse)
#load data beginning from qialfifications
read_csv( "../data/final_df/quali_final_df2.csv")->quali_df

#Change classification to improve data quality for modeling
quali_df[1:4] %>%
  mutate(ksa_identifier = case_when(str_detect(text,".+Knowledge:")~"Remove",
                                    str_detect(text,".+Skills:")~"Remove",
                                    str_detect(text,"^Knowledge:")~"Knowledge",
                                    str_detect(text, "^Skills:")~"Skills",
                                    str_detect(text, "Licensure") ~ "Licensure",
                                    str_detect(text, "Machines, Tools, Equipment:")~"mte",
                                    str_detect(text, "Work Experience:")~"Experience",
                                    T~"False"))->new_df2

new_df2 %>% 
  filter(ksa_identifier == "Remove") %>%
  distinct(dsm) %>%
  pull(dsm)->dsm_remove

new_df2 %>% 
  filter(!(dsm %in% dsm_remove)) %>%
  group_by(dsm) %>% 
  mutate(between = ifelse((cumsum(ksa_identifier == "Knowledge") > 0) & 
                            (cumsum(ksa_identifier == "Skills") == 0) , "between", "not_between"),
         ksa_identifier2= case_when(between=="between"& ksa_identifier=="Knowledge"~ "other",
                                    between=="between"& ksa_identifier=="False"~"Knowledge",
                                    T~ksa_identifier),
         numeric_helper = case_when(ksa_identifier2=="other"~100,
                                    ksa_identifier2=="Knowledge"~0,
                                    ksa_identifier =="Skills"~300,
                                    ksa_identifier2=="Licensure"~400,
                                    ksa_identifier2=="mte"~500,
                                    T~0
         )) %>%
  group_by(dsm) %>% 
  mutate(numeric_helper2 = cumsum(numeric_helper),
         ksa_identifier2 = case_when(numeric_helper==300 &numeric_helper2== 400 &str_len<16 ~"other2",
                                     numeric_helper2== 400~"Skills",
                                     T~ksa_identifier2))->new_df3

new_df3  %>% 
  mutate(ksa_identifier = ksa_identifier2) %>%
  select(-names(new_df3[6:8])) %>% 
  mutate(ksa_identifier = case_when(ksa_identifier=="Knowledge" & str_detect(text,"Knowledge:") & str_len <13 ~"Remove",
                                    ksa_identifier=="Skills" & str_detect(text,"Skills:") & str_len <13 ~"Remove",
                                    ksa_identifier=="Licensure" & str_detect(text,"(?i)Certification, etc.[:]?$")  ~"Remove",
                                    ksa_identifier=="Experience" & str_detect(text, "Work Experience:$")~"Remove",
                                    str_detect(text,"Dimensions:")~"dim",
                                    T~ksa_identifier
  )) %>% 
  mutate(dsm_change = dsm != lag(dsm, default = first(dsm))) %>%
  mutate(dsm_seq = cumsum(dsm_change)) %>%
  group_by(dsm, dsm_seq) %>%
  mutate(count = row_number()) %>%
  ungroup() %>%
  select(-dsm_change, -dsm_seq) %>% 
  group_by(dsm) %>% 
  mutate(num_helper = case_when(ksa_identifier == "dim"~100,
                                T~0),
         cumsum = cumsum(num_helper),
         ksa_identifier = case_when(cumsum==100~"Remove",
                                    T~ksa_identifier)) %>%
  ungroup()->new_df4



new_df4 %>% 
  select(c(names(new_df3[1:5]),count)) %>% 
  mutate(is_qualification = case_when(ksa_identifier=="other"|ksa_identifier=="other2"|ksa_identifier=="Remove" |ksa_identifier=="mte"|ksa_identifier=="dim"~0,
                                      ksa_identifier=="Knowledge" ~ 1,
                                      ksa_identifier=="Skills" ~ 2,
                                      ksa_identifier=="Licensure" ~ 3,
                                      ksa_identifier=="Experience" ~ 4,
                                      ksa_identifier=="False" ~ -1
  ),
  double = case_when(count>31~T,
                     T~F))->new_df5
new_df5 %>% 
  mutate(text = str_replace_all(text, "\\s+", " ")) %>% 
  mutate(is_qualification= case_when(str_detect(text,"(?i)knowledge") & str_len>30~1,
                                     str_detect(text,":\\s*$") ~0,
                                     T~is_qualification)) %>% 
  mutate(entity_encode = str_sub(dsm, end = 2))->quali_train_final


#write data for modelling
#write_csv(quali_train_final, "../data/isq_train_final.csv")