# Cómo jugar PES 2014 en Windows (port nativo)

> Esta guía sirve para las dos carpetas de `Documentos\PES2014_WINDOWS\`: **`PES2014_JUGAR`** (versión limpia, solo
> para jugar) y **`PES2014_PROYECTO`** (proyecto completo). `PES2014_JUGAR` se genera desde el proyecto con
> `tools\windows\sincronizar_jugar.bat`. No cambies sus archivos a mano, salvo tus controles (`controles.cfg`) y tus
> partidas guardadas, que la sincronización respeta.
>
> La guía completa del juego (qué esperar, ajustes de pantalla y variables) sigue en `COMO_JUGAR.md`, escrita para
> Linux. Aquí van solo las diferencias de Windows.

## 1. Jugar

Doble clic en **`jugar.bat`**.

- Para cerrar, cierra la ventana (o Alt+F4). **F11** alterna entre ventana y pantalla completa.
- La salida del juego queda en `logs\jugar.log`; la partida anterior, en `logs\jugar.anterior.log`.
- Si el juego termina con error, la ventana negra muestra las últimas líneas del registro y espera a que pulses Enter.
- Si la partida anterior falló, sus volcados de diagnóstico se guardan en `logs\diagnostico\fallo_<fecha>\`.

Para cambiar una opción solo una vez, abre PowerShell en la carpeta (clic derecho en un espacio vacío → «Abrir en Terminal») y define la variable antes de lanzar:

```powershell
$env:PES_GS_GPU = '0'; .\jugar.bat        # dibujar en la CPU (más lento), por si algo se ve mal
$env:PES_FULLSCREEN = '0'; .\jugar.bat    # en ventana
```

## 2. Controles y pantalla

Doble clic en **`configurar_controles.exe`**. Funciona igual que en Linux y guarda `controles.cfg` junto a `jugar.bat`.

**Mandos:** los identificadores de los joysticks y la numeración de sus botones son distintos en Windows y en Linux. Por
eso el `controles.cfg` copiado de Linux se dejó **sin las asignaciones de joystick** (sí conserva las teclas y los
ajustes de pantalla). Las líneas originales de Linux están en `controles_linux.cfg`. Sin asignaciones, cada mando
conectado funciona en modo automático: el primero es el mando 1 y el segundo, el mando 2. Si quieres otra asignación, usa
**Mandos...** en el configurador.

**Pantalla completa:** en Windows la pantalla completa real está siempre disponible. El monitor cambia a la resolución
elegida y Windows restaura la del escritorio al cerrar el juego (no hace falta el restaurador de Linux). La opción
«Imagen estirada» no cambia el escalado del monitor: eso lo decide el panel de control de la tarjeta gráfica (Intel:
*Escalado → Pantalla completa*).

## 3. Requisitos

- Windows 10 o 11 de 64 bits, con un procesador con SSE4.2 (2009 en adelante) y OpenGL 4.5 (el Intel HD 520 de este
  equipo lo tiene con el controlador de Intel).
- Las DLL de FFmpeg (vídeos) van junto a `ps2EntryRunner.exe`. Necesitan el *Microsoft Visual C++ Redistributable*
  2015-2022 x64, que casi todos los Windows ya tienen. Si al arrancar sale un error de `VCRUNTIME140.dll` o
  `MSVCP140.dll`, instálalo desde la web de Microsoft («vc_redist.x64.exe»).
- **Arranque rápido de Windows:** si vas a seguir alternando con Linux, conviene desactivarlo (Panel de control →
  Opciones de energía → «Elegir el comportamiento de los botones de inicio/apagado» → quitar «Activar inicio rápido»).
  Con él activo, Windows no se apaga del todo y Linux puede ver la partición en un estado inconsistente.

## 4. Si algo falla

- Mira `logs\jugar.log`. Las primeras líneas dicen qué tarjeta gráfica y qué versión de OpenGL encontró el juego.
- Si la imagen sale negra o el juego se cierra al abrir la ventana: actualiza el controlador de la tarjeta gráfica
  y prueba `PES_GS_GPU=0`.
- Si se queda colgado más de 5 segundos, el vigilante escribe en el registro la pila de cada hilo (`[watchdog]`).
