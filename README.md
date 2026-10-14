# Overcharged: Idle-Action Merge (Roblox)

Proyecto completo desarrollado con arquitectura limpia, tipado estricto Luau (`--!strict`), y optimizado para métricas virales y alta retención de usuarios.

---

## 🚀 Cómo jugar y probar de inmediato

### Opción 1: Abrir directamente el archivo generado (Más rápida)
1. Busca el archivo **`Overcharged.rbxl`** en esta carpeta.
2. Haz **doble clic** sobre él para abrirlo en **Roblox Studio**.
3. Presiona el botón verde **Play (F5)**. ¡Todo el juego, UI, tienda de mejoras y sistema de Auras ya están listos y funcionando!

### Opción 2: Sincronización en vivo con Rojo (Para desarrolladores)
1. Ejecuta el archivo `serve.bat` (o ejecuta `.\rojo.exe serve` en la terminal).
2. En Roblox Studio, abre el plugin de Rojo y presiona **Connect**.
3. Cualquier cambio que hagas en los archivos `.luau` de la carpeta `src/` se sincronizará automáticamente en tiempo real.

---

## 📂 Arquitectura del Proyecto

```text
Roblox/
├── default.project.json      -- Configuración del proyecto Rojo
├── Overcharged.rbxl          -- Archivo compilado de Roblox Studio listo para jugar
├── rojo.exe                  -- Binario de compilación y sincronización de Rojo
├── build.bat                 -- Script para recompilar el lugar
├── serve.bat                 -- Script para iniciar sincronización en tiempo real
└── src/
    ├── shared/               -- Código compartido cliente/servidor (ReplicatedStorage)
    │   ├── Types/
    │   │   └── GameTypes.luau          -- Tipos estrictos
    │   ├── Config/
    │   │   └── GameConfig.luau         -- Balance, costos de mejoras y catálogo de Auras
    │   └── Utils/
    │       └── FormatNumber.luau       -- Formateador compacto (1K, 1M, 1B...)
    ├── server/               -- Lógica autoritativa del servidor (ServerScriptService)
    │   ├── ServerInit.server.luau      -- Bootstrap del servidor y enlaces de red
    │   └── Services/
    │       ├── DataService.luau        -- Perfiles de sesión y persistencia
    │       ├── ReactorService.luau     -- Cálculos de clicks, mejoras y tiradas RNG
    │       └── AuraService.luau        -- Partículas y títulos 3D sobre el personaje
    └── client/               -- Lógica del jugador e interfaces (StarterPlayerScripts)
        ├── ClientInit.client.luau      -- Bootstrap del cliente y escucha de red
        └── Controllers/
            ├── ReactorController.luau  -- Squash & stretch del núcleo, popups y clics
            └── UIController.luau       -- HUD procedural animado, barra de sobrecarga y tienda
```

---

## 🎮 Mecánicas Virales Implementadas

1. **Bucle de Jugabilidad Inmediato (<30 segundos):**
   * Núcleo interactivo con física de rebote (*Squash & Stretch*).
   * Números flotantes animados (`+1 Energía`, `+5 Energía`) que saltan al hacer clic.
2. **Sistema de Sobrecarga (RNG Gacha & Flex Social):**
   * Cada clic llena la barra de sobrecarga circular.
   * Al llegar al 100%, ocurre una sobrecarga: explosión masiva de energía y tirada de Aura.
   * **Auras en el Personaje:** Al desbloquear un Aura (ej: *Chispa Cinética*, *Sobrecarga Azul*, *Plasma Neón*, *Singularidad del Vacío*, *Supernova Legendaria*), el jugador recibe un título flotante luminoso sobre su cabeza y partículas activas que los demás jugadores pueden ver y admirar.
3. **Tienda de Mejoras Integrada:**
   * **Turbina de Inducción:** Multiplica la energía por clic.
   * **Extractor Automatizado:** Generación pasiva continua de energía por segundo.
   * **Condensador de Flujo:** Aumenta la velocidad de llenado de la barra de sobrecarga.
   * **Amplificador de Resonancia:** Aumenta la suerte para sacar Auras legendarias (1 en 15,000).
4. **Anuncios Globales:**
   * Cuando un jugador saca un Aura de alta rareza, todo el servidor recibe un anuncio animado en pantalla para desatar la competitividad y la envidia sana.
