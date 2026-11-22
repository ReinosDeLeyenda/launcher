\# ❄️ Reinos de Leyenda — Launcher Oficial (WoW 3.3.5a)



Launcher de escritorio desarrollado en Python con estética \*\*azul hielo\*\* diseñado específicamente para \*\*World of Warcraft: Wrath of the Lich King (3.3.5a)\*\* en el servidor privado \*\*Reinos de Leyenda\*\*.



\---



\## ✨ Características Principales



\* \*\*📰 Noticias en Tiempo Real:\*\* Obtiene y muestra automáticamente las últimas actualizaciones y anuncios desde \[reinosdeleyenda.org](https://reinosdeleyenda.org) con acceso directo en el navegador.

\* \*\*🧩 Gestor Inteligente de Addons (GitHub):\*\*

&#x20; \* Muestra al instante tus addons instalados localmente mientras busca actualizaciones en segundo plano.

&#x20; \* Indicador visual dinámico en la cabecera (\*\*verde\*\* si todo está al día, \*\*naranja\*\* si hay actualizaciones disponibles y rueda giratoria mientras comprueba).

&#x20; \* Agrupación automática de paquetes multi-módulo (como `DataStore` o `Prat-3.0`) para instalarlos o actualizarlos con un solo clic.

&#x20; \* Ordenación por prioridad: \*\*Actualizar\*\* ➔ \*\*Instalar\*\* (según el orden de repositorios) ➔ \*\*Reinstalar\*\* ➔ \*\*Locales\*\*.

&#x20; \* Soporte para múltiples repositorios de GitHub configurables mediante archivo `.ini`.

\* \*\*⚙️ Herramientas y Ajustes Integrados:\*\*

&#x20; \* Selector de carpeta de instalación de World of Warcraft.

&#x20; \* Limpieza rápida de la carpeta `Cache` con un clic.

&#x20; \* Editor integrado de `realmlist.wtf` con restauración rápida a `set realmlist wow.reinosdeleyenda.org`.

\* \*\*📥 Bandeja del Sistema (System Tray):\*\* Minimización automática a la bandeja del sistema al cerrar la ventana (`X`), con menú rápido para abrir el launcher o iniciar el juego.

\* \*\*📝 Registro de Diagnóstico (`launcher.log`):\*\* Log con marca de tiempo que se reinicia automáticamente en cada sesión.



\---



\## 📂 Estructura del Proyecto



```text

RDL\_Launcher/

├── main.py              # Ventana principal e interfaz gráfica azul hielo

├── launcher\_actions.py  # Controlador de hilos en segundo plano y System Tray

├── config.py            # Gestión de rdl\_launcher.ini, logs y paleta de colores

├── news\_service.py      # Obtención de noticias de WordPress y carga del logotipo

├── addon\_service.py     # Escaneo local, agrupación de módulos y descarga desde GitHub

├── addons\_dialog.py     # Ventana modal del gestor de addons

├── settings\_dialog.py   # Ventana de ajustes, caché, realmlist y repositorios

├── ui\_widgets.py        # Componentes reutilizables de tarjetas de noticias

├── tray\_service.py      # Integración con la bandeja del sistema

└── logo.png             # Logotipo oficial del servidor

```



\---



\## 🚀 Instalación y Ejecución



\### 1. Requisitos

\* \*\*Python 3.10+\*\*

\* Dependencias externas:

&#x20; ```bash

&#x20; pip install requests beautifulsoup4 pillow pystray

&#x20; ```



\### 2. Ejecutar desde el código fuente

1\. Clona o descarga este repositorio.

2\. Asegúrate de incluir el archivo `logo.png` en la carpeta raíz del launcher.

3\. Ejecuta:

&#x20;  ```bash

&#x20;  python main.py

&#x20;  ```



\---



\## 📦 Compilar a Ejecutable (`.exe`)



Si deseas distribuir el launcher a otros jugadores sin que necesiten tener Python instalado, puedes empaquetarlo en un único ejecutable con \*\*PyInstaller\*\*:



```bash

pip install pyinstaller

pyinstaller --noconsole --onefile --name "RDL\_Launcher" --add-data "logo.png;." main.py

```



El ejecutable final se generará dentro de la carpeta `dist/RDL\_Launcher.exe`. \*(Recuerda colocar una copia de `logo.png` junto al `.exe` si deseas que también lo cargue el icono del System Tray).\*



\---



\## ⚙️ Configuración (`rdl\_launcher.ini`)



Al iniciar el launcher por primera vez, se creará automáticamente el archivo `rdl\_launcher.ini` junto al programa:



```ini

\[General]

wow\_dir = C:\\Juegos\\World of Warcraft 3.3.5a

minimize\_to\_tray = True



\[Addons]

repos = https://github.com

```



Puedes añadir más repositorios de GitHub (uno por línea) directamente desde el botón \*\*⚙ Ajustes\*\* dentro del launcher.



