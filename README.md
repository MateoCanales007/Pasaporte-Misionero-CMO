# 🛂 Pasaporte Misionero Virtual - CMO

**Centro Misionero Oasis (CMO)**

Aplicación móvil para centralizar los logros y el historial de participación misionera. Funciona como una bitácora de intercesión digital donde los usuarios coleccionan sellos al escanear códigos QR durante los cultos, fomentando la constancia y el compromiso espiritual.

## Tecnologías y Arquitectura
* **Frontend:** Flutter (Dart)
* **Backend:** Firebase (Authentication y Cloud Firestore NoSQL)
* **Arquitectura:** Clean Architecture
* **Características Clave:** * Escaneo QR rápido mediante Google ML Kit (`mobile_scanner`).
  * Persistencia de datos y funcionamiento **Offline-First** (ideal para zonas sin cobertura Wi-Fi en la iglesia).

---

## Guía (VS Code)

Sigue estos pasos para configurar tu entorno local y levantar el proyecto en tu máquina.

### 1. Instalar el SDK de Flutter
1. Ve a la [página oficial de Flutter](https://docs.flutter.dev/get-started/install) y descarga la versión para Windows (Elige la opción "Custom Setup" bajando el `.zip`).
2. Crea una carpeta llamada `develop` en tu directorio de usuario (ej. `C:\Users\tu_usuario\develop`).
3. Extrae el contenido del `.zip` dentro de esa carpeta. La ruta final debe quedar como `C:\Users\tu_usuario\develop\flutter`.

### 2. Configurar Variables de Entorno (PATH)
Para que tu terminal reconozca a Flutter:
1. En Windows, busca **"Variables de entorno"** en el menú de inicio y selecciona "Editar las variables de entorno del sistema".
2. Haz clic en "Variables de entorno...".
3. En la lista, busca la variable `Path` y haz doble clic sobre ella.
4. Añade una **Nueva** entrada apuntando a la carpeta `bin` del SDK: 
   `C:\Users\tu_usuario\develop\flutter\bin`
5. Acepta y cierra. **Reinicia tu computadora** para aplicar los cambios.

### 3. Preparar Visual Studio Code
1. Abre Visual Studio Code.
2. Ve a la pestaña de **Extensiones** (`Ctrl+Shift+X`).
3. Busca e instala la extensión oficial de **Flutter** (esto instalará Dart automáticamente).

### 4. Clonar el Repositorio
1. En VS Code, abre una terminal integrada (`Terminal > New Terminal`).
2. Crea una carpeta para tus aplicaciones y entra en ella:
   ```bash
   mkdir C:\Users\tu_usuario\develop\apps
   cd C:\Users\tu_usuario\develop\apps
   
A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
