param(
    [switch]$InstallOnly
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Write-ProjectFile {
    param([string]$RelativePath, [string]$Content)
    $fullPath = Join-Path $Root $RelativePath
    $directory = Split-Path -Parent $fullPath
    if ($directory) { Ensure-Directory -Path $directory }
    $Content | Set-Content -Path $fullPath -Encoding UTF8
}

Ensure-Directory (Join-Path $Root "backend/app")
Ensure-Directory (Join-Path $Root "frontend/src")

Write-ProjectFile "backend/app/__init__.py" ""

Write-ProjectFile "backend/app/database.py" @'
from contextlib import contextmanager
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DATABASE_URL = "sqlite:///./dev.db"

_db_path = Path(DATABASE_URL.replace("sqlite:///", "")).resolve()
_db_path.parent.mkdir(parents=True, exist_ok=True)

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}, future=True, echo=False
)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


@contextmanager
def get_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()
'@

Write-ProjectFile "backend/app/models.py" @'
from datetime import datetime
from enum import Enum

from sqlalchemy import DateTime, Enum as SqlEnum, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class SenderEnum(str, Enum):
    USER = "user"
    BOT = "bot"


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    bot_id: Mapped[str] = mapped_column(String(50), index=True)
    sender: Mapped[SenderEnum] = mapped_column(SqlEnum(SenderEnum))
    content: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, index=True
    )
'@

Write-ProjectFile "backend/app/schemas.py" @'
from datetime import datetime
from typing import List

from pydantic import BaseModel, Field


class BotInfo(BaseModel):
    id: str
    nombre: str
    descripcion: str


class MessageCreate(BaseModel):
    mensaje: str = Field(..., min_length=1, max_length=1000)


class MessageRead(BaseModel):
    id: int
    bot_id: str
    remitente: str
    contenido: str
    creado_en: datetime

    class Config:
        orm_mode = True


class ConversationResponse(BaseModel):
    bot: BotInfo
    historial: List[MessageRead]
'@

Write-ProjectFile "backend/app/main.py" @'
from __future__ import annotations

from datetime import datetime
from typing import Dict, List

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from .database import engine, get_session
from .models import Base, Message, SenderEnum
from .schemas import BotInfo, ConversationResponse, MessageCreate, MessageRead

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Suite de Bots", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class BotPersona:
    def __init__(self, nombre: str, descripcion: str, tono: str, rutinas: List[str] | None = None):
        self.nombre = nombre
        self.descripcion = descripcion
        self.tono = tono
        self.rutinas = rutinas or []

    def responder(self, mensaje: str) -> str:
        mensaje = mensaje.strip()
        if not mensaje:
            return "¿Puedes contarme un poco más?"

        saludo = f"Hola, soy {self.nombre}."
        if "hola" in mensaje.lower():
            saludo = f"¡Hola! Soy {self.nombre}!"

        cuerpo = ""
        if self.rutinas:
            cuerpo = " Aquí tienes una sugerencia rápida: " + ", ".join(self.rutinas[:2]) + "."

        cierre = " ¿Te gustaría profundizar en algo más?"
        return f"{saludo} {self.tono} {cuerpo} {cierre}".strip()


BOTS: Dict[str, BotPersona] = {
    "tutor": BotPersona(
        nombre="Tutor",
        descripcion="Apoyo académico con explicaciones claras y ejemplos prácticos.",
        tono="Estoy listo para ayudarte a comprender cualquier tema paso a paso.",
    ),
    "coach": BotPersona(
        nombre="Coach de hábitos",
        descripcion="Te guía para construir hábitos saludables y sostenibles.",
        tono="Vamos a definir acciones concretas y motivadoras para tu día.",
        rutinas=["Respira profundo 3 veces", "Define una meta pequeña", "Celebra tu progreso"],
    ),
    "habits": BotPersona(
        nombre="Gestor de hábitos",
        descripcion="Registra y analiza tus hábitos cotidianos para que los mantengas.",
        tono="Revisemos tu registro y encontremos patrones útiles.",
        rutinas=["Anota tus logros", "Identifica un obstáculo", "Planea una recompensa"],
    ),
}


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


@app.get("/bots", response_model=List[BotInfo])
def list_bots() -> List[BotInfo]:
    return [
        BotInfo(id=bot_id, nombre=persona.nombre, descripcion=persona.descripcion)
        for bot_id, persona in BOTS.items()
    ]


@app.get("/bots/{bot_id}", response_model=BotInfo)
def get_bot(bot_id: str) -> BotInfo:
    persona = BOTS.get(bot_id)
    if not persona:
        raise HTTPException(status_code=404, detail="Bot no encontrado")
    return BotInfo(id=bot_id, nombre=persona.nombre, descripcion=persona.descripcion)


