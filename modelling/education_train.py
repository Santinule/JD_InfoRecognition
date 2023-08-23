import pandas as pd
import numpy as np
import spacy
from spacy.lang.en.stop_words import STOP_WORDS

nlp = spacy.load("en_core_web_lg")
df = pd.read_csv("../../data/jdCleanData/edut_df.csv")

# Define a function to preprocess text

def preprocess_text(text):
    # Create a Doc object
    doc = nlp(text, disable=['ner', 'parser'])
    # Generate lemmas
    lemmas = [token.lemma_ for token in doc]
    # Remove stopwords and non-alphabetic characters
    a_lemmas = [lemma for lemma in lemmas if lemma.isalpha() and lemma not in STOP_WORDS]
    
    return ' '.join(a_lemmas)
    
columns_to_preprocess = ['text', "lag_text",'lag_text2', 'lag_text3']

for column in columns_to_preprocess:
    df[column] = df[column].apply(preprocess_text)

from sklearn.feature_extraction.text import CountVectorizer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer


# Define preprocessor
preprocessor = ColumnTransformer(
    transformers=[
        ('text', CountVectorizer(), 'text'),
        ('lag_text', CountVectorizer(), 'lag_text'),
        ('lag_text2', CountVectorizer(), 'lag_text2'),
        ('lag_text3', CountVectorizer(), 'lag_text3'),
        ('num', StandardScaler(with_mean=False), ['str_len']),
        ('cat', OneHotEncoder(handle_unknown='ignore'), ['entity_encode'])
    ]
)



X = df[["text", 'str_len', "lag_text", 'lag_text2', 'lag_text3',  'entity_encode']]
y = df['is_education']

# Fit and transform the data
X = preprocessor.fit_transform(X)

from joblib import dump
dump(edu_preprocessor, 'edu_preporcesor.joblib')

from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.33, random_state=2)

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GridSearchCV

# Define the model
clf = RandomForestClassifier()

# Define hyperparameters to tune
param_grid = {
    'n_estimators': [50, 100, 150],
    'max_depth': [None, 10, 20, 30],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 2, 4],
    'bootstrap': [True, False]
}

# Setup GridSearch with Cross-Validation then fit
grid_search = GridSearchCV(estimator=clf, param_grid=param_grid, cv=5, n_jobs=-1, verbose=2)
grid_search.fit(X_train, y_train)

#Get the best parameters
best_params = grid_search.best_params_
# Creating a new instance with the best hyperparameters
best_rf_clf = RandomForestClassifier(**best_params)


# Evaluate on test data
# best_clf = grid_search.best_estimator_
# y_pred = best_clf.predict(X_test)
y_pred = model_for_eval.predict(X_test)


from sklearn.metrics import classification_report, accuracy_score, confusion_matrix
print("Accuracy:", accuracy_score(y_test, y_pred), "\n")
print(classification_report(y_test, y_pred), "\n")
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))


#After evaluation, fit to all the data
final_model =best_rf_clf.fit(X, y)

from joblib import dump

# Save the trained model
dump(final_model, '../../joblib/education_rfm.joblib')

