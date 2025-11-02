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
