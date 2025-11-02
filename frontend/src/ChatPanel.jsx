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
