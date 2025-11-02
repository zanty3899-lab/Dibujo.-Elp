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
