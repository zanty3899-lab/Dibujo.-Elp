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
