import pandas as pd
import numpy as np 
import spacy
from spacy.lang.en.stop_words import STOP_WORDS
from preprocess import preprocess_text 
df=pd.read_csv("../../data/final_df/ps_final_df2.csv")
nlp = spacy.load('en_core_web_lg')

#Parse the text column using spacy
df['text_original'] = df['text']
df['text_parsed'] = df['text'].apply(nlp)
df['text_parsed'] = df['text_parsed'].apply(lambda doc: ' '.join([token.text for token in doc]))#unlist/unspacy

columns_to_preprocess = ['text', 'lag_text', 'lag_text2', 'lag_text3']

for column in columns_to_preprocess:
    df[column] = df[column].apply(lambda x:preprocess_text(x, nlp))
    
# Convert 'entity_encode' to object
df['entity_encode'] = df['entity_encode'].astype(str)

X = df[["text", 'str_len', "lag_text", 'lag_text2', 'lag_text3',  'entity_encode']]

from joblib import load

ps_preprocessor = load('preprocessors/ps_processor.joblib')

matrix_x = ps_preprocessor.transform(X)

# Load the saved model
ps_model = load('../../joblib/self_training_model_robust_ps.joblib')

predictions = ps_model.predict(matrix_x)
df['predictions'] = predictions

# Get the probabilities of the positive class
# probabilities = ps_model.predict_proba(matrix_x)[:, 1]
probabilities = ps_model.predict_proba(matrix_x)
for i, class_name in enumerate(ps_model.classes_):
    df[f'model1_probability_class_{class_name}'] = probabilities[:, i]
    
df.to_csv('../../data/final_df/ps_classified.csv', index=False)
    