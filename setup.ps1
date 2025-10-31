$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptRoot

$structure = @(
    'bots_suite_stack',
    'bots_suite_stack/backend',
    'bots_suite_stack/backend/app',
    'bots_suite_stack/frontend',
    'bots_suite_stack/frontend/src',
    'bots_suite_stack/frontend/src/ui'
)

foreach ($dir in $structure) {
    $fullPath = Join-Path $scriptRoot $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath | Out-Null
    }
}

$backendDir = Join-Path $scriptRoot 'bots_suite_stack/backend'
$backendAppDir = Join-Path $backendDir 'app'
$frontendDir = Join-Path $scriptRoot 'bots_suite_stack/frontend'
$frontendSrcDir = Join-Path $frontendDir 'src'
$frontendUiDir = Join-Path $frontendSrcDir 'ui'

Set-Content -Path (Join-Path $backendDir 'requirements.txt') -Value @'
fastapi==0.115.0
uvicorn[standard]==0.30.6
sqlalchemy==2.0.34
pydantic==2.9.2
python-dotenv==1.0.1
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir '__init__.py') -Value '' -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'config.py') -Value @'
database_url = "sqlite:///./dev.db"
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'db.py') -Value @'
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from .config import database_url

connect_args = {}
if database_url.startswith("sqlite"):
    connect_args["check_same_thread"] = False

engine = create_engine(database_url, future=True, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine, future=True)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from . import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'models.py') -Value @'
from datetime import datetime, timedelta
from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from .db import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    habits = relationship("Habit", back_populates="user", cascade="all, delete-orphan")
    checkins = relationship("Checkin", back_populates="user", cascade="all, delete-orphan")
    study_sessions = relationship("StudySession", back_populates="user", cascade="all, delete-orphan")
    cards = relationship("Card", back_populates="user", cascade="all, delete-orphan")


class Habit(Base):
    __tablename__ = "habits"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String, nullable=False)
    schedule = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User", back_populates="habits")
    checkins = relationship("Checkin", back_populates="habit", cascade="all, delete-orphan")


class Checkin(Base):
    __tablename__ = "checkins"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    habit_id = Column(Integer, ForeignKey("habits.id"), nullable=False, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False)
    streak = Column(Integer, default=1, nullable=False)

    habit = relationship("Habit", back_populates="checkins")
    user = relationship("User", back_populates="checkins")


class StudySession(Base):
    __tablename__ = "study_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    topic = Column(String, nullable=False)
    lesson = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    user = relationship("User", back_populates="study_sessions")


class Card(Base):
    __tablename__ = "cards"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    prompt = Column(Text, nullable=False)
    answer = Column(Text, nullable=False)
    last_review = Column(DateTime, default=datetime.utcnow, nullable=False)
    next_review = Column(DateTime, default=lambda: datetime.utcnow() + timedelta(days=1), nullable=False)
    interval = Column(Integer, default=1, nullable=False)
    ease = Column(Integer, default=250, nullable=False)
    streak = Column(Integer, default=0, nullable=False)

    user = relationship("User", back_populates="cards")
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'schemas.py') -Value @'
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class HabitCreate(BaseModel):
    name: str
    schedule: Dict[str, Any]


class HabitRead(BaseModel):
    id: int
    name: str
    schedule: Dict[str, Any]
    created_at: datetime

    class Config:
        from_attributes = True


class CheckinCreate(BaseModel):
    timestamp: Optional[datetime] = None


class CheckinResponse(BaseModel):
    habit_id: int
    streak: int
    timestamp: datetime


class HabitSummaryDay(BaseModel):
    date: str
    completed: List[str] = Field(default_factory=list)


class HabitSummary(BaseModel):
    days: List[HabitSummaryDay]


class CoachNudgeRequest(BaseModel):
    focus: str = "general"


class CoachNudgeResponse(BaseModel):
    message: str


class PomodoroStartRequest(BaseModel):
    minutes: int = 25


class PomodoroStartResponse(BaseModel):
    end_time: datetime


