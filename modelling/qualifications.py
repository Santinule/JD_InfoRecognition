import numpy as np
import pandas as pd 
import spacy
from preprocess import preprocess_text
from spacy.lang.en.stop_words import STOP_WORDS

# Load a SpaCy model
nlp = spacy.load('en_core_web_lg')

df = pd.read_csv("../../data/jdCleanData/isq_train_final.csv")
df['is_qualification'] = df['is_qualification'].replace([1, 2], 5)
df["text"] = df["text"].apply(lambda x:preprocess_text(x, nlp))
df["text2"] = df["text"].apply(lambda x:preprocess_text(x, nlp))

from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import CountVectorizer, TfidfTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.compose import ColumnTransformer
from joblib import dump

count_vectorizer = CountVectorizer()
tfidf_transformer = TfidfTransformer()

# Pipeline for CountVectorizer
count_vect_pipeline = Pipeline([
    ('countvectorizer', count_vectorizer)
])

# Pipeline for TFIDF
tfidf_pipeline = Pipeline([
    ('countvectorizer', count_vectorizer),
    ('tfidf', tfidf_transformer)
])

preprocessor = ColumnTransformer(
    transformers=[
        ('countvectorizer', count_vect_pipeline, 'text'),
        ('tfidf', tfidf_pipeline, 'text2'),
        ('cat', OneHotEncoder(handle_unknown='ignore'), ['entity_encode'])
    ],
    remainder='passthrough'  # The 'str_len' column will be passed through without transformation
)

X = df[["text", "text2", 'str_len', 'entity_encode']]
y = df['is_qualification']

# Fit the preprocessor on your training data and then transform it
X_processed = preprocessor.fit_transform(X)

# Now, dump the fitted preprocessor
dump(preprocessor, 'preprocessors/quali_processor2.joblib')

from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X_processed, y, test_size=0.3, random_state=10)

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GridSearchCV
from sklearn.semi_supervised import SelfTrainingClassifier

# Given class weights
class_weight = {0: 1, 3: 5, 4:5, 5:2}

base_classifier = RandomForestClassifier(class_weight=class_weight, random_state=42)

self_training_model = SelfTrainingClassifier(base_classifier, criterion='k_best', k_best=10, max_iter=10)

# Hyperparameter tuning using grid search with cross-validation


param_grid = {
    'base_estimator__n_estimators': [50, 100, 200],
    'base_estimator__max_depth': [200, 300, None],
    'base_estimator__min_samples_split': [2, 5, 10],
    'base_estimator__min_samples_leaf': [1, 2, 4]
}


grid_search = GridSearchCV(self_training_model, param_grid, cv=5, n_jobs=-1)
grid_search.fit(X_train, y_train)

best_params = grid_search.best_params_


# Training the model with the best hyperparameters
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GridSearchCV
from sklearn.semi_supervised import SelfTrainingClassifier
eval_base_classifier =RandomForestClassifier(
        n_estimators=50,
        max_depth=300,
        min_samples_split=2,
        min_samples_leaf=1
    )
model_for_eval = SelfTrainingClassifier(eval_base_classifier, criterion='k_best', k_best=10, max_iter=10
    
)

# Predicting with the model

y_pred = model_for_eval.predict(X_test)


from sklearn.metrics import classification_report, accuracy_score, confusion_matrix
print("Accuracy:", accuracy_score(y_test, y_pred), "\n")
print(classification_report(y_test, y_pred), "\n")
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

#Use all data to train model
best_model_quali = model_for_eval.fit(X_processed, y)

from joblib import dump
# Save the model using joblib
dump(best_model_quali, '../../joblib/best_model_quali.joblib')