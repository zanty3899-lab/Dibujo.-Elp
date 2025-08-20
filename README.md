# Dibujo.-Elp

Ejemplo de animación de avatar mecánico creado con Python. Incluye un script
(`mechanic_avatar.py`) que genera un video con una figura humana estilizada
capaz de mover los labios, cambiar de expresión y realizar gestos con los brazos.

## Requisitos

- Python 3
- [pygame](https://www.pygame.org/)
- [moviepy](https://zulko.github.io/moviepy/)

Instala las dependencias con:

```bash
pip install pygame moviepy
```

## Uso básico

```bash
python mechanic_avatar.py --audio voz.wav --expression happy --arm wave --clothing "#003399" --bg "#EEEEEE" --output avatar.mp4
```

Parámetros principales:

- `--audio`: archivo de audio para sincronizar los labios.
- `--expression`: `happy`, `serious` o `surprised`.
- `--arm`: gesto del brazo derecho (`down`, `point` o `wave`).
- `--clothing`: color del mono de trabajo en formato hexadecimal.
- `--bg`: color de fondo en formato hexadecimal.
- `--output`: archivo de video resultante.

Si no se proporciona un audio, los labios se moverán de manera automática y se
puede definir la duración con `--duration`.

El script exporta un archivo `mp4` listo para ser utilizado en videos
informativos de mecánica.

