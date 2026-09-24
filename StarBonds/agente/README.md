# Agente de IA para Bonds — Matchmaker de artistas

Este agente conecta artistas entre sí basándose en sus **tags** (disciplinas)
y genera sugerencias para **colaborar**, **iniciar una conversación** o
**explorar y comprar** el arte de otro usuario.

## Cómo funciona (2 pasos)

1. **Filtro por tags (sin IA):** compara las disciplinas de los artistas y
   calcula una afinidad. Las disciplinas iguales valen más; también detecta
   disciplinas que se *complementan* (ej. ilustración + escritura).
2. **Redacción con IA (Gemini):** toma los candidatos y escribe la sugerencia
   final en lenguaje natural y persuasivo.

## Cómo probarlo paso a paso

1. **Instala Python** (python.org) si no lo tienes.
2. Abre una terminal en esta carpeta e instala la librería:
   ```
   pip install -r requirements.txt
   ```
3. Consigue una **API key gratuita** en https://aistudio.google.com/app/apikey y configúrala:
   ```
   setx GEMINI_API_KEY "tu-clave-aqui"
   ```
   (cierra y vuelve a abrir la terminal después de esto)
4. Ejecuta:
   ```
   python agente_bonds.py
   ```

## Qué puedes editar

- **`usuarios_ejemplo.json`** → los artistas y sus tags.
- En `agente_bonds.py`:
  - `COMPLEMENTOS` → qué disciplinas se complementan entre sí.
  - `objetivo` (en la función `main`) → para qué usuario generar matches.
  - `SYSTEM_PROMPT` → la personalidad e instrucciones del agente.

## Nota sobre costos

Gemini ofrece una cuota gratuita, sujeta a los límites vigentes de Google. El
paso 1 (filtro por tags) siempre es gratis; solo el paso 2 (redacción) consume
la API. Para conectarlo a la app real, este código se integraría en tu servidor.
