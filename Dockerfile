# --- Etapa 1: Compilación ---
FROM dart:stable AS build

WORKDIR /app

# Copiamos primero los archivos de dependencias para aprovechar la caché de Docker
COPY pubspec.* ./
RUN dart pub get

# Copiamos el resto del código
COPY . .

# Instalamos el CLI de Dart Frog y compilamos la aplicación
RUN dart pub global activate dart_frog_cli
ENV PATH="/root/.pub-cache/bin:${PATH}"
RUN dart_frog build

# Compilamos el servidor generado a un ejecutable nativo
RUN dart compile exe build/bin/server.dart -o build/bin/server


# --- Etapa 2: Ejecución (Imagen final ligera) ---
FROM scratch

# Copiamos el ejecutable compilado desde la etapa de compilación
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server

# Exponemos el puerto (Railway inyectará la variable PORT)
EXPOSE 8080

# Comando para iniciar el servidor
CMD ["/app/bin/server"]