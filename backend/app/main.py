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