@app.get("/bots/{bot_id}/conversation", response_model=ConversationResponse)
def get_conversation(bot_id: str, session: Session = Depends(get_session)) -> ConversationResponse:
    persona = BOTS.get(bot_id)
    if not persona:
        raise HTTPException(status_code=404, detail="Bot no encontrado")

    result = session.execute(
        select(Message).where(Message.bot_id == bot_id).order_by(Message.created_at.asc())
    )
    mensajes = [
        MessageRead(
            id=msg.id,
            bot_id=msg.bot_id,
            remitente=msg.sender.value,
            contenido=msg.content,
            creado_en=msg.created_at,
        )
        for msg in result.scalars().all()
    ]
    return ConversationResponse(
        bot=BotInfo(id=bot_id, nombre=persona.nombre, descripcion=persona.descripcion),
        historial=mensajes,
    )


@app.post("/bots/{bot_id}/message", response_model=MessageRead, status_code=201)
def send_message(
    bot_id: str, payload: MessageCreate, session: Session = Depends(get_session)
) -> MessageRead:
    persona = BOTS.get(bot_id)
    if not persona:
        raise HTTPException(status_code=404, detail="Bot no encontrado")

    user_message = Message(bot_id=bot_id, sender=SenderEnum.USER, content=payload.mensaje)
    session.add(user_message)
    session.flush()

    respuesta = persona.responder(payload.mensaje)
    bot_message = Message(bot_id=bot_id, sender=SenderEnum.BOT, content=respuesta)
    session.add(bot_message)
    session.commit()
    session.refresh(bot_message)

    return MessageRead(
        id=bot_message.id,
        bot_id=bot_message.bot_id,
        remitente=bot_message.sender.value,
        contenido=bot_message.content,
        creado_en=bot_message.created_at,
    )


@app.delete("/bots/{bot_id}/conversation", status_code=204)
def clear_conversation(bot_id: str, session: Session = Depends(get_session)) -> None:
    if bot_id not in BOTS:
        raise HTTPException(status_code=404, detail="Bot no encontrado")
    session.query(Message).filter(Message.bot_id == bot_id).delete()
    session.commit()
'@

Write-ProjectFile "backend/requirements.txt" @'
fastapi==0.110.0
uvicorn[standard]==0.27.1
sqlalchemy==2.0.25
pydantic==1.10.13
'@

Write-ProjectFile "frontend/package.json" @'
{
  "name": "suite-bots",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.6.7",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.8"
  }
}
'@

Write-ProjectFile "frontend/vite.config.js" @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8000",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, "")
      }
    }
  }
});
'@

Write-ProjectFile "frontend/index.html" @'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Suite de Bots</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@

Write-ProjectFile "frontend/src/main.jsx" @'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.jsx";
import "./styles.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@

Write-ProjectFile "frontend/src/styles.css" @'
:root {
  font-family: "Segoe UI", system-ui, -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
  background: #f9fafb;
  color: #111827;
}

body {
  margin: 0;
}

#root {
  min-height: 100vh;
}

.app-container {
  max-width: 960px;
  margin: 0 auto;
  padding: 2rem 1.5rem 3rem;
}

header {
  text-align: center;
  margin-bottom: 2rem;
}

.tabs {
  display: flex;
  gap: 0.5rem;
  justify-content: center;
  flex-wrap: wrap;
  margin-bottom: 1.5rem;
}

.tab-button {
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 999px;
  cursor: pointer;
  background: #e5e7eb;
  color: #111827;
  transition: all 0.2s ease;
  font-size: 0.95rem;
}

.tab-button.active {
  background: #2563eb;
  color: #fff;
  box-shadow: 0 10px 25px rgba(37, 99, 235, 0.25);
}

.card {
  background: #ffffff;
  border-radius: 16px;
  padding: 1.75rem;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
}

.section-title {
  font-size: 1.5rem;
  margin-top: 0;
  margin-bottom: 1rem;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

textarea {
  resize: vertical;
  min-height: 120px;
  border-radius: 12px;
  border: 1px solid #d1d5db;
  padding: 0.75rem 1rem;
  font-size: 1rem;
}

button.primary {
  background: #2563eb;
  color: #fff;
  border: none;
  border-radius: 12px;
  padding: 0.75rem 1.5rem;
  font-size: 1rem;
  cursor: pointer;
  transition: background 0.2s ease;
}

button.primary:disabled {
  background: #93c5fd;
  cursor: not-allowed;
}

.message-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin-top: 1.25rem;
}

.message-item {
  background: #f3f4f6;
  border-radius: 12px;
  padding: 0.75rem 1rem;
}

.message-item.bot {
  background: #dbeafe;
}

