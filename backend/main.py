import os
from flask import Flask, send_file, jsonify, request
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore

# --- Firebase Initialization ---
# This prevents the app from crashing during hot-reloading.
if not firebase_admin._apps:
    try:
        cred = credentials.Certificate("firebase_credentials.json")
        firebase_admin.initialize_app(cred)
    except FileNotFoundError:
        print("Firebase credentials file not found. Please add firebase_credentials.json to the root directory.")
        # In a real app, you might handle this more gracefully.
    except Exception as e:
        print(f"An error occurred during Firebase initialization: {e}")

db = firestore.client() if firebase_admin._apps else None

# --- Flask App Initialization ---
app = Flask(__name__)
CORS(app)

# --- Routes ---
@app.route("/")
def index():
    return send_file('src/welcome.html')

@app.route("/history")
def history():
    return send_file('src/history.html')

@app.route("/add-medicine")
def add_medicine_page():
    return send_file('src/add_medicine.html')

@app.route("/medicines")
def get_medicines():
    if not db:
        return jsonify({"error": "Firestore is not initialized. Check server logs."}), 500
    try:
        medicines_ref = db.collection('medicines').stream()
        medicines = []
        for med in medicines_ref:
            medicine_data = med.to_dict()
            medicine_data['id'] = med.id
            medicines.append(medicine_data)
        return jsonify(medicines)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/save_medicine", methods=['POST'])
def save_medicine():
    if not db:
        return jsonify({"error": "Firestore is not initialized.", "success": False}), 500
    try:
        data = request.json
        # Add a new doc in collection 'medicines' with an auto-generated ID
        _, doc_ref = db.collection('medicines').add(data)
        return jsonify({"success": True, "id": doc_ref.id})
    except Exception as e:
        return jsonify({"error": str(e), "success": False}), 500

@app.route("/delete_medicine/<medicine_id>", methods=['DELETE'])
def delete_medicine(medicine_id):
    if not db:
        return jsonify({"error": "Firestore is not initialized. Check server logs."}), 500
    try:
        db.collection('medicines').document(medicine_id).delete()
        return jsonify({"success": True, "message": "Medicine deleted"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/settings")
def settings():
    return send_file('src/settings.html')

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=8000)
