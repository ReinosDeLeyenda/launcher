# Reinos de Leyenda — Launcher Oficial (WoW 3.3.5a)

Launcher de escritorio desarrollado en Python con estética **azul hielo** diseñado específicamente para **World of Warcraft: Wrath of the Lich King (3.3.5a)** en el servidor privado **Reinos de Leyenda**.

---

## Características Principales

* **Noticias en Tiempo Real:** Obtiene y muestra automáticamente las últimas actualizaciones y anuncios desde [reinosdeleyenda.org](https://reinosdeleyenda.org) con acceso directo en el navegador.
* **Gestor Inteligente de Addons (GitHub):**
  * Muestra al instante tus addons instalados localmente mientras busca actualizaciones en segundo plano.
  * **Caché por último commit (`addons_cache.json`):** Comprueba el SHA del último commit de cada repositorio para ahorrar ancho de banda y cargar al instante si no hay cambios.
  * Indicador visual dinámico en la cabecera (**verde** si todo está al día, **naranja** si hay actualizaciones disponibles y rueda giratoria mientras comprueba).
  * Agrupación automática de paquetes multi-módulo (como `DataStore` o `Prat-3.0`) para instalarlos o actualizarlos con un solo clic.
  * Ordenación por prioridad: **Actualizar** -> **Instalar** (según el orden de repositorios) -> **Reinstalar** -> **Locales**.
  * Soporte para múltiples repositorios de GitHub configurables mediante archivo `.ini`.
* **Gestor de Cuentas y Auto-Login:**
  * Selector desplegable en la cabecera para elegir rápidamente la cuenta con la que iniciar sesión o entrar en modo manual.
  * Configuración automática de `SET accountName` en `WTF\Config.wtf` y envío de contraseña al cliente.
* **Herramientas y Ajustes Integrados:**
  * Selector de carpeta de instalación de World of Warcraft.
  * Limpieza rápida de la carpeta `Cache` con un clic.
  * Editor integrado de `realmlist.wtf` con restauración rápida a `set realmlist wow.reinosdeleyenda.org`.
* **Bandeja del Sistema (System Tray):** Minimización automática a la bandeja del sistema al cerrar la ventana (`X`), con menú rápido para abrir el launcher o iniciar el juego.
* **Registro de Diagnóstico (`launcher.log`):** Log con marca de tiempo que se reinicia automáticamente en cada sesión.

---

## Estructura del Proyecto

```text
RDL_Launcher/
├── main.py              # Ventana principal e interfaz gráfica azul hielo
├── launcher_actions.py  # Controlador de hilos en segundo plano, auto-login y System Tray
├── config.py            # Gestión de rdl_launcher.ini, logs y paleta de colores
├── news_service.py      # Obtención de noticias de WordPress y carga del logotipo
├── addon_service.py     # Escaneo local, caché por commit, agrupación y descarga desde GitHub
├── addons_dialog.py     # Ventana modal del gestor de addons
├── accounts_dialog.py   # Ventana modal del gestor de cuentas de usuario
├── settings_dialog.py   # Ventana de ajustes, caché, realmlist y repositorios
├── ui_widgets.py        # Componentes reutilizables de tarjetas de noticias
├── tray_service.py      # Integración con la bandeja del sistema
├── .gitignore           # Exclusión de credenciales, caché y temporales
└── logo.png             # Logotipo oficial del servidor
```

---

## Instalación y Ejecución

### 1. Requisitos
* **Python 3.10+**
* Dependencias externas:

```bash
pip install requests beautifulsoup4 pillow pystray
```

### 2. Ejecutar desde el código fuente
1. Clona o descarga este repositorio.
2. Asegúrate de incluir el archivo `logo.png` en la carpeta raíz del launcher.
3. Ejecuta:

```bash
python main.py
```

---

## Compilar a Ejecutable (`.exe`)

Para distribuir el launcher a otros jugadores sin que necesiten tener Python instalado, puedes empaquetarlo en un único ejecutable con **PyInstaller**:

```bash
pip install pyinstaller
pyinstaller --noconsole --onefile --name "RDL_Launcher" --add-data "logo.png;." main.py
```

El ejecutable final se generará dentro de la carpeta `dist/RDL_Launcher.exe`. *(Coloca una copia de `logo.png` junto al `.exe` si deseas que también lo cargue el icono del System Tray).*

---

## Configuración (`rdl_launcher.ini`)

Al iniciar el launcher por primera vez, se creará automáticamente el archivo `rdl_launcher.ini` junto al programa:

```ini
[General]
wow_dir = C:\Juegos\World of Warcraft 3.3.5a
minimize_to_tray = True
active_account = 

[Addons]
repos = https://github.com
```

Puedes añadir más repositorios de GitHub (uno por línea) o gestionar tus cuentas directamente desde el botón **Ajustes** dentro del launcher.