.message-meta {
  font-size: 0.8rem;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.empty-state {
  text-align: center;
  color: #6b7280;
  padding: 2rem 1rem;
}

.summary-box {
  background: linear-gradient(135deg, #2563eb 0%, #7c3aed 100%);
  color: #fff;
  border-radius: 18px;
  padding: 1.5rem;
  margin-top: 1.5rem;
}
'@

Write-ProjectFile "frontend/src/App.jsx" @'
import { useEffect, useState } from "react";
import {
  clearConversation,
  getBots,
  getConversation,
  sendMessage
} from "./api";
import Coach from "./Coach.jsx";
import Tutor from "./Tutor.jsx";
import Habits from "./Habits.jsx";

const TABS = [
  { id: "tutor", label: "Tutor" },
  { id: "coach", label: "Coach de hábitos" },
  { id: "habits", label: "Gestor de hábitos" }
];

export default function App() {
  const [bots, setBots] = useState([]);
  const [activeTab, setActiveTab] = useState(TABS[0].id);
  const [historial, setHistorial] = useState([]);
  const [botInfo, setBotInfo] = useState(null);
  const [cargando, setCargando] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    getBots()
      .then((data) => setBots(data))
      .catch(() => setError("No se pudieron cargar los bots."));
  }, []);

  useEffect(() => {
    setError(null);
    setCargando(true);
    getConversation(activeTab)
      .then((data) => {
        setHistorial(data.historial);
        setBotInfo(data.bot);
      })
      .catch(() => setError("No se pudo cargar la conversación."))
      .finally(() => setCargando(false));
  }, [activeTab]);

  const manejarEnvio = async (mensaje) => {
    if (!mensaje) return;
    try {
      setEnviando(true);
      const respuesta = await sendMessage(activeTab, mensaje);
      const nuevoHistorial = await getConversation(activeTab);
      setHistorial(nuevoHistorial.historial);
      setBotInfo(nuevoHistorial.bot);
      return respuesta;
    } catch (e) {
      setError("No se pudo enviar el mensaje.");
      return null;
    } finally {
      setEnviando(false);
    }
  };

  const manejarLimpiar = async () => {
    try {
      await clearConversation(activeTab);
      setHistorial([]);
    } catch (e) {
      setError("No se pudo limpiar la conversación.");
    }
  };

  const vista = () => {
    const props = {
      bot: botInfo,
      historial,
      cargando,
      enviando,
      error,
      onSend: manejarEnvio,
      onClear: manejarLimpiar
    };

    switch (activeTab) {
      case "coach":
        return <Coach {...props} />;
      case "habits":
        return <Habits {...props} />;
      default:
        return <Tutor {...props} />;
    }
  };

  return (
    <div className="app-container">
      <header>
        <h1>Suite de bots personales</h1>
        <p>Elige el asistente ideal para estudiar, crear hábitos y mantenerlos.</p>
      </header>

      <nav className="tabs">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            className={`tab-button ${activeTab === tab.id ? "active" : ""}`}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>

      {bots.length === 0 && !error && (
        <p className="empty-state">Cargando información de los bots...</p>
      )}

      {error && <p className="empty-state">{error}</p>}

      {!error && vista()}
    </div>
  );
}
'@

Write-ProjectFile "frontend/src/Coach.jsx" @'
import ChatPanel from "./ChatPanel.jsx";

export default function Coach(props) {
  return (
    <ChatPanel
      titulo="Coach de hábitos"
      descripcion="Define pequeñas metas, diseña recordatorios y mantente motivado día a día."
      recomendaciones={[
        "Cuéntame el hábito que deseas incorporar",
        "Explícame cuándo y dónde lo practicarás",
        "Planifiquemos recompensas y recordatorios"
      ]}
      {...props}
    />
  );
}
'@

Write-ProjectFile "frontend/src/Tutor.jsx" @'
import ChatPanel from "./ChatPanel.jsx";

export default function Tutor(props) {
  return (
    <ChatPanel
      titulo="Tutor académico"
      descripcion="Aclaramos conceptos complejos con ejemplos sencillos y pasos concretos."
      recomendaciones={[
        "Describe la materia y el tema que deseas repasar",
        "Solicita un ejemplo práctico para practicar",
        "Pide un resumen rápido para repasar antes de un examen"
      ]}
      {...props}
    />
  );
}
'@

Write-ProjectFile "frontend/src/Habits.jsx" @'
import ChatPanel from "./ChatPanel.jsx";

export default function Habits(props) {
  return (
    <ChatPanel
      titulo="Gestor de hábitos"
      descripcion="Registra tus logros, analiza patrones y ajusta tus rutinas semanalmente."
      recomendaciones={[
        "Registra qué hábito cumpliste hoy",
        "Menciona obstáculos que aparecieron",
        "Pide ideas para mejorar tu seguimiento"
      ]}
      {...props}
    />
  );
}
'@

