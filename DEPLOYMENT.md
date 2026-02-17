# Deployment Guide (Render.com)

This guide helps you deploy the Backend (Node.js + PostgreSQL) to Render.com for free.

## Prerequisites
1.  **GitHub Repository**: Ensure your code is pushed to GitHub.
2.  **Render Account**: Sign up at [dashboard.render.com](https://dashboard.render.com).

## Option 1: Manual Setup (Recommended for First Time)

### 1. Create Database
1.  Click **New +** -> **PostgreSQL**.
2.  Name: `campus-social-db`.
3.  Region: Choose closest to you (e.g., Ohio, Frankfurt).
4.  Plan: **Free**.
5.  Click **Create Database**.
6.  **Copy the "Internal Connection String"** (Available once created).

### 2. Create Web Service for Backend
1.  Click **New +** -> **Web Service**.
2.  Connect your GitHub repository.
3.  Name: `campus-social-api`.
4.  Region: Same as database.
5.  Branch: `main` (or your working branch).
6.  Root Directory: Leave empty (unless backend is in a subfolder).
7.  Runtime: **Node**.
8.  Build Command: `npm install`.
9.  Start Command: `node src/server.js`.
10. Plan: **Free**.

### 3. Configure Environment Variables
Scroll down to **Environment Variables** and add the following:

| Key | Value |
| :--- | :--- |
| `NODE_ENV` | `production` |
| `PORT` | `10000` (Render default) |
| `DATABASE_URL` | Paste the **Internal Connection String** from Step 1 |
| `JWT_SECRET` | Generate a strictly random string (e.g., use `openssl rand -hex 32`) |
| `SUPABASE_URL` | Your Supabase Project URL (from local .env) |
| `SUPABASE_KEY` | Your Supabase Anon Key (from local .env) |

### 4. Deploy
1.  Click **Create Web Service**.
2.  Wait for the build to finish.
3.  Once "Live", copy the URL (e.g., `https://campus-social-api.onrender.com`).

---

## Option 2: Infrastructure as Code (Blueprint)
1.  Push the `render.yaml` file to your repo.
2.  In Render Dashboard, go to **Blueprints**.
3.  Click **New Blueprint Instance**.
4.  Select your repo.
5.  Render will auto-detect the configuration.
6.  You will still need to manually input `JWT_SECRET`, `SUPABASE_URL`, and `SUPABASE_KEY` when prompted.

---

## Updating the Mobile App
Once deployed, update your Flutter App to point to the new URL:

1.  Open `lib/core/constants/api_constants.dart`.
2.  Update `apiBaseUrl`:
    ```dart
    static const String apiBaseUrl = 'https://your-app-name.onrender.com/api';
    ```
3.  Build the APK for your phone.
