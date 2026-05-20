# MediMind Backend Deployment Guide (PythonAnywhere)

This guide shows you how to host your Python Flask backend (`main.py` + Firestore integration) online 24/7 using **PythonAnywhere**'s completely free tier with **zero credit card required**!

---

## Step 1: Create a Free Account
1. Open your browser and go to: **[PythonAnywhere Signup](https://www.pythonanywhere.com/registration/register/lite/)**.
2. Fill in your details to create a free **"Beginner account"**.
3. **Choose your username carefully** (for example, `harisyaseen`). Your backend's public URL will be:
   `https://YOUR_USERNAME.pythonanywhere.com`

---

## Step 2: Import Your Code (Clone from GitHub)
1. Once logged in, click on the **"Consoles"** tab in the top right menu of your PythonAnywhere Dashboard.
2. Under *New console*, click on **"Bash"**. This will open an online command terminal.
3. Paste the following command into the terminal and press **Enter** to pull your codebase:
   ```bash
   git clone https://github.com/HarisYaseen/MediMind.git
   ```

---

## Step 3: Create the Web App
1. Click the **Menu** icon (three horizontal lines) in the top-right of your screen and select **"Web"**.
2. Click the blue **"Add a new web app"** button.
3. Click *Next*, then select **"Manual Configuration"** (do NOT click "Flask" directly; choosing "Manual Configuration" allows us to point the app to your custom folder structure).
4. Select **"Python 3.10"** (or Python 3.9) and click *Next* to finish.

---

## Step 4: Configure the Web App Settings
Once the web app is created, you will see a settings dashboard. Configure the following sections:

1. **Under the "Code" section:**
   * **Source code:** Set this to:
     `/home/YOUR_USERNAME/MediMind/backend`
   * **Working directory:** Set this to:
     `/home/YOUR_USERNAME/MediMind/backend`

2. **WSGI Configuration File (Crucial):**
   * Under the *Code* section, locate the link next to **"WSGI configuration file"** (looks like `/var/www/YOUR_USERNAME_pythonanywhere_com_wsgi.py`). 
   * Click on this link. It will open an online text editor.
   * **Delete all the text currently in that file**, paste the following block in its place, and click **Save** (top right):

```python
import sys
import os

# Point to your backend project folder
project_home = '/home/YOUR_USERNAME/MediMind/backend'
if project_home not in sys.path:
    sys.path = [project_home] + sys.path

# Set the working directory
os.chdir(project_home)

# Import the Flask app instance from main.py as "application"
from main import app as application
```

---

## Step 5: Install Dependencies & Go Live!
1. Go back to your active Bash Console (or go to *Consoles* and open a new *Bash* console).
2. Paste the following command to install the required Python packages into your account and press **Enter**:
   ```bash
   pip install --user flask firebase-admin flask-cors
   ```
3. Once the installations finish, go back to the **"Web"** tab in the top menu.
4. Click the big green **"Reload YOUR_USERNAME.pythonanywhere.com"** button at the top of the page.

---

## Step 6: Connect Your Mobile App!
Your backend is now live 24/7! 
1. Open `e:\Medi Mind\mobile_app\lib\providers\medicine_provider.dart`.
2. Change the `serverUrl` (around line 14) to your new PythonAnywhere URL:
   ```dart
   static String serverUrl = 'https://YOUR_USERNAME.pythonanywhere.com';
   ```
3. Re-run your mobile app using `flutter run` on your device, and you are 100% cloud-synced!