Write-ProjectFile "frontend/src/ChatPanel.jsx" @'
import { useState } from "react";

export default function ChatPanel({
  titulo,
  descripcion,
  recomendaciones = [],
  historial = [],
  cargando,
  enviando,
  onSend,
  onClear
}) {
  const [mensaje, setMensaje] = useState("");

  const manejarSubmit = async (event) => {
    event.preventDefault();
    if (!mensaje.trim()) return;
    await onSend(mensaje.trim());
    setMensaje("");
  };

  return (
    <section className="card">
      <h2 className="section-title">{titulo}</h2>
      <p>{descripcion}</p>

      {recomendaciones.length > 0 && (
        <div className="summary-box">
          <strong>Ideas para comenzar:</strong>
          <ul>
            {recomendaciones.map((item) => (
              <li key={item}>{item}</li>
            ))}
          </ul>
        </div>
      )}

      <form className="form-group" onSubmit={manejarSubmit}>
        <label htmlFor="mensaje">Escribe tu mensaje</label>
        <textarea
          id="mensaje"
          value={mensaje}
          onChange={(event) => setMensaje(event.target.value)}
          placeholder="Comparte tu duda o comenta tus avances..."
          disabled={cargando || enviando}
        />
        <div style={{ display: "flex", gap: "0.75rem", flexWrap: "wrap" }}>
          <button className="primary" type="submit" disabled={enviando}>
            {enviando ? "Enviando..." : "Enviar"}
          </button>
          <button
            type="button"
            className="primary"
            style={{ background: "#ef4444" }}
            onClick={onClear}
            disabled={cargando || enviando}
          >
            Limpiar historial
          </button>
        </div>
      </form>

      {cargando ? (
        <p className="empty-state">Cargando conversación...</p>
      ) : historial.length === 0 ? (
        <p className="empty-state">
          Aún no hay mensajes. ¡Envía el primero y comienza la conversación!
        </p>
      ) : (
        <div className="message-list">
          {historial.map((item) => (
            <article
              key={item.id}
              className={`message-item ${item.remitente === "bot" ? "bot" : ""}`}
            >
              <div className="message-meta">
                {item.remitente === "bot" ? "Bot" : "Tú"} · {new Date(item.creado_en).toLocaleString()}
              </div>
              <div>{item.contenido}</div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
'@

Write-ProjectFile "frontend/src/api.js" @'
import axios from "axios";

const api = axios.create({
  baseURL: "/api"
});

export const getBots = () => api.get("/bots").then((res) => res.data);

export const getConversation = (botId) =>
  api.get(`/bots/${botId}/conversation`).then((res) => res.data);

export const sendMessage = (botId, mensaje) =>
  api.post(`/bots/${botId}/message`, { mensaje }).then((res) => res.data);

export const clearConversation = (botId) =>
  api.delete(`/bots/${botId}/conversation`);

export default api;
'@

if (-not $InstallOnly) {
    Write-Host "Estructura de archivos creada o actualizada." -ForegroundColor Green
}

# Configuración de entorno Python
$venvPath = Join-Path $Root ".venv"
if (-not (Test-Path $venvPath)) {
    Write-Host "Creando entorno virtual de Python..." -ForegroundColor Cyan
    python -m venv $venvPath
}

$pythonExe = Join-Path $venvPath "Scripts/python.exe"
$pipExe = Join-Path $venvPath "Scripts/pip.exe"

Write-Host "Instalando dependencias del backend..." -ForegroundColor Cyan
& $pipExe install --upgrade pip | Out-Null
& $pipExe install -r (Join-Path $Root "backend/requirements.txt")

# Configuración del frontend
Write-Host "Instalando dependencias del frontend..." -ForegroundColor Cyan
Push-Location (Join-Path $Root "frontend")
try {
    npm install | Out-Null
} finally {
    Pop-Location
}

if ($InstallOnly) {
    Write-Host "Instalación completada. Ejecuta nuevamente sin -InstallOnly para iniciar los servicios." -ForegroundColor Yellow
    exit 0
}

Write-Host "Iniciando backend en http://localhost:8000..." -ForegroundColor Green
Start-Process -FilePath $pythonExe -ArgumentList "-m", "uvicorn", "app.main:app", "--reload", "--port", "8000" -WorkingDirectory (Join-Path $Root "backend")

Write-Host "Iniciando frontend en http://localhost:5173..." -ForegroundColor Green
Start-Process -FilePath "npm" -ArgumentList "run", "dev" -WorkingDirectory (Join-Path $Root "frontend")

Write-Host "Todo listo. Usa Ctrl+C en las ventanas abiertas para detener los servicios." -ForegroundColor Green
