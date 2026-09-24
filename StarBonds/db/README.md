# Base de datos de Bonds (Supabase / PostgreSQL)

Esta carpeta contiene el esquema de la base de datos para la app **Bonds**.

## Archivos

| Archivo | Qué hace |
|---|---|
| `schema.sql` | Crea todas las tablas, contadores automáticos (triggers), la función de match y la seguridad (RLS). |
| `seed.sql` | Carga datos de ejemplo: disciplinas, 5 artistas, posts, follows, productos y una venta. |

## Cómo montarla en Supabase

1. Entra a tu proyecto en [supabase.com](https://supabase.com) → **SQL Editor** → **New query**.
2. Pega el contenido de **`schema.sql`** y pulsa **Run**.
3. Abre otra query, pega **`seed.sql`** y pulsa **Run** (opcional, solo datos demo).
4. Comprueba:
   ```sql
   select username, posts_count, followers_count, obras_vendidas from profiles;
   ```

## Qué guarda (resumen)

- **profiles** — todos los datos del usuario: nombre, usuario, foto, bio, ubicación, y
  contadores que se actualizan solos: `posts_count`, `collabs_count`, `followers_count`,
  `following_count`, `likes_received`, **`obras_vendidas`** y `ventas_totales`.
- **disciplines** + **profile_disciplines** — el catálogo de disciplinas y los **tags**
  de cada artista (lo que se usa para el match).
- **discipline_complements** — qué disciplinas se complementan (para sugerir collabs).
- **posts**, **comments**, **likes**, **follows** — la red social.
- **collabs** — colaboraciones entre artistas y su estado.
- **products**, **orders**, **order_items** — el marketplace y las ventas.
- **messages** — el chat directo.
- **notifications** — alimenta la página de Actividad (likes, follows, collabs, ventas).

## Contadores automáticos

No tienes que actualizar los números a mano. Por ejemplo:
- Insertar un `like` sube `posts.likes_count` y `profiles.likes_received`.
- Insertar un `follow` ajusta `followers_count` y `following_count`.
- Marcar una orden como `pagado` suma `obras_vendidas`, `ventas_totales` y `products.sales_count`,
  y crea una notificación de venta.

## Match entre artistas

La función `artist_matches(uuid)` replica la lógica del agente de Python
(disciplinas iguales valen 2, las complementarias suman su `weight`):

```sql
-- top 10 de artistas afines a Noa
select * from artist_matches(
  (select id from profiles where username = 'noa.writes'), 10
);
```

Devuelve cada candidato con su `score`, las disciplinas `shared` (en común) y
`complementary` (que se complementan). El [agente de IA](../agente/) puede tomar
ese resultado y redactar la sugerencia final en lenguaje natural.

## Cómo lo usa el front-end

La app de [/app](../app/) hoy usa datos de ejemplo en `app.js` con `localStorage`.
Para conectarla a esta base de datos:

1. Crea el proyecto en Supabase y ejecuta `schema.sql`.
2. Añade el cliente de Supabase a las páginas:
   ```html
   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
   <script>
     const supabase = supabase.createClient('TU_URL', 'TU_ANON_KEY');
   </script>
   ```
3. Reemplaza las funciones de `app.js` (publicar, like, follow, carrito…) por
   llamadas a Supabase, por ejemplo:
   ```js
   // publicar un post
   await supabase.from('posts').insert({ content, media_emoji });
   // dar follow
   await supabase.from('follows').insert({ following_id: otroId });
   // login con Google
   await supabase.auth.signInWithOAuth({ provider: 'google' });
   ```

Las políticas RLS ya garantizan que cada quien solo pueda editar lo suyo.
