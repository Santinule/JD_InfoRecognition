library(tidyverse)
library(officer)

#get file paths for jd's
Sys.glob("../data/JHH/*.docx")->files_word
Sys.glob("../data/sample_jd/*.docx")->files_word2
files_word <- c(files_word2,files_word[1:255])
length(files_word)


#Generate df, get keys to later append data from jd
meta_df2<-data.frame(files=files_word)

meta_df2 %>% 
  mutate(dsm= vectorized_get_dsm(meta_df2$files),
         know_line_index =999)->meta_df2




# extract data from JD 
vector_notFound <- vector(mode = "list", length=100)
k <- 1
for(i in 1:length(files_word)){
  print(i)
  func3(i, files_word)$text->text
  # Remove NA and whitespace from text
  text <- na.omit(text) # remove NA values
  text <- trimws(text) # remove leading and trailing white spaces
  text <- text[nzchar(text)] # remove empty string
  
  #Individual doc operations
  #Position Summary
  found <- F
  for(line_num in 1:300){
    text[line_num]->current_line
    if(grepl("Knowledge:", ignore.case = T,x= current_line)){
      meta_df2$know_line_index[i]<-line_num
      for(j in 0:30){
        meta_df2[[paste0("know_next", j, "_literal")]][i] <- text[line_num + j]
      }
      found <- T
      break
    }
  }
  if(!found){
    for(j in 0:30){
      meta_df2[[paste0("know_next", j, "_literal")]][i] <- "not found"
    }
    vector_notFound[k] <- i
    k <- k+1
  }
  
}

##Easier for analyzing text in view mode while cleaning
meta_df2 %>% 
  select(c("dsm", names(meta_df2)[4:ncol(meta_df2)])) ->df

# Create a list of column names except the 'dsm' column
column_names <- names(df)[2:ncol(df)]

# Initialize empty lists to store the data for the new DataFrame
dsm_list <- vector("integer")
text_list <- vector("character")
previous_column_number_list <- vector("integer")

# Iterate over the rows and columns of the original DataFrame
for (i in 1:nrow(df)) {
  row <- df[i, ]
  for (j in 1:length(column_names)) {
    column <- column_names[j]
    value <- row[[column]]
    if (!is.na(value)) {
      dsm_list <- c(dsm_list, row[["dsm"]])
      text_list <- c(text_list, value)
      previous_column_number_list <- c(previous_column_number_list, j + 1)
    }
  }
}


##Pass it onto long df for labeling
data.frame(dsm = dsm_list,
           text = text_list,
           previous_column_number = previous_column_number_list) %>% 
  mutate(str_len = str_length(text)) %>% 
  filter(str_len>3) %>% 
  filter(text !="not found")->new_df


# Clean data and generate algorithm to automate labeling
new_df %>% 
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
  group_by(dsm, double) %>%
  mutate(previous_line = lag(text, default = "none"),
         line_behind2 = lag(text, n = 2, default = "none"))->new_df6


#Save data to csv to then train the model
# write_csv(new_df6,"../data/isq_df.csv")

