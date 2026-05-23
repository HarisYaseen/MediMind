import os
import json
from flask import Flask, send_file, jsonify, request
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
import google.generativeai as genai

# --- Load Environment Variables ---
load_dotenv(override=True)

# --- Gemini Configuration ---
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
else:
    print("Warning: GEMINI_API_KEY environment variable is not set. AI features may fail.")

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

@app.route("/lookup_medicine", methods=['POST'])
def lookup_medicine():
    try:
        data = request.json
        query = data.get("query")
        
        if not query:
            return jsonify({"error": "Query is required"}), 400
            
        model = genai.GenerativeModel('gemini-flash-latest')
        
        # Smart Hybrid Barcode Resolver
        resolved_name = None
        is_barcode = query.strip().isdigit()
        
        if is_barcode:
            try:
                import requests
                url = f"https://world.openfoodfacts.org/api/v0/product/{query.strip()}.json"
                headers = {'User-Agent': 'MediMind - MobileApp - Version 1.0'}
                r = requests.get(url, headers=headers, timeout=5)
                if r.status_code == 200:
                    prod_data = r.json()
                    resolved_name = prod_data.get('product', {}).get('product_name')
                    if resolved_name:
                        print(f"Hybrid Resolver matched EAN {query} to product: {resolved_name}")
            except Exception as e:
                print(f"EAN Database lookup skipped: {e}")
        
        # Build prompt dynamically based on lookup result
        if resolved_name:
            search_subject = f"barcode number {query} which maps to the medicine '{resolved_name}'"
        else:
            search_subject = f"query/barcode value '{query}'"
            
        prompt = f"""
        You are a clinical pharmacy expert and professional medical AI assistant.
        A user has scanned or searched for a medication with the search subject: {search_subject}.
        
        Please search or check your clinical database to identify this exact medication:
        1. If this is a barcode, identify the exact brand name medicine associated with it. If the EAN database mapped it to a product name ('{resolved_name}'), prioritize that exact medicine name and fetch clinical instructions for it.
        2. If this is a text search, identify the exact medicine name.
        3. CRITICAL: If you cannot find the barcode in your database, and there was no mapped name, you MUST return the JSON with "name" set to "Unknown Medicine (Barcode: {query})" and "notes" set to "This barcode is not globally indexed yet. Please edit the name and add your dosage details manually." Do NOT leave the name field empty for unindexed barcode numbers. If the query is completely random junk letters, set the name to an empty string "".
        
        Provide the details in strict JSON format containing these fields:
        - "name": The official, brand, or generic name of the medicine (e.g. "Panadol", "Infacol").
        - "dosage": Standard recommended patient dosage instructions.
        - "notes": Important patient guidelines, what the drug is used for, safety warnings, and potential side effects.
        - "barcode": The exact barcode number "{query if is_barcode else ''}" (if this was a barcode scan), or empty string if input was a textual name.
        
        Return ONLY raw, valid JSON. Do not write any markdown code block fences (do not wrap in ```json), introductory text, or explanations.
        """
        
        response = model.generate_content(
            prompt,
            generation_config={"response_mime_type": "application/json"}
        )
        text = response.text.strip()
        parsed_json = json.loads(text)
        return jsonify(parsed_json)
    except Exception as e:
        print(f"Error during AI medicine lookup: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=8000)
