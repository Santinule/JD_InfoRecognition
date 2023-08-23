import pandas as pd
import numpy as np
import spacy
from spacy.lang.en.stop_words import STOP_WORDS
df=pd.read_csv("../../data/final_df/edu_final_df.csv")
nlp = spacy.load('en_core_web_lg')

# Define a function to preprocess text

def preprocess_text(text):
    # Create a Doc object
    doc = nlp(text, disable=['ner', 'parser'])
    # Generate lemmas
    lemmas = [token.lemma_ for token in doc]
    # Remove stopwords and non-alphabetic characters
    a_lemmas = [lemma for lemma in lemmas if lemma.isalpha() and lemma not in STOP_WORDS]
    
    return ' '.join(a_lemmas)

df['text_original'] = df['text']
# Parse the text column using spacy
df['text_parsed'] = df['text'].apply(nlp)
df['text_parsed'] = df['text_parsed'].apply(lambda doc: ' '.join([token.text for token in doc]))#unlist/unspacy


columns_to_preprocess = ['text', "lag_text",'lag_text2', 'lag_text3']

for column in columns_to_preprocess:
    df[column] = df[column].apply(preprocess_text)
    
# Convert 'str_len' to int64
df['str_len'] = df['str_len'].astype(int)
# Convert 'entity_encode' to object
df['entity_encode'] = df['entity_encode'].astype(str)


X = df[["text", 'str_len', "lag_text", 'lag_text2', 'lag_text3',  'entity_encode']]

from joblib import load
preprocessor = load('path_to_save_preprocessor.joblib')

matrix_x =preprocessor.transform(X)

from joblib import load
# Load the saved model
edu_model = load('../../joblib/education_rfm.joblib')

predictions = edu_model.predict(matrix_x)
df['predictions'] = predictions

# Get the probabilities of the positive class
probabilities = edu_model.predict_proba(matrix_x)[:, 1]
probabilities = edu_model.predict_proba(matrix_x)
for i, class_name in enumerate(edu_model.classes_):
    df[f'probability_class_{class_name}'] = probabilities[:, i]

# df.to_csv('../../data/final_df/edu_classified.csv', index=False)