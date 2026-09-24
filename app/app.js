/* ============================================================
   StarBonds · Bonds — Lógica compartida de la app (sin servidor)
   Usa datos de ejemplo y localStorage para simular interacción.
   Cuando conectes un backend, reemplaza estas funciones por
   llamadas a tu API.
   ============================================================ */

const supabaseUrl = "https://wwhnfchmsqxzlkcmyoex.supabase.co";
const supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind3aG5mY2htc3F4emxrY215b2V4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MTQzOTQsImV4cCI6MjEwMTI5MDM5NH0.D7B_6nk5D-vLAslyR5WTlnSqR8R4P_8-_AE_y_WawvI";
let supabaseClient = null;
try {
  if (typeof supabase !== "undefined" && supabase?.createClient) {
    supabaseClient = supabase.createClient(supabaseUrl, supabaseKey);
  }
} catch (err) {
  console.warn("No se pudo inicializar Supabase:", err);
}
if (!supabaseClient) {
  console.warn("Supabase no está disponible. La app usará datos locales de ejemplo.");
}

/* ---------------- Datos de ejemplo ---------------- */
const USUARIO_ACTUAL = {
  id: "yo",
  nombre: "Artista",
  usuario: "",
  inicial: "A",
  emoji: "🎨",
  bio: "",
  tags: [],
  seguidores: 0,
  seguidos: 0,
};

const USUARIOS = {
  lia:    { id: "lia",    nombre: "Lía Moreno",    usuario: "@lia.draws",   emoji: "🖌️", tags: ["Ilustración", "Cómic", "Acuarela"],      seguidores: 1240, seguidos: 312, bio: "Ilustradora freelance. Acepto comisiones de personajes y portadas." },
  marco:  { id: "marco",  nombre: "Marco Ruiz",    usuario: "@marco.clay",  emoji: "🗿", tags: ["Escultura", "Cerámica", "3D"],          seguidores: 860,  seguidos: 145, bio: "Escultor en barro y resina. Piezas únicas hechas a mano." },
  sofia:  { id: "sofia",  nombre: "Sofía Vega",    usuario: "@sofivega",    emoji: "🎻", tags: ["Música", "Composición", "Violín"],      seguidores: 2030, seguidos: 410, bio: "Compositora y violinista. Hago bandas sonoras para tus proyectos." },
  dani:   { id: "dani",   nombre: "Dani Cruz",     usuario: "@danicruz",    emoji: "📷", tags: ["Fotografía", "Edición", "Cine"],        seguidores: 540,  seguidos: 220, bio: "Fotógrafo de retrato y calle. La luz lo es todo." },
  noa:    { id: "noa",    nombre: "Noa Pérez",     usuario: "@noa.writes",  emoji: "✍️", tags: ["Escritura", "Poesía", "Guion"],         seguidores: 690,  seguidos: 198, bio: "Escritora. Busco ilustradores para un libro de poemas." },
};

const COMPLEMENTOS = {
  ilustracion: ["escritura", "musica", "comic", "narrativa", "guion"],
  escritura: ["ilustracion", "poesia", "guion", "comic", "narrativa"],
  musica: ["ilustracion", "composicion", "fotografia", "cine"],
  composicion: ["musica", "fotografia", "cine"],
  escultura: ["ceramica", "fotografia", "3d", "diseno"],
  ceramica: ["escultura", "ilustracion", "diseno"],
  fotografia: ["musica", "edicion", "cine", "diseno"],
  edicion: ["fotografia", "cine", "diseno", "ilustracion"],
  cine: ["fotografia", "edicion", "guion", "musica"],
  guion: ["escritura", "ilustracion", "cine", "narrativa"],
  poesia: ["escritura", "musica", "ilustracion"],
  comic: ["ilustracion", "escritura", "guion", "narrativa"],
  narrativa: ["escritura", "ilustracion", "comic", "guion"],
  "3d": ["escultura", "ilustracion", "ceramica"],
  diseno: ["ilustracion", "fotografia", "edicion"],
};

function normalizarTag(tag = "") {
  return String(tag)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[\s_\-+/]+/g, "-")
    .replace(/[^a-z0-9-]/g, "")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function perfilParaMatching() {
  const perfil = perfilActual();
  const tags = Array.isArray(perfil.tags) ? perfil.tags.filter(Boolean) : [];
  return {
    id: perfil.id || "yo",
    nombre: perfil.nombre || "Artista",
    usuario: perfil.usuario || "@artista",
    bio: perfil.bio || "",
    tags,
  };
}

