# MediMind Backend Deployment Guide (Render)

This guide shows you how to host your Python Flask backend (`main.py` + Firestore integration) online 24/7 using the **Render** free tier. Once deployed, the server is always active, allowing your Flutter mobile application to work perfectly from anywhere in the world!

---

## What We Have Already Prepared for You
1. **Dynamic Port Binding (`backend/main.py`):** Configured the server to dynamically read the environment `PORT` variable assigned by Render.
2. **Production-Ready Server (`backend/requirements.txt`):** Added `gunicorn` to dependencies.
3. **App Runner Config (`backend/Procfile`):** Created a `Procfile` instructing Render to start the app using `gunicorn main:app`.
4. **Cloud-Ready Flutter app (`mobile_app/.../medicine_provider.dart`):** Upgraded `_baseUrl` to support full cloud URLs seamlessly.

---

## Step 1: Create a GitHub Repository & Push Your Code

Since Render connects directly to GitHub, you need to push your workspace code to a new repository first.

1. Go to [GitHub](https://github.com/) and log in.
2. Click **New Repository**.
3. Name it `MediMind` (or any name you prefer), keep it **Public** (or Private), and click **Create repository**.
4. In your terminal at `E:\Medi Mind`, run the following commands to initialize Git and push the project:

```powershell
# 1. Initialize git (if not already done)
git init

# 2. Add all files to staging
git add .

# 3. Create initial commit
git commit -m "Prepare backend and frontend for cloud deployment"

# 4. Set default branch to main
git branch -M main

# 5. Link to your new GitHub repository
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git

# 6. Push code to GitHub
git push -u origin main
```

---

## Step 2: Deploy to Render (Free Web Service)

1. Go to [Render](https://render.com/) and sign up or log in.
2. Click the blue **New +** button in the top right and select **Web Service**.
3. Choose **Connect a repository** and select your newly created GitHub repository.
4. Fill in the deployment details exactly as follows:
   * **Name:** `medimind-backend` (or any name)
   * **Region:** Choose the one closest to you (e.g., *Singapore* or *Oregon*)
   * **Branch:** `main`
   * **Root Directory:** `backend` *(This is CRITICAL! It tells Render to build inside the backend folder since your project is structured with frontend and backend subfolders).*
   * **Runtime:** `Python`
   * **Build Command:** `pip install -r requirements.txt`
   * **Start Command:** `gunicorn main:app`
   * **Instance Type:** `Free`
5. Click **Deploy Web Service** at the bottom of the page!

Render will now pull the code, install dependencies, and host the server. Within 2-3 minutes, you will see a green status saying **"Live"**, and your server's public URL will be visible in the top-left (e.g. `https://medimind-backend.onrender.com`).

---

## Step 3: Connect Your Mobile App to the Cloud Server

1. Open `e:\Medi Mind\mobile_app\lib\providers\medicine_provider.dart` in VS Code.
2. Change the `serverUrl` string (around line 14) from your local IP to your new Render public URL:

```dart
// REPLACE:
static String serverUrl = '192.168.100.4';

// WITH YOUR RENDER URL:
static String serverUrl = 'https://medimind-backend.onrender.com';
```

3. Save the file.
4. Re-run your mobile app using `flutter run`.

**Your app is now 100% connected to a global production cloud server! You can shut down your computer, and the medication reminders and schedules on your mobile phone will continue to fetch, sync, and alert you completely uninterrupted!**