class LessonRequest(BaseModel):
    topic: str


class LessonResponse(BaseModel):
    topic: str
    outline: List[str]
    practice: str


class AnswerRequest(BaseModel):
    card_id: Optional[int] = None
    prompt: str
    expected_answer: str
    user_answer: str


class AnswerResponse(BaseModel):
    correct: bool
    feedback: str
    card_id: int
    next_review: datetime


class TutorReviewResponse(BaseModel):
    cards: List[dict]


class TutorSummaryResponse(BaseModel):
    total_cards: int
    due_cards: int
    upcoming_cards: int
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'llm.py') -Value @'
from datetime import datetime, timedelta
from typing import List


def generate_nudge(focus: str) -> str:
    phrases = {
        "general": "Recuerda que cada pequeño avance cuenta. ¡Vamos a por ello!",
        "habits": "Tu rutina te está acercando a tu meta. Marca ese check-in hoy.",
        "study": "Aprender algo nuevo hoy te pone delante del 90% de la gente."
    }
    return phrases.get(focus.lower(), phrases["general"])


def generate_lesson(topic: str) -> tuple[List[str], str]:
    bullets = [
        f"Definición básica de {topic}.",
        f"Ejemplo práctico de {topic}.",
        f"Aplicación rápida de {topic} en la vida diaria."
    ]
    practice = f"Explica {topic} en 3 frases usando una metáfora sencilla."
    return bullets, practice


def evaluate_answer(prompt: str, expected: str, answer: str) -> tuple[bool, str]:
    normalized_expected = expected.strip().lower()
    normalized_answer = answer.strip().lower()
    correct = normalized_expected in normalized_answer or normalized_answer in normalized_expected
    if correct:
        feedback = "¡Excelente! Tu respuesta cubre la idea clave."
    else:
        feedback = f"Casi. Recuerda mencionar: {expected.strip()}"
    return correct, feedback


def next_review_schedule(correct: bool, interval: int, ease: int) -> tuple[int, datetime, int, int]:
    ease_adjustment = 20 if correct else -30
    new_ease = max(130, min(300, ease + ease_adjustment))
    if correct:
        new_interval = max(1, int(interval * (new_ease / 200)))
    else:
        new_interval = 1
    next_review = datetime.utcnow() + timedelta(days=new_interval)
    streak_delta = 1 if correct else 0
    return new_interval, next_review, new_ease, streak_delta
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'routers.py') -Value @'
import json
from datetime import datetime, timedelta
from typing import List

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from . import llm, models, schemas
from .db import get_db

router = APIRouter()


def get_or_create_user(db: Session, email: str) -> models.User:
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        user = models.User(email=email)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


