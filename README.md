# JD_InfoRecognition

Involves joining data from various sources. Most complex source was gathering data from over 1,000 job descriptions onto Structured Format. The complexity arose due to inconsistencies in semantical dependencies during parsing given the variation in the kinds of Job Descriptions (JD).

The data extraction from the JD'S involves machine learning component, where preecedingly, I dicerned patterns in data and thus generated algorithms to either supervise or semi-supervise a subset of the JD's.

Then used that data to generate various predctive models to ultimately classify the data. Ultimately importing the probabilities from the model and doing a second round of filtering. Then, checked the accuracy of the predictions manually and acheiving in two of three attributes an estimated proportion of 0.95 success, with a CI of (0.88-0.99), at the 95% Confidence level.

I am not including any data nor the pretrained models for they have metadata that does not belong to me but rather Johns Hopkins Health System (JHHS).

The pupose was to propell the launch of JDExpert, a Job Description software that JHHS is adopting.