function calcularAfinidad(usuario, otro) {
  const tagsA = new Set((usuario.tags || []).map(normalizarTag).filter(Boolean));
  const tagsB = new Set((otro.tags || []).map(normalizarTag).filter(Boolean));

  const enComun = [...tagsA].filter((tag) => tagsB.has(tag));
  let puntaje = enComun.length * 2;
  const complementos = [];

  for (const tag of tagsA) {
    for (const comp of COMPLEMENTOS[tag] || []) {
      if (tagsB.has(comp)) {
        puntaje += 1;
        complementos.push([tag, comp]);
      }
    }
  }

  return {
    puntaje,
    en_comun: enComun,
    complementos,
  };
}

function buscarCandidatos(usuario, todos) {
  const candidatos = [];
  for (const otro of todos) {
    if ((otro.id || otro.usuario) === (usuario.id || usuario.usuario)) continue;
    const afinidad = calcularAfinidad(usuario, otro);
    if (afinidad.puntaje > 0) {
      candidatos.push({ usuario: otro, afinidad });
    }
  }
  return candidatos.sort((a, b) => b.afinidad.puntaje - a.afinidad.puntaje).slice(0, 3);
}

const POSTS = [
  { id: "p1", autor: "lia",   emoji: "🐉", texto: "Nuevo dragón terminado para una comisión 🐉 ¿qué les parece la paleta?", likes: 134, comentarios: 22, tiempo: "hace 2 h", following: true },
  { id: "p2", autor: "sofia", emoji: "🎼", texto: "Acabo de subir el demo de la banda sonora del corto. Busco un ilustrador para la portada del álbum 👀", likes: 89, comentarios: 14, tiempo: "hace 5 h", following: true },
  { id: "p3", autor: "marco", emoji: "🏺", texto: "Proceso de torneado de esta vasija. El barro tiene su propio ritmo.", likes: 203, comentarios: 31, tiempo: "hace 8 h", following: false },
  { id: "p4", autor: "dani",  emoji: "🌆", texto: "Serie de fotos nocturnas de la ciudad. Disponibles en el marketplace.", likes: 312, comentarios: 40, tiempo: "hace 12 h", following: false },
  { id: "p5", autor: "noa",   emoji: "📖", texto: "Fragmento del nuevo poemario. ¿Alguien se anima a ilustrarlo? #collab", likes: 76, comentarios: 18, tiempo: "hace 1 d", following: true },
];

const PRODUCTOS = [
  { id: "m1", titulo: "Retrato digital personalizado", disciplina: "Ilustración", autor: "lia",   emoji: "🧑‍🎨", precio: 35 },
  { id: "m2", titulo: "Escultura de cerámica artesanal", disciplina: "Escultura",  autor: "marco", emoji: "🏺", precio: 120 },
  { id: "m3", titulo: "Composición musical original",   disciplina: "Música",      autor: "sofia", emoji: "🎵", precio: 80 },
  { id: "m4", titulo: "Sesión de fotos de retrato",     disciplina: "Fotografía",  autor: "dani",  emoji: "📸", precio: 60 },
  { id: "m5", titulo: "Poema personalizado",            disciplina: "Escritura",   autor: "noa",   emoji: "📜", precio: 20 },
  { id: "m6", titulo: "Ilustración de portada de libro",disciplina: "Ilustración", autor: "lia",   emoji: "📕", precio: 90 },
  { id: "m7", titulo: "Figura escultórica en resina",   disciplina: "Escultura",   autor: "marco", emoji: "🗿", precio: 150 },
  { id: "m8", titulo: "Jingle / intro musical",         disciplina: "Música",      autor: "sofia", emoji: "🎙️", precio: 45 },
  { id: "m9", titulo: "Pack de fotos urbanas",          disciplina: "Fotografía",  autor: "dani",  emoji: "🌃", precio: 30 },
];

const ACTIVIDAD = [
  { tipo: "like",   usuario: "lia",   texto: "le dio me gusta a tu ilustración «Atardecer»", tiempo: "hace 10 min" },
  { tipo: "follow", usuario: "sofia", texto: "empezó a seguirte",                             tiempo: "hace 40 min" },
  { tipo: "collab", usuario: "noa",   texto: "te propuso una colaboración para su poemario",  tiempo: "hace 2 h" },
  { tipo: "post",   usuario: "marco", texto: "publicó una nueva escultura",                   tiempo: "hace 3 h" },
  { tipo: "like",   usuario: "dani",  texto: "le dio me gusta a tu post",                      tiempo: "hace 6 h" },
  { tipo: "post",   usuario: "sofia", texto: "publicó un nuevo demo musical",                  tiempo: "hace 9 h" },
  { tipo: "follow", usuario: "marco", texto: "empezó a seguirte",                             tiempo: "ayer" },
  { tipo: "collab", usuario: "lia",   texto: "aceptó tu colaboración de portada",             tiempo: "ayer" },
];

