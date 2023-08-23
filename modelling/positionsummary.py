import pandas as pd
import numpy as np
import spacy
from spacy.lang.en.stop_words import STOP_WORDS
from preprocess import preprocess_text

df = pd.read_csv("../../data/jdCleanData/pst2_df.csv")
# Load a SpaCy model
nlp = spacy.load('en_core_web_lg')

# Apply the function to the 'previous_line' column
columns_to_preprocess = ['text', 'lag_text','lag_text2', 'lead_text', 'lead_text2']

for column in columns_to_preprocess:
    df[column] = df[column].apply(lambda x:preprocess_text(x, nlp))
    
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer


# Define preprocessor
preprocessor_ps2 = ColumnTransformer(
    transformers=[
        ('text', CountVectorizer(), 'text'),
        ('lag_text', CountVectorizer(), 'lag_text'),
        ('lag_text2', CountVectorizer(), 'lag_text2'),
        ('lead_text', CountVectorizer(), 'lead_text'),
        ('lead_text2', CountVectorizer(), 'lead_text2'),
        ('num', StandardScaler(with_mean=False), ['str_len']),
        ('cat', OneHotEncoder(handle_unknown='ignore'), ['entity_encode'])
    ]
)

X = df[["text", 'previous_column_number', 'str_len',
        "lag_text", 'lag_text2',
        'lead_text','lead_text2',
        'entity_encode']]

y = df['is_ps']

# Fit and transform the data
X = preprocessor_ps2.fit_transform(X)
from joblib import dump
dump(preprocessor_ps2, 'preprocessors/ps_processor.joblib')

from sklearn.model_selection import train_test_split
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=20)

from sklearn.ensemble import RandomForestClassifier
from sklearn.semi_supervised import SelfTrainingClassifier
from sklearn.model_selection import GridSearchCV

# Defining base classifier
base_classifier = RandomForestClassifier()

# Wrap it with SelfTrainingClassifier
self_training_clf = SelfTrainingClassifier(base_classifier)

# Parameters for GridSearch. Notice the prefix to each parameter which corresponds to the base_classifier.
param_grid = {
    'base_estimator__n_estimators': [50, 100, 150],
    'base_estimator__max_depth': [None, 5, 10, 12],
    'base_estimator__min_samples_split': [2, 5, 10],
    'base_estimator__min_samples_leaf': [1, 2, 4],
    'base_estimator__bootstrap': [True, False]
}

# Setting up GridSearch with Cross-Validation
grid_search = GridSearchCV(estimator=self_training_clf, param_grid=param_grid, cv=5, n_jobs=-1, verbose=2)
grid_search.fit(X_train, y_train)

best_params = grid_search.best_params_

# Training the model with the best hyperparameters
from sklearn.ensemble import RandomForestClassifier
from sklearn.semi_supervised import SelfTrainingClassifier
model_for_eval = SelfTrainingClassifier(
    RandomForestClassifier(
        n_estimators=150,
        max_depth=None,
        min_samples_split=2,
        min_samples_leaf=1,
        bootstrap=False
    )
)

# model_for_eval.fit(X_train, y_train)

# Predicting with the model
y_pred = model_for_eval.predict(X_test)


from sklearn.metrics import classification_report, accuracy_score, confusion_matrix
print("Accuracy:", accuracy_score(y_test, y_pred), "\n")
print(classification_report(y_test, y_pred), "\n")
print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

#Use all data to train model
# Training the model with the best hyperparameters

best_model_ps2 = model_for_eval.fit(X, y)

from joblib import dump

# Save the model using joblib
dump(best_model_ps2, '../../joblib/best_model_ps2.joblib')