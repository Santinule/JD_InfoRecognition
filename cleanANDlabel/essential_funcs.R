library(tidyverse)
library(officer)

# Define functions
func1<-function(file){
  return(tryCatch(read_docx(file), error=function(e) NULL))
}


func2<-function(file2){
  return(tryCatch(docx_summary(file2), error=function(e) NULL))
}

func3 <- function(num, files_vec){
  return(func2(func1(files_vec[num])))
  
}

get_dsm <- function(input_string) {
  # Using regular expression to find eight consecutive digits
  matches <- regmatches(input_string, gregexpr("\\d{6}|\\d{8}", input_string))
  
  # Check if there is a match
  if (length(matches[[1]]) > 0) {
    return(matches[[1]][1])
  } else {
    return("No match found")
  }
}

vectorized_get_dsm<- Vectorize(get_dsm)





###GET text

get_text <- function(df=df,pattern= "pattern", name ="title", nv =c(0,30,300), print_num = T, view=F, files_vec){
  files_vec <- df[["files"]]
  vector_notFound <- vector(mode = "list", length=150)
  k <- 1
  for(i in 1:length(files_vec)){
    if(print_num){
      print(i)
    }
    func3(i, files_vec)$text->text
    # Remove NA and whitespace from text
    text <- na.omit(text) # remove NA values
    text <- trimws(text) # remove leading and trailing white spaces
    text <- text[nzchar(text)] # remove empty string
    
    #Individual doc operations
    #Position Summary
    found <- F
    for(line_num in 1:nv[3]){
      text[line_num]->current_line
      if(grepl(pattern = pattern, ignore.case = T,x= current_line)){
        df[[paste0(name,"_line_index")]][i] <-line_num
        for(j in nv[1]:nv[2]){
          df[[paste0(name, "_next", j, "_literal")]][i] <- text[line_num + j]
        }
        found <- T
        break
      }
    }
    if(!found){
      for(j in nv[1]:nv[2]){
        df[[paste0(name,"_next", j, "_literal")]][i] <- "not found"
      }
      vector_notFound[k] <- i
      k <- k+1
    }
    
  }
  if(view){
    df %>% view()
  }
  return(df)
  
}

get_text2 <- function(df,pattern= "pattern", name ="title", nv =c(0,30,300), print_num = T, view=F, files_vec ){
  files_vec <- df[["files"]]
  vector_notFound <- vector(mode = "list", length=length(files_vec))
  k <- 1
  for(i in 1:length(files_vec)){
    if(print_num){
      print(i)
    }
    func3(num= i, files_vec)$text->text
    # Remove NA and whitespace from text
    text <- na.omit(text) # remove NA values
    text <- trimws(text) # remove leading and trailing white spaces
    text <- text[nzchar(text)] # remove empty string
    
    #Individual doc operations
    #Position Summary
    found <- F
    for(line_num in 1:nv[3]){
      text[line_num]->current_line
      if(grepl(pattern = pattern, ignore.case = T,x= current_line)){
        df[[paste0(name,"_line_index")]][i] <-line_num
        for(j in nv[1]:nv[2]){
          df[[paste0(name, "_next", j, "_literal")]][i] <- text[line_num + j]
        }
        found <- T
        break
      }
    }
    if(!found){
      df[[paste0(name,"_line_index")]][i] <-"not found"
      for(j in nv[1]:nv[2]){
        df[[paste0(name,"_next", j, "_literal")]][i] <- text[j+1]
      }
      vector_notFound[k] <- i
      k <- k+1
    }
    
  }
  if(view){
    df %>% view()
  }
  return(df)
  return(files_vec)
  
}


# Long text df

long_text_df <- function(get_text_df){
  get_text_df %>% 
    select(c("dsm", names(get_text_df)[4:ncol(get_text_df)])) ->df
  
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
  
  data.frame(dsm = dsm_list,
             text = text_list,
             previous_column_number = previous_column_number_list) %>% 
    mutate(str_len = str_length(text)) %>% 
    filter(str_len>3) %>% 
    filter(text !="not found")->new_df
  
  return(new_df)
  
}