/* ---------------- Estado persistente ---------------- */
const Estado = {
  get(clave, def) { try { return JSON.parse(localStorage.getItem("sb_" + clave)) ?? def; } catch { return def; } },
  set(clave, val) { localStorage.setItem("sb_" + clave, JSON.stringify(val)); },
};

function perfilActual() {
  return Estado.get("perfil", {
    id: "yo",
    nombre: "Artista",
    usuario: "",
    inicial: "A",
    emoji: "🎨",
    bio: "",
    tags: [],
    seguidores: 0,
    seguidos: 0,
    email: "",
  });
}

function guardarPerfil(perfil) {
  if (!perfil || !perfil.id) return;
  const tags = Array.isArray(perfil.tags)
    ? perfil.tags
    : (Array.isArray(perfil.user_metadata?.tags) ? perfil.user_metadata.tags : []);

  Estado.set("perfil", {
    id: perfil.id,
    nombre: perfil.nombre || perfil.display_name || perfil.user_metadata?.display_name || perfil.email?.split('@')[0] || "Artista",
    usuario: perfil.usuario || perfil.username || perfil.user_metadata?.username || perfil.email?.split('@')[0] || "",
    emoji: perfil.emoji || perfil.avatar_emoji || "🎨",
    avatar_url: perfil.avatar_url || perfil.avatarUrl || perfil.avatar_url || "",
    bio: perfil.bio || perfil.profile_bio || "",
    tags,
    seguidores: perfil.seguidores ?? perfil.followers_count ?? 0,
    seguidos: perfil.seguidos ?? perfil.following_count ?? 0,
    email: perfil.email || perfil.user_metadata?.email || "",
  });
  window.dispatchEvent(new CustomEvent("perfilActualizado"));
}

/* ---------------- Utilidades de UI ---------------- */
function toast(msg) {
  let t = document.querySelector(".toast");
  if (!t) { t = document.createElement("div"); t.className = "toast"; document.body.appendChild(t); }
  t.textContent = msg;
  t.classList.add("visible");
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove("visible"), 2200);
}

async function loginWithSupabase(e) {
  e.preventDefault();
  const form = e.target;
  const panel = form.dataset.panel;

  try {
    if (panel === "login") {
      const email = form.querySelector("#email-l").value;
      const password = form.querySelector("#pass-l").value;
      const { error } = await supabaseClient.auth.signInWithPassword({ email, password });
      if (error) throw error;
      toast("Bienvenido de nuevo");
      location.href = "comunidad.html";
    } else {
      const email = form.querySelector("#email-s").value;
      const password = form.querySelector("#pass-s").value;
      const username = form.querySelector("#user-s").value;
      const nombre = form.querySelector("#nombre-s").value;
      const tags = Array.from(document.querySelectorAll("#signup-tags .tag-boton.activo"))
        .map((btn) => btn.dataset.tag)
        .filter(Boolean);
      const { data, error } = await supabaseClient.auth.signUp(
        { email, password },
        { data: { username, display_name: nombre, email, tags } }
      );
      if (error) throw error;

      if (data?.user) {
        guardarPerfil({
          id: data.user.id,
          nombre,
          usuario: username,
          email,
          avatar_emoji: "🎨",
          bio: "",
          tags,
          seguidores: 0,
          seguidos: 0,
        });
      }

      if (data?.session) {
        toast("Cuenta creada. Bienvenido");
        location.href = "comunidad.html";
      } else {
        toast("Cuenta creada. Revisa tu correo para confirmar");
        location.href = "login.html";
      }
    }
  } catch (err) {
    console.error("Supabase auth error:", err);
    toast(err.message || "Error de autenticación");
  }
}

async function crearPerfilSiNoExiste(user) {
  if (!user?.id) return null;
  const username = user.user_metadata?.username || user.email?.split("@")[0];
  const displayName = user.user_metadata?.display_name || username;
  const email = user.email;

  const { data: perfil, error: fetchError } = await supabaseClient
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  if (perfil) return perfil;

  const { data: insertedPerfil, error: insertError } = await supabaseClient
    .from("profiles")
    .insert([{ id: user.id, username, display_name: displayName, email }])
    .select()
    .single();

  if (insertError) {
    console.warn("No se pudo crear perfil automáticamente:", insertError);
    return null;
  }

  return insertedPerfil;
}

