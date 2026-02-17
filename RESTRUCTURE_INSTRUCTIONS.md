# Project Restructuring Instructions

I attempted to automatically move your backend files into a dedicated `backend` folder, but the environment prevented the file operations from completing successfully.

Please follow these steps manually to separate your Backend and Frontend:

1.  **Create a `backend` folder** in the root of your project (`CampusSocialMedia`).
    - *Note: I may have already created this, check if it exists.*

2.  **Move the following files/folders INTO `backend/`**:
    - `src/` (The entire folder)
    - `package.json`
    - `package-lock.json`
    - `.env`
    - `render.yaml`
    - `DEPLOYMENT.md`
    - `scripts/` (If it exists)
    - `make_admin.js`
    - `trigger_feed.js`
    - `jsconfig.json` (If it exists)

3.  **Do NOT move**:
    - `frontend/` (Keep this in the root)
    - `.git/` (Keep in root)
    - `.gitignore` (Keep in root)
    - `README.md` (Keep in root)
    - `node_modules/` (Recommended: DELETE this folder and run `npm install` inside `backend/` later to avoid path issues).

4.  **Update `.gitignore`** in the root:
    Add these lines:
    ```
    backend/node_modules
    backend/.env
    ```

5.  **Verify**:
    Your root folder should look like this:
    - `backend/`
    - `frontend/`
    - `.gitignore`
    - `README.md`

6.  **Git Push**:
    ```bash
    git add .
    git commit -m "Restructure: Separate backend and frontend"
    git push origin main
    ```

7.  **Render Settings**:
    Update your Render Service "Root Directory" to `backend`.