@router.post("/habits", response_model=schemas.HabitRead)
def create_habit(payload: schemas.HabitCreate, db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    schedule_json = json.dumps(payload.schedule, ensure_ascii=False)
    habit = models.Habit(user_id=user.id, name=payload.name, schedule=schedule_json)
    db.add(habit)
    db.commit()
    db.refresh(habit)
    return schemas.HabitRead(
        id=habit.id,
        name=habit.name,
        schedule=payload.schedule,
        created_at=habit.created_at,
    )


@router.post("/habits/{habit_id}/checkin", response_model=schemas.CheckinResponse)
def habit_checkin(habit_id: int, payload: schemas.CheckinCreate, db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    habit = db.query(models.Habit).filter(models.Habit.id == habit_id, models.Habit.user_id == user.id).first()
    if not habit:
        raise HTTPException(status_code=404, detail="Hábito no encontrado")

    timestamp = payload.timestamp or datetime.utcnow()
    last_checkin = (
        db.query(models.Checkin)
        .filter(models.Checkin.habit_id == habit.id)
        .order_by(models.Checkin.timestamp.desc())
        .first()
    )

    streak = 1
    if last_checkin:
        delta_days = (timestamp.date() - last_checkin.timestamp.date()).days
        if delta_days == 0:
            streak = last_checkin.streak
        elif delta_days == 1:
            streak = last_checkin.streak + 1

    checkin = models.Checkin(user_id=user.id, habit_id=habit.id, timestamp=timestamp, streak=streak)
    db.add(checkin)
    db.commit()
    db.refresh(checkin)

    return schemas.CheckinResponse(habit_id=habit.id, streak=checkin.streak, timestamp=checkin.timestamp)


@router.get("/habits/summary", response_model=schemas.HabitSummary)
def habits_summary(db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    start_date = datetime.utcnow().date() - timedelta(days=6)

    checkins = (
        db.query(models.Checkin)
        .join(models.Habit)
        .filter(models.Checkin.user_id == user.id, models.Checkin.timestamp >= datetime.combine(start_date, datetime.min.time()))
        .all()
    )

    summary_map: dict[str, List[str]] = {}
    for checkin in checkins:
        day_key = checkin.timestamp.strftime("%Y-%m-%d")
        summary_map.setdefault(day_key, []).append(checkin.habit.name)

    days = []
    for i in range(7):
        day = start_date + timedelta(days=i)
        day_key = day.strftime("%Y-%m-%d")
        days.append(schemas.HabitSummaryDay(date=day_key, completed=summary_map.get(day_key, [])))

    return schemas.HabitSummary(days=days)


@router.post("/coach/nudge", response_model=schemas.CoachNudgeResponse)
def coach_nudge(payload: schemas.CoachNudgeRequest, x_debug_user: str = Header(..., alias="X-Debug-User"), db: Session = Depends(get_db)):
    get_or_create_user(db, x_debug_user)
    message = llm.generate_nudge(payload.focus)
    return schemas.CoachNudgeResponse(message=message)


@router.post("/pomodoro/start", response_model=schemas.PomodoroStartResponse)
def pomodoro_start(payload: schemas.PomodoroStartRequest, x_debug_user: str = Header(..., alias="X-Debug-User"), db: Session = Depends(get_db)):
    get_or_create_user(db, x_debug_user)
    minutes = max(1, min(60, payload.minutes))
    end_time = datetime.utcnow() + timedelta(minutes=minutes)
    return schemas.PomodoroStartResponse(end_time=end_time)


@router.post("/lesson", response_model=schemas.LessonResponse)
def lesson(payload: schemas.LessonRequest, db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    outline, practice = llm.generate_lesson(payload.topic)
    session = models.StudySession(user_id=user.id, topic=payload.topic, lesson="\n".join(outline))
    db.add(session)
    db.commit()
    return schemas.LessonResponse(topic=payload.topic, outline=outline, practice=practice)


@router.post("/answer", response_model=schemas.AnswerResponse)
def answer(payload: schemas.AnswerRequest, db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    card: models.Card | None = None

    if payload.card_id:
        card = db.query(models.Card).filter(models.Card.id == payload.card_id, models.Card.user_id == user.id).first()
    if not card:
        card = models.Card(
            user_id=user.id,
            prompt=payload.prompt,
            answer=payload.expected_answer,
            interval=1,
            ease=250,
            next_review=datetime.utcnow(),
        )
        db.add(card)
        db.commit()
        db.refresh(card)

    correct, feedback = llm.evaluate_answer(payload.prompt, payload.expected_answer, payload.user_answer)
    new_interval, next_review, new_ease, streak_delta = llm.next_review_schedule(correct, card.interval, card.ease)

    card.last_review = datetime.utcnow()
    card.interval = new_interval
    card.next_review = next_review
    card.ease = new_ease
    card.streak = card.streak + streak_delta if correct else 0
    db.add(card)
    db.commit()
    db.refresh(card)

    return schemas.AnswerResponse(correct=correct, feedback=feedback, card_id=card.id, next_review=card.next_review)


@router.get("/tutor/review", response_model=schemas.TutorReviewResponse)
def tutor_review(db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    now = datetime.utcnow()
    cards = (
        db.query(models.Card)
        .filter(models.Card.user_id == user.id, models.Card.next_review <= now)
        .order_by(models.Card.next_review.asc())
        .all()
    )
    serialized = [
        {
            "id": card.id,
            "prompt": card.prompt,
            "next_review": card.next_review.isoformat(),
            "interval": card.interval,
            "ease": card.ease,
            "streak": card.streak,
        }
        for card in cards
    ]
    return schemas.TutorReviewResponse(cards=serialized)


@router.get("/tutor/summary", response_model=schemas.TutorSummaryResponse)
def tutor_summary(db: Session = Depends(get_db), x_debug_user: str = Header(..., alias="X-Debug-User")):
    user = get_or_create_user(db, x_debug_user)
    now = datetime.utcnow()
    total_cards = db.query(func.count(models.Card.id)).filter(models.Card.user_id == user.id).scalar() or 0
    due_cards = db.query(func.count(models.Card.id)).filter(models.Card.user_id == user.id, models.Card.next_review <= now).scalar() or 0
    upcoming_cards = db.query(func.count(models.Card.id)).filter(models.Card.user_id == user.id, models.Card.next_review > now).scalar() or 0
    return schemas.TutorSummaryResponse(total_cards=total_cards, due_cards=due_cards, upcoming_cards=upcoming_cards)
'@ -Encoding UTF8

Set-Content -Path (Join-Path $backendAppDir 'main.py') -Value @'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .db import init_db
from .routers import router

init_db()

app = FastAPI(title="Bots Suite Stack API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

app.include_router(router, prefix="/api")
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendDir 'package.json') -Value @'
{
  "name": "bots-suite-stack-frontend",
  "private": true,
  "version": "0.0.1",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.9",
    "vite": "^5.4.7"
  }
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendDir 'vite.config.js') -Value @'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5173,
    proxy: {
      "/api": "http://localhost:8000"
    }
  }
});
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendDir 'index.html') -Value @'
<!doctype html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Bots Suite Stack</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendSrcDir 'main.jsx') -Value @'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./ui/App.jsx";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'api.js') -Value @'
const defaultHeaders = {
  "Content-Type": "application/json",
  "X-Debug-User": "santy@example.com"
};