async function actualizarPerfilRemoto(perfil) {
  try {
    const { data: sessionData, error: sessionError } = await supabaseClient.auth.getSession();
    if (sessionError) {
      console.warn("No se pudo obtener sesión supabase para guardar perfil:", sessionError);
      return null;
    }
    const user = sessionData?.session?.user;
    if (!user?.id) return null;

    const updatePayload = {
      username: perfil.usuario,
      display_name: perfil.nombre,
      avatar_url: perfil.avatar_url,
      bio: perfil.bio,
      email: perfil.email,
    };

    const authUpdate = await supabaseClient.auth.updateUser({
      data: {
        username: perfil.usuario,
        display_name: perfil.nombre,
        tags: Array.isArray(perfil.tags) ? perfil.tags : [],
      },
    });

    if (authUpdate.error) {
      console.warn("Error actualizando metadata de usuario:", authUpdate.error);
    }

    const { data, error } = await supabaseClient
      .from("profiles")
      .update(updatePayload)
      .eq("id", user.id)
      .select()
      .single();

    if (error) {
      console.warn("Error actualizando perfil remoto:", error);
      return null;
    }
    return data;
  } catch (err) {
    console.warn("Error en actualizarPerfilRemoto:", err);
    return null;
  }
}

async function cargarPerfilActivo() {
  try {
    const { data: sessionData, error: sessionError } = await supabaseClient.auth.getSession();
    if (sessionError) {
      console.warn("No se pudo obtener sesión supabase:", sessionError);
      return;
    }
    const user = sessionData?.session?.user;
    if (!user) return;

    const perfil = await crearPerfilSiNoExiste(user);
    const tagsUsuario = Array.isArray(user.user_metadata?.tags) ? user.user_metadata.tags : [];

    if (perfil) {
      guardarPerfil({
        ...perfil,
        id: perfil.id || user.id,
        tags: perfil.tags || tagsUsuario,
      });
      return;
    }

    const perfilGuardado = perfilActual();
    guardarPerfil({
      id: user.id,
      nombre: perfilGuardado.nombre || user.user_metadata?.display_name || user.email?.split("@")[0] || "Artista",
      usuario: perfilGuardado.usuario || user.user_metadata?.username || user.email?.split("@")[0] || "",
      email: user.email,
      avatar_emoji: perfilGuardado.emoji || "🎨",
      bio: perfilGuardado.bio || "",
      tags: perfilGuardado.tags?.length ? perfilGuardado.tags : tagsUsuario,
      seguidores: perfilGuardado.seguidores ?? 0,
      seguidos: perfilGuardado.seguidos ?? 0,
    });
  } catch (err) {
    console.warn("Error cargando perfil activo:", err);
  }
}

async function cerrarSesion() {
  try {
    const { error } = await supabaseClient.auth.signOut();
    if (error) {
      console.warn("Error cerrando sesión:", error);
    }
  } catch (err) {
    console.warn("Supabase signOut falló:", err);
  }
  Estado.set("perfil", {});
  Estado.set("carrito", []);
  Estado.set("misPublicaciones", []);
  toast("Sesión cerrada");
  location.href = "login.html";
}

function avatarHTML(emoji, clase = "avatar-md") {
  return `<span class="avatar ${clase}">${emoji}</span>`;
}

/* Pestañas: cualquier contenedor .tabs con botones [data-tab] y
   paneles con id igual al valor de data-tab. */
function initTabs() {
  document.querySelectorAll(".tabs").forEach((grupo) => {
    const botones = grupo.querySelectorAll(".tab");
    botones.forEach((btn) => {
      btn.addEventListener("click", () => {
        const destino = btn.dataset.tab;
        botones.forEach((b) => b.classList.toggle("activo", b === btn));
        document.querySelectorAll(`[data-panel]`).forEach((p) => {
          if (p.dataset.grupo === grupo.dataset.grupo) {
            p.classList.toggle("activo", p.dataset.panel === destino);
          }
        });
      });
    });
  });
}

/* Marca el enlace activo de la barra según el archivo actual */
function marcarNav() {
  const pagina = location.pathname.split("/").pop() || "comunidad.html";
  document.querySelectorAll(".nav-links a").forEach((a) => {
    if (a.getAttribute("href") === pagina) a.classList.add("activo");
  });
}

/* Carrito del marketplace */
const Carrito = {
  items() { return Estado.get("carrito", []); },
  agregar(id) {
    const items = Carrito.items();
    if (!items.includes(id)) { items.push(id); Estado.set("carrito", items); }
    toast("Añadido al carrito 🛒");
    Carrito.actualizarBadge();
  },
  quitar(id) {
    Estado.set("carrito", Carrito.items().filter((x) => x !== id));
    Carrito.actualizarBadge();
  },
  vaciar() { Estado.set("carrito", []); Carrito.actualizarBadge(); },
  total() { return Carrito.items().reduce((s, id) => s + (PRODUCTOS.find((p) => p.id === id)?.precio || 0), 0); },
  actualizarBadge() {
    const b = document.querySelector("#cart-badge");
    if (b) { const n = Carrito.items().length; b.textContent = n; b.style.display = n ? "inline-flex" : "none"; }
  },
};

/* Inicialización común en todas las páginas */
document.addEventListener("DOMContentLoaded", () => {
  marcarNav();
  initTabs();
  Carrito.actualizarBadge();
  cargarPerfilActivo();
});
