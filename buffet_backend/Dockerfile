FROM dart:stable AS build

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .

RUN dart pub global activate dart_frog_cli
ENV PATH="/root/.pub-cache/bin:${PATH}"
RUN dart_frog build
RUN dart compile exe build/bin/server.dart -o build/bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server
EXPOSE 8080
CMD ["/app/bin/server"]