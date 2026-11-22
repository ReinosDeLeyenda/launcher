# Reinos de Leyenda — Launcher Oficial (WoW 3.3.5a)

Launcher de escritorio desarrollado en Python con estética **azul hielo** diseñado específicamente para **World of Warcraft: Wrath of the Lich King (3.3.5a)** en el servidor privado **Reinos de Leyenda**.

---

## Características Principales

* **Noticias en Tiempo Real:** Obtiene y muestra automáticamente las últimas actualizaciones y anuncios desde [reinosdeleyenda.org](https://reinosdeleyenda.org) con acceso directo en el navegador.
* **Soporte Multi-Cliente (WoW 3.3.5a):**
  * Configura y gestiona múltiples instalaciones de WoW desde **Ajustes** (por ejemplo: *3.3.5a enUS Standard*, *3.3.5a enUS HD*, *3.3.5a esES Standard*).
  * Selector desplegable rápido justo encima de **Jugar Ahora** para cambiar de cliente al instante.
  * Detección automática y aviso visual si falta `Wow.exe` en el cliente seleccionado.
* **Gestor Inteligente de Addons (GitHub):**
  * Muestra al instante tus addons instalados localmente en el cliente activo mientras busca actualizaciones en segundo plano.
  * **Caché por último commit (`addons_cache.json`):** Comprueba el último commit de cada repositorio (mediante Atom/HTML sin sufrir límites de la API) para ahorrar ancho de banda y cargar al instante si no hay cambios.
  * Descarga paralela de archivos `.toc` y agrupación automática de paquetes multi-módulo (como `DataStore` o `Prat-3.0`) para instalarlos o actualizarlos con un solo clic.
  * Indicador visual dinámico en la cabecera (**verde** si todo está al día, **naranja** si hay actualizaciones disponibles y rueda giratoria mientras comprueba).
  * Ordenación por prioridad: **Actualizar** -> **Instalar** (según el orden de repositorios) -> **Reinstalar** -> **Locales**.
* **Gestor de Cuentas y Auto-Login Seguro (Windows DPAPI):**
  * Desplegable rápido en la cabecera para elegir con qué cuenta iniciar sesión o entrar en modo manual.
  * Almacenamiento cifrado mediante **Windows DPAPI** (`CryptProtectData`), vinculando las contraseñas localmente a la sesión de Windows del usuario y descifrándolas únicamente en memoria al enviarlas a `Wow.exe`.
  * Configuración automática de `SET accountName` en `WTF\Config.wtf` e ingreso automático mediante `PostMessageW`.
* **Herramientas y Ajustes Integrados:**
  * Limpieza rápida de la carpeta `Cache` del cliente seleccionado con un clic.
  * Editor integrado de `realmlist.wtf` con restauración rápida a `set realmlist wow.reinosdeleyenda.org`.
* **Auto-Actualizador del Launcher:** Comprueba nuevas versiones en [GitHub Releases](https://github.com) y permite descargar y reemplazar el ejecutable con un clic.
* **Bandeja del Sistema (System Tray):** Minimización automática a la bandeja del sistema al cerrar la ventana (`X`), con menú rápido para abrir el launcher o iniciar el juego.
* **Registro de Diagnóstico (`launcher.log`):** Log con marca de tiempo que se reinicia automáticamente en cada sesión.

---

## Estructura del Proyecto

```text
RDL_Launcher/
├── main.py              # Ventana principal e interfaz gráfica azul hielo
├── launcher_actions.py  # Controlador de hilos, auto-login, updates y System Tray
├── config.py            # Gestión de rdl_launcher.ini, clientes, logs y tema
├── dpapi_crypto.py      # Cifrado y descifrado nativo de contraseñas con Windows DPAPI
├── news_service.py      # Obtención de noticias de WordPress y carga del logotipo
├── addon_service.py     # Escaneo local, caché por commit, agrupación y descarga
├── addons_dialog.py     # Ventana modal del gestor de addons
├── accounts_dialog.py   # Ventana modal del gestor de cuentas de usuario
├── settings_dialog.py   # Ventana de ajustes, perfiles de cliente, caché y realmlist
├── updater_service.py   # Comprobación y actualización automática desde GitHub Releases
├── ui_widgets.py        # Componentes reutilizables de tarjetas de noticias
├── tray_service.py      # Integración con la bandeja del sistema
├── .gitignore           # Exclusión de credenciales, caché y temporales
└── logo.png             # Logotipo oficial del servidor
```

---

## Instalación y Ejecución

### 1. Requisitos
* **Windows** (requerido para DPAPI y automatización de ventana de WoW) y **Python 3.10+**
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

Para distribuir el launcher en un único archivo ejecutable sin consola usando **PyInstaller**:

```powershell
python -m pip install pyinstaller
Remove-Item -Recurse -Force build, dist, RDL_Launcher.spec -ErrorAction SilentlyContinue
python -m PyInstaller --clean --noconsole --onefile --name "RDL_Launcher" --add-data "logo.png;." main.py
```

El ejecutable final se generará en `dist\RDL_Launcher.exe`.
