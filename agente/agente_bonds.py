"""
=================================================================
  Agente de IA para Bonds  —  Matchmaker de artistas
=================================================================
Qué hace este programa, en orden:

  1. Lee los usuarios desde 'usuarios_ejemplo.json'.
  2. Para un usuario objetivo, busca CANDIDATOS comparando sus tags
     (esto es matemática simple, NO usa IA: es gratis y rápido).
    3. Le pasa esos candidatos a Gemini (la IA), que redacta una
     sugerencia natural para cada match: colaborar, iniciar una
     conversación, o explorar/comprar su arte.

Necesitas:
  - Python 3.9 o superior
    - La librería de Google Gen AI:  pip install google-genai
    - Una API key en la variable de entorno GEMINI_API_KEY
=================================================================
"""

import json
import os
from google import genai
from google.genai import types

# ---------------------------------------------------------------
# CONFIGURACIÓN (editable)
# ---------------------------------------------------------------
MODELO = "gemini-2.5-flash"
ARCHIVO_USUARIOS = "usuarios_ejemplo.json"
MAX_MATCHES = 3              # cuántas sugerencias devolver como máximo

# Diccionario de tags que se COMPLEMENTAN (no son iguales, pero juntos crean algo).
# EDITABLE: agrega aquí pares de disciplinas que tengan sentido colaborar.
COMPLEMENTOS = {
    "ilustracion": ["escritura", "musica", "animacion"],
    "escritura": ["ilustracion", "musica", "guion"],
    "musica": ["animacion", "video", "escritura"],
    "animacion": ["musica", "guion", "concept-art"],
    "fotografia": ["edicion", "diseno-digital"],
}


# ---------------------------------------------------------------
# PASO 1: cargar usuarios
# ---------------------------------------------------------------
def cargar_usuarios(ruta):
    with open(ruta, "r", encoding="utf-8") as f:
        datos = json.load(f)
    return datos["usuarios"]


# ---------------------------------------------------------------
# PASO 2: buscar candidatos comparando tags (sin IA)
# ---------------------------------------------------------------
def calcular_afinidad(usuario, otro):
    """Devuelve un puntaje: tags en común + tags que se complementan."""
    tags_a = set(usuario["tags"])
    tags_b = set(otro["tags"])

    en_comun = tags_a & tags_b                      # disciplinas iguales
    puntaje_comun = len(en_comun) * 2               # valen doble (afinidad fuerte)

    puntaje_complemento = 0
    complementos = []
    for tag in tags_a:
        for comp in COMPLEMENTOS.get(tag, []):
            if comp in tags_b:
                puntaje_complemento += 1
                complementos.append((tag, comp))

    return {
        "puntaje": puntaje_comun + puntaje_complemento,
        "en_comun": list(en_comun),
        "complementos": complementos,
    }


def buscar_candidatos(usuario, todos):
    candidatos = []
    for otro in todos:
        if otro["id"] == usuario["id"]:
            continue  # no se compara consigo mismo
        afinidad = calcular_afinidad(usuario, otro)
        if afinidad["puntaje"] > 0:
            candidatos.append({"usuario": otro, "afinidad": afinidad})
    # ordenar de mayor a menor puntaje
    candidatos.sort(key=lambda c: c["afinidad"]["puntaje"], reverse=True)
    return candidatos[:MAX_MATCHES]


# ---------------------------------------------------------------
# PASO 3: Gemini redacta las sugerencias (la parte de IA)
# ---------------------------------------------------------------
SYSTEM_PROMPT = """\
Eres el agente de recomendaciones de Bonds, una app para artistas.
Tu trabajo es conectar artistas entre sí de forma cálida y natural.

Para cada candidato que recibas, decide cuál es la MEJOR acción a sugerir:
  - "colaborar": si sus disciplinas se complementan para crear algo juntos.
  - "conversar": si comparten intereses y vale la pena que platiquen.
  - "explorar_comprar": si el otro vende arte que al usuario le interesaría.

Reglas:
  - Habla en español, en segunda persona ("te recomendamos...").
  - Sé concreto: menciona la disciplina específica que los conecta.
  - Una sola frase de "rompe hielo" lista para enviar, si aplica.
  - No inventes datos que no estén en los perfiles.
  - Tono motivador y breve, sin exagerar.
"""


def generar_sugerencias(cliente, usuario, candidatos):
    # Armamos un resumen de texto con los candidatos para dárselo a Gemini.
    lineas = [f"USUARIO OBJETIVO: {usuario['nombre']} — {usuario['bio']}",
              f"Sus disciplinas: {', '.join(usuario['tags'])}",
              "",
              "CANDIDATOS ENCONTRADOS:"]
    for c in candidatos:
        u = c["usuario"]
        af = c["afinidad"]
        lineas.append(
            f"- {u['nombre']} ({u['ciudad']}): {u['bio']} "
            f"| disciplinas: {', '.join(u['tags'])} "
            f"| vende arte: {'sí' if u['vende'] else 'no'} "
            f"| en común: {af['en_comun']} "
            f"| complementos: {af['complementos']}"
        )

    mensaje_usuario = "\n".join(lineas) + (
        "\n\nPara cada candidato, dame una recomendación con: nombre, "
        "tipo de acción (colaborar / conversar / explorar_comprar), "
        "el motivo en una frase, y una frase para romper el hielo."
    )

    respuesta = cliente.models.generate_content(
        model=MODELO,
        contents=mensaje_usuario,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=1500,
        ),
    )

    return respuesta.text or "(sin respuesta)"


# ---------------------------------------------------------------
# PROGRAMA PRINCIPAL
# ---------------------------------------------------------------
def main():
    # Verificamos que exista la API key
    if not os.environ.get("GEMINI_API_KEY"):
        print("⚠  No encontré tu API key. Ponla así (en la terminal):")
        print('     setx GEMINI_API_KEY "tu-clave-aqui"   (Windows)')
        print("   y vuelve a abrir la terminal.")
        return

    cliente = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
    usuarios = cargar_usuarios(ARCHIVO_USUARIOS)

    # EDITABLE: elige para qué usuario quieres generar matches.
    objetivo = usuarios[0]  # por defecto, el primero (Lucía)

    print(f"\n🔎 Buscando matches para: {objetivo['nombre']}\n")
    candidatos = buscar_candidatos(objetivo, usuarios)

    if not candidatos:
        print("No se encontraron candidatos con afinidad.")
        return

    print("Candidatos detectados (por tags):")
    for c in candidatos:
        print(f"  • {c['usuario']['nombre']} (afinidad: {c['afinidad']['puntaje']})")

    print("\n🤖 Pensando las recomendaciones con IA...\n")
    sugerencias = generar_sugerencias(cliente, objetivo, candidatos)
    print(sugerencias)


if __name__ == "__main__":
    main()