export async function apiFetch(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      ...defaultHeaders,
      ...(options.headers || {})
    },
    ...options
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Error ${response.status}`);
  }

  const contentType = response.headers.get("content-type") || "";
  if (contentType.includes("application/json")) {
    return await response.json();
  }

  return await response.text();
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'App.jsx') -Value @'
import React, { useEffect, useState } from "react";
import Coach from "./Coach.jsx";
import Tutor from "./Tutor.jsx";
import Habits from "./Habits.jsx";
import "./styles.css";
import { apiFetch } from "./api.js";

const tabs = [
  { id: "coach", label: "Coach", component: Coach },
  { id: "tutor", label: "Tutor", component: Tutor },
  { id: "habits", label: "Hábitos", component: Habits }
];

export default function App() {
  const [activeTab, setActiveTab] = useState("coach");
  const [summary, setSummary] = useState(null);

  useEffect(() => {
    const loadSummary = async () => {
      try {
        const data = await apiFetch("/api/tutor/summary");
        setSummary(data);
      } catch (error) {
        setSummary(null);
      }
    };
    loadSummary();
  }, []);

  const ActiveComponent = tabs.find((tab) => tab.id === activeTab).component;

  return (
    <div className="app-shell">
      <header>
        <h1>Bots Suite Stack</h1>
        {summary && (
          <p className="tutor-summary">
            Tarjetas totales: {summary.total_cards} · Vencidas: {summary.due_cards} · Próximas: {summary.upcoming_cards}
          </p>
        )}
      </header>
      <nav>
        {tabs.map((tab) => (
          <button
            key={tab.id}
            className={tab.id === activeTab ? "active" : ""}
            onClick={() => setActiveTab(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>
      <main>
        <ActiveComponent />
      </main>
    </div>
  );
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'Coach.jsx') -Value @'
import React, { useState } from "react";
import { apiFetch } from "./api.js";

export default function Coach() {
  const [focus, setFocus] = useState("general");
  const [nudge, setNudge] = useState("");
  const [pomodoro, setPomodoro] = useState(null);
  const [loading, setLoading] = useState(false);

  const getNudge = async () => {
    setLoading(true);
    try {
      const data = await apiFetch("/api/coach/nudge", {
        method: "POST",
        body: JSON.stringify({ focus })
      });
      setNudge(data.message);
    } catch (error) {
      setNudge(error.message);
    } finally {
      setLoading(false);
    }
  };

  const startPomodoro = async () => {
    setLoading(true);
    try {
      const data = await apiFetch("/api/pomodoro/start", {
        method: "POST",
        body: JSON.stringify({ minutes: 25 })
      });
      setPomodoro(new Date(data.end_time).toLocaleTimeString());
    } catch (error) {
      setPomodoro(null);
      setNudge(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section>
      <h2>Coach motivacional</h2>
      <label>
        Enfoque:
        <select value={focus} onChange={(event) => setFocus(event.target.value)}>
          <option value="general">General</option>
          <option value="habits">Hábitos</option>
          <option value="study">Estudio</option>
        </select>
      </label>
      <div className="actions">
        <button onClick={getNudge} disabled={loading}>Obtener empujón</button>
        <button onClick={startPomodoro} disabled={loading}>Iniciar Pomodoro</button>
      </div>
      {nudge && <p className="result">{nudge}</p>}
      {pomodoro && <p className="result">Fin estimado: {pomodoro}</p>}
    </section>
  );
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'Habits.jsx') -Value @'
import React, { useEffect, useState } from "react";
import { apiFetch } from "./api.js";

export default function Habits() {
  const [name, setName] = useState("");
  const [schedule, setSchedule] = useState("{\"lunes\": true, \"martes\": true}");
  const [habits, setHabits] = useState([]);
  const [selectedHabit, setSelectedHabit] = useState("");
  const [summary, setSummary] = useState([]);
  const [feedback, setFeedback] = useState("");

  const fetchSummary = async () => {
    try {
      const data = await apiFetch("/api/habits/summary");
      setSummary(data.days);
    } catch (error) {
      setFeedback(error.message);
    }
  };

  useEffect(() => {
    fetchSummary();
  }, []);

  const createHabit = async () => {
    try {
      const parsedSchedule = JSON.parse(schedule);
      const data = await apiFetch("/api/habits", {
        method: "POST",
        body: JSON.stringify({ name, schedule: parsedSchedule })
      });
      setHabits((prev) => [...prev, data]);
      setSelectedHabit(String(data.id));
      setName("");
      setFeedback("Hábito creado");
      fetchSummary();
    } catch (error) {
      setFeedback(`Error: ${error.message}`);
    }
  };

  const doCheckin = async () => {
    if (!selectedHabit) {
      setFeedback("Selecciona un hábito");
      return;
    }
    try {
      const data = await apiFetch(`/api/habits/${selectedHabit}/checkin`, {
        method: "POST",
        body: JSON.stringify({})
      });
      setFeedback(`Check-in registrado. Racha: ${data.streak}`);
      fetchSummary();
    } catch (error) {
      setFeedback(error.message);
    }
  };

  return (
    <section>
      <h2>Gestor de hábitos</h2>
      <div className="form">
        <input
          placeholder="Nombre del hábito"
          value={name}
          onChange={(event) => setName(event.target.value)}
        />
        <textarea
          placeholder='Horario JSON, ej: {"lunes": true}'
          value={schedule}
          onChange={(event) => setSchedule(event.target.value)}
          rows={3}
        />
        <button onClick={createHabit}>Crear hábito</button>
      </div>

      {habits.length > 0 && (
        <div className="form">
          <label>
            Hábito para check-in:
            <select value={selectedHabit} onChange={(event) => setSelectedHabit(event.target.value)}>
              <option value="" disabled>
                Selecciona
              </option>
              {habits.map((habit) => (
                <option key={habit.id} value={habit.id}>
                  {habit.name}
                </option>
              ))}
            </select>
          </label>
          <button onClick={doCheckin}>Registrar check-in</button>
        </div>
      )}

      <h3>Resumen últimos 7 días</h3>
      <ul className="summary">
        {summary.map((day) => (
          <li key={day.date}>
            <strong>{day.date}</strong>
            <div>{day.completed.length > 0 ? day.completed.join(", ") : "Sin registros"}</div>
          </li>
        ))}
      </ul>

      {feedback && <p className="result">{feedback}</p>}
    </section>
  );
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'Tutor.jsx') -Value @'
import React, { useEffect, useState } from "react";
import { apiFetch } from "./api.js";

export default function Tutor() {
  const [topic, setTopic] = useState("Derivadas");
  const [lesson, setLesson] = useState(null);
  const [answer, setAnswer] = useState("");
  const [expected, setExpected] = useState("");
  const [reviewCards, setReviewCards] = useState([]);
  const [verdict, setVerdict] = useState(null);

  const loadReview = async () => {
    try {
      const data = await apiFetch("/api/tutor/review");
      setReviewCards(data.cards);
    } catch (error) {
      setReviewCards([]);
    }
  };

  useEffect(() => {
    loadReview();
  }, []);

  const requestLesson = async () => {
    try {
      const data = await apiFetch("/api/lesson", {
        method: "POST",
        body: JSON.stringify({ topic })
      });
      setLesson(data);
      setExpected(data.practice);
      setVerdict(null);
    } catch (error) {
      setLesson(null);
    }
  };

  const submitAnswer = async () => {
    if (!lesson) {
      return;
    }
    try {
      const data = await apiFetch("/api/answer", {
        method: "POST",
        body: JSON.stringify({
          card_id: reviewCards[0]?.id,
          prompt: lesson.topic,
          expected_answer: expected,
          user_answer: answer
        })
      });
      setVerdict(data);
      setAnswer("");
      loadReview();
    } catch (error) {
      setVerdict({ feedback: error.message, correct: false });
    }
  };

  return (
    <section>
      <h2>Tutor inteligente</h2>
      <div className="form">
        <input value={topic} onChange={(event) => setTopic(event.target.value)} />
        <button onClick={requestLesson}>Pedir lección</button>
      </div>

      {lesson && (
        <article className="lesson">
          <h3>{lesson.topic}</h3>
          <ul>
            {lesson.outline.map((item, index) => (
              <li key={index}>{item}</li>
            ))}
          </ul>
          <p className="practice">Ejercicio: {lesson.practice}</p>
        </article>
      )}

      <div className="form">
        <textarea
          placeholder="Tu respuesta"
          value={answer}
          onChange={(event) => setAnswer(event.target.value)}
          rows={4}
        />
        <button onClick={submitAnswer}>Enviar respuesta</button>
      </div>

      {verdict && (
        <div className={`verdict ${verdict.correct ? "ok" : "fail"}`}>
          <p>{verdict.feedback}</p>
          {verdict.next_review && <p>Revisa otra vez: {new Date(verdict.next_review).toLocaleString()}</p>}
        </div>
      )}

      <aside className="review">
        <h3>Cards por repasar</h3>
        {reviewCards.length === 0 ? (
          <p>No hay tarjetas vencidas.</p>
        ) : (
          <ul>
            {reviewCards.map((card) => (
              <li key={card.id}>
                {card.prompt} — vence {new Date(card.next_review).toLocaleString()}
              </li>
            ))}
          </ul>
        )}
      </aside>
    </section>
  );
}
'@ -Encoding UTF8

Set-Content -Path (Join-Path $frontendUiDir 'styles.css') -Value @'
body {
  font-family: system-ui, sans-serif;
  margin: 0;
  background: #f6f8fb;
  color: #1f2933;
}

.app-shell {
  max-width: 960px;
  margin: 0 auto;
  padding: 2rem;
}

header {
  text-align: center;
  margin-bottom: 2rem;
}

.tutor-summary {
  margin-top: 0.5rem;
  color: #475569;
}

nav {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin-bottom: 1.5rem;
}

nav button {
  padding: 0.5rem 1rem;
  border: 1px solid #94a3b8;
  background: white;
  border-radius: 999px;
  cursor: pointer;
}

nav button.active {
  background: #2563eb;
  color: white;
  border-color: #2563eb;
}

main {
  background: white;
  padding: 2rem;
  border-radius: 1rem;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
}

section h2 {
  margin-top: 0;
}

.form {
  display: grid;
  gap: 0.75rem;
  margin-bottom: 1.5rem;
}

.form input,
.form textarea,
.form select {
  padding: 0.75rem;
  border-radius: 0.75rem;
  border: 1px solid #cbd5e1;
}

.form button,
.actions button {
  padding: 0.75rem 1rem;
  border-radius: 0.75rem;
  border: none;
  background: #2563eb;
  color: white;
  cursor: pointer;
}

.result {
  background: #eff6ff;
  border-left: 4px solid #2563eb;
  padding: 1rem;
  border-radius: 0.5rem;
}

.summary {
  list-style: none;
  padding: 0;
  display: grid;
  gap: 0.5rem;
}

.lesson {
  background: #f8fafc;
  padding: 1.5rem;
  border-radius: 1rem;
  margin-bottom: 1.5rem;
}

.lesson ul {
  padding-left: 1.2rem;
}

.practice {
  font-style: italic;
}

.verdict.ok {
  background: #dcfce7;
  border-left: 4px solid #16a34a;
  padding: 1rem;
  border-radius: 0.5rem;
}

.verdict.fail {
  background: #fee2e2;
  border-left: 4px solid #dc2626;
  padding: 1rem;
  border-radius: 0.5rem;
}

.review ul {
  list-style: none;
  padding: 0;
}

.review li {
  background: #e2e8f0;
  padding: 0.5rem;
  border-radius: 0.5rem;
  margin-bottom: 0.5rem;
}
'@ -Encoding UTF8

$venvPath = Join-Path $backendDir '.venv'
if (-not (Test-Path $venvPath)) {
    Write-Host "Creando entorno virtual del backend..."
    & python -m venv $venvPath
}

Write-Host "Instalando dependencias del backend..."
& (Join-Path $venvPath 'Scripts/python.exe') -m pip install --upgrade pip
& (Join-Path $venvPath 'Scripts/python.exe') -m pip install -r (Join-Path $backendDir 'requirements.txt')

Write-Host "Instalando dependencias del frontend..."
Push-Location $frontendDir
try {
    & npm install
}
finally {
    Pop-Location
}

Write-Host "Iniciando servidores..."
$backendCommand = "Set-Location `"$backendDir`"; . .\.venv\Scripts\Activate.ps1; uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
$frontendCommand = "Set-Location `"$frontendDir`"; npm run dev -- --host 0.0.0.0 --port 5173"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCommand | Out-Null
Start-Process powershell -ArgumentList "-NoExit", "-Command", $frontendCommand | Out-Null

Write-Host "Backend: http://localhost:8000/docs"
Write-Host "Frontend: http://localhost:5173"

Write-Host ""
Write-Host "Cómo ejecutar manualmente si no usas el script:" -ForegroundColor Cyan
Write-Host "1. python -m venv bots_suite_stack/backend/.venv"
Write-Host "2. bots_suite_stack/backend/.venv/Scripts/activate"
Write-Host "3. pip install -r bots_suite_stack/backend/requirements.txt"
Write-Host "4. cd bots_suite_stack/frontend && npm install"
Write-Host "5. En una consola: cd bots_suite_stack/backend && ./.venv/Scripts/activate && uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload"
Write-Host "6. En otra consola: cd bots_suite_stack/frontend && npm run dev -- --host 0.0.0.0 --port 5173"

Write-Host ""
Write-Host "Solución de problemas:" -ForegroundColor Cyan
Write-Host "- Si PowerShell bloquea el script, ejecuta: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
Write-Host "- Permite en el firewall las apps python.exe y node.exe si Windows las bloquea"
Write-Host "- Si los puertos 8000 o 5173 están en uso, cierra los procesos o modifica los puertos en el script"
