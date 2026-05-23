from flask import Flask, request, jsonify, render_template
import sqlite3
import os
import json
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

app = Flask(__name__, template_folder='src', static_folder='src')

# Ensure the database directory exists using robust absolute paths
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
db_dir = os.path.join(BASE_DIR, 'database')
if not os.path.exists(db_dir):
    os.makedirs(db_dir)

# Database path setup
db_path = os.path.join(db_dir, 'medimind.db')

def get_db():
    conn = sqlite3.connect(db_path)
    return conn

# Create table thread-safely on startup
def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS medicines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medicineName TEXT NOT NULL,
            dosage TEXT NOT NULL,
            notes TEXT,
            times TEXT, -- Storing times as a JSON string
            sound TEXT -- The selected alert sound URL
        )
    ''')
    conn.commit()
    conn.close()

init_db()

@app.route('/')
def home():
    return render_template('welcome.html')

@app.route('/add-medicine')
def add_medicine_page():
    return render_template('add_medicine.html')

@app.route('/history')
def history_page():
    return render_template('history.html')

@app.route('/settings')
def settings_page():
    return render_template('settings.html')

@app.route('/save_medicine', methods=['POST'])
def save_medicine():
    conn = get_db()
    cursor = conn.cursor()
    try:
        data = request.get_json()
        medicine_name = data.get('medicineName')
        dosage = data.get('dosage')
        notes = data.get('notes')
        times = data.get('times')
        sound = data.get('sound')

        if not medicine_name or not dosage:
            return jsonify({'success': False, 'error': 'Missing required fields'}), 400

        times_json = json.dumps(times)

        cursor.execute(
            "INSERT INTO medicines (medicineName, dosage, notes, times, sound) VALUES (?, ?, ?, ?, ?)",
            (medicine_name, dosage, notes, times_json, sound)
        )
        conn.commit()
        last_id = cursor.lastrowid
        return jsonify({'success': True, 'id': last_id})

    except Exception as e:
        conn.rollback()
        print(f"Error saving medicine: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/medicines', methods=['GET'])
def get_medicines():
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT * FROM medicines ORDER BY id DESC")
        medicines = cursor.fetchall()
        medicines_list = []
        for med in medicines:
            times_list = []
            if med[4]:
                try:
                    times_list = json.loads(med[4])
                except json.JSONDecodeError:
                    times_list = [med[4]] 
            
            medicines_list.append({
                'id': med[0],
                'medicineName': med[1],
                'dosage': med[2],
                'notes': med[3],
                'times': times_list,
                'sound': med[5]
            })
        return jsonify(medicines_list)

    except Exception as e:
        print(f"Error fetching medicines: {e}")
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()

@app.route('/delete_medicine/<int:id>', methods=['DELETE'])
def delete_medicine(id):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM medicines WHERE id = ?", (id,))
        conn.commit()
        if cursor.rowcount > 0:
            return jsonify({'success': True})
        else:
            return jsonify({'success': False, 'error': 'Medicine not found'}), 404

    except Exception as e:
        conn.rollback()
        print(f"Error deleting medicine: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500
    finally:
        conn.close()

@app.route("/api_key", methods=['GET'])
def get_api_key():
    return jsonify({'apiKey': os.environ.get('GEMINI_API_KEY', '')})

@app.route("/lookup_medicine", methods=['POST'])
def lookup_medicine():
    try:
        data = request.json
        query = data.get("query")
        
        if not query:
            return jsonify({"error": "Query is required"}), 400
            
        model = genai.GenerativeModel('gemini-flash-latest')
        
        # Smart Hybrid Barcode Resolver
        resolved_name = data.get("resolved_name")
        is_barcode = query.strip().isdigit()
        
        if is_barcode and not resolved_name:
            import requests
            # Try Open FDA NDC database
            try:
                url = f"https://api.fda.gov/drug/ndc.json?search=package_ndc:\"{query.strip()}\"&limit=1"
                r = requests.get(url, timeout=5)
                if r.status_code == 200:
                    results = r.json().get('results', [])
                    if results:
                        resolved_name = results[0].get('brand_name') or results[0].get('generic_name')
                        if resolved_name:
                            print(f"FDA matched EAN {query} to product: {resolved_name}")
            except Exception as e:
                print(f"FDA lookup skipped: {e}")

            # Try RxNorm secondary
            if not resolved_name:
                try:
                    url = f"https://rxnav.nlm.nih.gov/REST/rxcui.json?idtype=NDC&id={query.strip()}"
                    r = requests.get(url, headers={'Accept': 'application/json'}, timeout=5)
                    if r.status_code == 200:
                        concept_properties = r.json().get('idGroup', {}).get('rxconceptProperties', [])
                        if concept_properties:
                            resolved_name = concept_properties[0].get('name')
                            if resolved_name:
                                print(f"RxNorm matched EAN {query} to concept: {resolved_name}")
                except Exception as e:
                    print(f"RxNorm lookup skipped: {e}")

            # final fallback to OpenFoodFacts EAN Database
            if not resolved_name:
                try:
                    url = f"https://world.openfoodfacts.org/api/v0/product/{query.strip()}.json"
                    headers = {'User-Agent': 'MediMind - MobileApp - Version 1.0'}
                    r = requests.get(url, headers=headers, timeout=5)
                    if r.status_code == 200:
                        prod_data = r.json()
                        resolved_name = prod_data.get('product', {}).get('product_name')
                        if resolved_name:
                            print(f"OpenFoodFacts matched EAN {query} to product: {resolved_name}")
                except Exception as e:
                    print(f"OpenFoodFacts lookup skipped: {e}")
        
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
        
        # Check if the key is a Groq key (starts with gsk_)
        is_groq = GEMINI_API_KEY.startswith('gsk_') if GEMINI_API_KEY else False
        
        if is_groq:
            import requests
            headers = {
                "Authorization": f"Bearer {GEMINI_API_KEY}",
                "Content-Type": "application/json"
            }
            payload = {
                "model": "llama-3.3-70b-versatile",
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "response_format": {"type": "json_object"}
            }
            try:
                r = requests.post("https://api.groq.com/openai/v1/chat/completions", json=payload, headers=headers, timeout=10)
                if r.status_code == 200:
                    res_data = r.json()
                    content = res_data['choices'][0]['message']['content'].strip()
                    parsed_json = json.loads(content)
                    return jsonify(parsed_json)
                else:
                    # Fallback to smaller fast model if larger one is busy
                    payload["model"] = "llama3-8b-8192"
                    r2 = requests.post("https://api.groq.com/openai/v1/chat/completions", json=payload, headers=headers, timeout=10)
                    if r2.status_code == 200:
                        res_data = r2.json()
                        content = r2.json()['choices'][0]['message']['content'].strip()
                        parsed_json = json.loads(content)
                        return jsonify(parsed_json)
                    else:
                        raise Exception(f"Groq API returned error: {r2.status_code} - {r2.text}")
            except Exception as ex:
                print(f"Groq lookup failed: {ex}")
                return jsonify({"error": f"Groq Error: {str(ex)}"}), 500
        
        # Standard Gemini Flow
        model = genai.GenerativeModel('gemini-flash-latest')
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
    app.run(debug=True, port=8000)
