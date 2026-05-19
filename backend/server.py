from flask import Flask, request, jsonify, render_template
import sqlite3
import os
import json

app = Flask(__name__, template_folder='src', static_folder='src')

# Ensure the database directory exists
if not os.path.exists('database'):
    os.makedirs('database')

# Database setup
conn = sqlite3.connect('database/medimind.db', check_same_thread=False)
cursor = conn.cursor()

# Create table if it doesn't exist
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
        return jsonify({'success': True, 'id': cursor.lastrowid})

    except Exception as e:
        conn.rollback()
        print(f"Error saving medicine: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/medicines', methods=['GET'])
def get_medicines():
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

@app.route('/delete_medicine/<int:id>', methods=['DELETE'])
def delete_medicine(id):
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

if __name__ == '__main__':
    app.run(debug=True, port=8000)
