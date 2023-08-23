library(tidyverse)
library(officer)

#get file paths for jd's
Sys.glob("../data/JHH/*.docx")->files_word
Sys.glob("../data/sample_jd/*.docx")->files_word2
files_word <- c(files_word2,files_word[1:255])


#Generate df, get keys to later append data from jd
meta_df<-data.frame(files=files_word)
meta_df %>% 
  mutate(dsm= vectorized_get_dsm(meta_df$files))->meta_df


# extract data from JD calling get_text function, 

##Easier for analyzing text in view mode while cleaning
get_text(df = meta_df, pattern = "Education:", print_num = T)->df

##Pass it onto df for labeling jd
long_text_df(df)->df_long

# Clean data and generate algorithm to automate labeling
df_long %>% 
  mutate(is_education = case_when(str_detect(text,"Bachelors's|degree|diploma")~T,
                                  T~F)) %>% 
  group_by(dsm) %>% 
  mutate(ed_count = cumsum(is_education),
         max_ed_count = max(ed_count)) %>% 
  filter(max_ed_count==1)->new_df

new_df %>% filter(is_education==T) %>% view()

#create text lags
new_df %>% 
  mutate(entity_encode = str_sub(dsm, end = 2)) %>% 
  group_by(dsm) %>% 
  mutate(lag_text = lag(text, default = "first line"),
         lag_text2 = lag(lag_text, default = "second line"),
         lag_text3 = lag(lag_text2, default = "third line"))->edu_df

#Save data to csv to then train the model
# write_csv(edu_df,"../data/edut_df.csv")