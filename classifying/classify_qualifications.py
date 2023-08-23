import pandas as pd
import numpy as np 
import spacy
from spacy.lang.en.stop_words import STOP_WORDS
from preprocess import preprocess_text 
nlp = spacy.load('en_core_web_lg')
df=pd.read_csv("../../data/final_df/quali_final_df2.csv")

df["text_original"] = df["text"]
df["text"] = df["text"].apply(lambda x:preprocess_text(x, nlp))
df["text2"] = df["text"].apply(lambda x:preprocess_text(x, nlp))

from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import CountVectorizer
from joblib import load
preprocessor = load( 'preprocessors/quali_processor2.joblib')
X = df[["text", "text2", 'str_len', 'entity_encode']]
X_processed = preprocessor.transform(X)

quali_model = load('../../joblib/best_model_quali.joblib')
predictions = quali_model.predict(X_processed)
df['predictions_model2'] = predictions

probabilities = quali_model.predict_proba(X_processed)
for i, class_name in enumerate(quali_model.classes_):
    df[f'quali_model_probability_class_{class_name}'] = probabilities[:, i]
    
# df.to_csv('../../data/final_df/quali_classified2.csv', index=False)