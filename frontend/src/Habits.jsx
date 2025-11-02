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
