"""
DEMO sin API key.
Ejecuta de verdad el Paso 1 (filtro por tags) y muestra un EJEMPLO
simulado del Paso 2 (lo que escribiría la IA), para que veas el flujo
completo sin necesidad de una clave de pago.
"""

import sys
sys.stdout.reconfigure(encoding="utf-8")  # para que Windows muestre bien acentos y símbolos

from agente_bonds import cargar_usuarios, buscar_candidatos, ARCHIVO_USUARIOS

usuarios = cargar_usuarios(ARCHIVO_USUARIOS)
objetivo = usuarios[0]  # Lucía

print("=" * 60)
print(f"  PASO 1 (REAL) — Matches para: {objetivo['nombre']}")
print(f"  Disciplinas: {', '.join(objetivo['tags'])}")
print("=" * 60)

candidatos = buscar_candidatos(objetivo, usuarios)
for c in candidatos:
    u = c["usuario"]
    af = c["afinidad"]
    print(f"\n• {u['nombre']} ({u['ciudad']})  —  afinidad: {af['puntaje']}")
    print(f"    en común:     {af['en_comun'] or 'ninguno'}")
    print(f"    complementos: {af['complementos'] or 'ninguno'}")

print("\n" + "=" * 60)
print("  PASO 2 (EJEMPLO SIMULADO) — Lo que escribiría la IA")
print("=" * 60)
print("""
1) Marco Díaz  →  ACCIÓN: colaborar
   Motivo: Tú ilustras y Marco escribe fantasía; juntos podrían
   crear un libro ilustrado o una portada para sus cuentos.
   Rompe el hielo: "Hola Marco, me encanta la fantasía. ¿Te late
   que ilustre uno de tus cuentos?"

2) Diego Herrera  →  ACCIÓN: colaborar
   Motivo: Comparten concept-art y diseño digital; tus ilustraciones
   podrían cobrar vida en sus animaciones 2D.
   Rompe el hielo: "Hola Diego, vi tu motion graphics. ¿Animamos
   juntos uno de mis personajes?"

3) Diego Herrera  →  ACCIÓN: explorar_comprar
   Motivo: Diego vende su trabajo; vale la pena revisar su perfil
   para inspirarte o adquirir alguna pieza.
""")
print("(Este texto es un EJEMPLO. Con tu API key, la IA lo genera en vivo.)")
