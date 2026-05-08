import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier, export_text
from sklearn.metrics import accuracy_score
import pickle
import os

# Updated training script for AgroGuide AI
# Fixed column names for Fertilizer dataset

def train_crop_model():
    print("\n--- Training Crop Recommendation Model ---")
    path = 'datasets/crop/Crop_recommendation.csv'
    if not os.path.exists(path):
        print(f"Error: {path} not found.")
        return

    df = pd.read_csv(path)
    X = df[['N', 'P', 'K', 'temperature', 'humidity', 'ph', 'rainfall']]
    y = df['label']

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = DecisionTreeClassifier(max_depth=10, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    print(f"Crop Model Accuracy: {accuracy_score(y_test, y_pred):.4f}")
    
    tree_rules = export_text(model, feature_names=list(X.columns))
    with open('crop_tree_rules.txt', 'w') as f:
        f.write(tree_rules)
    
    with open('crop_model.pkl', 'wb') as f:
        pickle.dump(model, f)
    print("Crop model and rules exported.")

def train_fertilizer_model():
    print("\n--- Training Fertilizer Advisory Model ---")
    path = 'datasets/fertilizer/fertilizer_recommendation.csv'
    if not os.path.exists(path):
        print(f"Error: {path} not found.")
        return

    df = pd.read_csv(path)
    
    # Correct columns from previous run
    target = 'Recommended_Fertilizer'
    features_to_encode = ['Soil_Type', 'Crop_Type', 'Season']
    numeric_features = ['Soil_pH', 'Soil_Moisture', 'Nitrogen_Level', 'Phosphorus_Level', 'Potassium_Level', 'Temperature', 'Humidity', 'Rainfall']
    
    # Filter to relevant features
    df = df[features_to_encode + numeric_features + [target]]
    
    # Encode categorical variables
    df_encoded = pd.get_dummies(df, columns=features_to_encode)
    
    y = df[target]
    X = df_encoded.drop([target], axis=1)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = DecisionTreeClassifier(max_depth=10, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    print(f"Fertilizer Model Accuracy: {accuracy_score(y_test, y_pred):.4f}")
    
    tree_rules = export_text(model, feature_names=list(X.columns))
    with open('fertilizer_tree_rules.txt', 'w') as f:
        f.write(tree_rules)

    with open('fertilizer_model.pkl', 'wb') as f:
        pickle.dump(model, f)
    print("Fertilizer model and rules exported.")

if __name__ == "__main__":
    train_crop_model()
    train_fertilizer_model()
    print("\nTraining complete. Review .txt files for decision rules to implement in Dart.")
