// Service worker de Firebase Cloud Messaging (avisos en web con la app cerrada).
// La configuración se obtiene de la URL reservada de Firebase Hosting para no
// duplicar claves en este archivo. Solo funciona en el sitio desplegado.
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');
importScripts('/__/firebase/init.js');

firebase.messaging();
