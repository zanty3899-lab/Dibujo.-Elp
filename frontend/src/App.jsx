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
