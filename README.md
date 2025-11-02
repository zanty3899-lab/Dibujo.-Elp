# Suite de Bots (Tutor, Coach de hábitos, Gestor de hábitos)

Proyecto full-stack en español con FastAPI + SQLite (backend) y Vite + React (frontend).

## Requisitos

- Python 3.11+
- Node.js 18+
- PowerShell 5+ (Windows)

## Estructura

```
backend/
  app/
    main.py
    database.py
    models.py
    schemas.py
  requirements.txt
frontend/
  index.html
  package.json
  vite.config.js
  src/
    App.jsx
    Coach.jsx
    Tutor.jsx
    Habits.jsx
    ChatPanel.jsx
    api.js
    main.jsx
    styles.css
setup.ps1
```

## Backend

- Framework: FastAPI
- Base de datos: SQLite (`sqlite:///./dev.db`)
- Endpoints principales:
  - `GET /health`
  - `GET /bots`
  - `GET /bots/{bot_id}`
  - `GET /bots/{bot_id}/conversation`
  - `POST /bots/{bot_id}/message`
  - `DELETE /bots/{bot_id}/conversation`

## Frontend

- Vite + React con tabs para tres vistas: Tutor, Coach de hábitos y Gestor de hábitos.
- Consumo de API mediante `axios` con proxy `/api → http://localhost:8000`.

## Puesta en marcha rápida (Windows)

Ejecuta el script automatizado:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

El script creará/actualizará los archivos del proyecto, instalará dependencias, generará un entorno virtual y levantará backend (puerto 8000) y frontend (puerto 5173) en ventanas separadas. Usa `Ctrl+C` en cada ventana para detenerlos.

Para instalar sin iniciar servicios:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -InstallOnly
```

## Puesta en marcha manual (opcional)

### Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # En Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Abre `http://localhost:5173` en tu navegador. El proxy redirige las peticiones `/api` al backend.

## Pruebas básicas

Verifica el backend:

```bash
curl http://localhost:8000/health
```

Desde el frontend, envía un mensaje a cualquiera de los bots para ver la respuesta generada y su registro en la base de datos.
