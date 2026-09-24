-- ============================================================
--  StarBonds · Bonds — Esquema de base de datos (PostgreSQL / Supabase)
-- ------------------------------------------------------------
--  Cómo usarlo:
--    1. En Supabase abre el proyecto → SQL Editor → New query.
--    2. Pega y ejecuta este archivo (schema.sql) primero.
--    3. Luego ejecuta seed.sql para cargar datos de ejemplo.
--
--  Convenciones:
--    - Los usuarios viven en auth.users (lo crea Supabase Auth).
--      La tabla "profiles" extiende a cada usuario con sus datos públicos.
--    - Los CONTADORES (posts_count, followers_count, obras_vendidas, etc.)
--      se mantienen solos con triggers: nunca los actualizas a mano.
--    - RLS (Row Level Security) está activado en todas las tablas.
-- ============================================================

-- Extensiones útiles
create extension if not exists "pgcrypto";   -- para gen_random_uuid()
create extension if not exists "citext";      -- texto sin distinción de mayúsculas (emails, usernames)

-- Limpieza opcional (descomenta si quieres reinstalar desde cero)
-- drop schema public cascade;
-- create schema public;


-- ============================================================
--  1. PERFILES DE USUARIO
-- ============================================================
-- Un perfil por cada usuario de auth.users.
create table if not exists profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  username          citext unique not null,
  display_name      text not null,
  email             citext,
  avatar_emoji      text default '🎨',           -- placeholder cuando no hay foto
  avatar_url        text,                          -- foto de perfil real
  cover_url         text,                          -- imagen de portada
  bio               text,
  location          text,                          -- ciudad / país
  website           text,
  is_verified       boolean not null default false,
  accepts_collabs   boolean not null default true, -- ¿abierto a colaboraciones?
  sells_art         boolean not null default false,-- ¿vende en el marketplace?

  -- Contadores denormalizados (mantenidos por triggers)
  posts_count       integer not null default 0,
  collabs_count     integer not null default 0,
  followers_count   integer not null default 0,
  following_count   integer not null default 0,
  likes_received    integer not null default 0,    -- total de likes en sus posts
  obras_vendidas    integer not null default 0,    -- piezas vendidas (orders pagadas)
  ventas_totales    numeric(12,2) not null default 0, -- dinero generado

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

comment on table profiles is 'Datos públicos de cada artista. Extiende auth.users.';


-- ============================================================
--  2. DISCIPLINAS (catálogo) y TAGS del usuario
-- ============================================================
-- Catálogo central de disciplinas artísticas. El "slug" se usa para el match.
create table if not exists disciplines (
  id        serial primary key,
  slug      text unique not null,        -- ej: 'ilustracion'
  name      text not null,               -- ej: 'Ilustración'
  icon      text default '✦',            -- emoji para la UI
  category  text                          -- ej: 'visual', 'sonora', 'escrita'
);

-- Tags de cada usuario: relación muchos-a-muchos perfil <-> disciplina.
-- Estos son los tags que se usan para hacer el MATCH entre artistas.
create table if not exists profile_disciplines (
  profile_id     uuid not null references profiles (id) on delete cascade,
  discipline_id  integer not null references disciplines (id) on delete cascade,
  skill_level    smallint default 3 check (skill_level between 1 and 5), -- 1 novato … 5 experto
  is_primary     boolean not null default false,                          -- disciplina principal
  primary key (profile_id, discipline_id)
);

-- Pares de disciplinas que se COMPLEMENTAN (para sugerir colaboraciones).
-- Espeja la lógica COMPLEMENTOS del agente de Python.
create table if not exists discipline_complements (
  discipline_a  integer not null references disciplines (id) on delete cascade,
  discipline_b  integer not null references disciplines (id) on delete cascade,
  weight        integer not null default 1,   -- qué tan fuerte es el complemento
  primary key (discipline_a, discipline_b),
  check (discipline_a <> discipline_b)
);


-- ============================================================
--  3. POSTS, COMENTARIOS y LIKES
-- ============================================================
create table if not exists posts (
  id              uuid primary key default gen_random_uuid(),
  author_id       uuid not null references profiles (id) on delete cascade,
  content         text not null,
  media_url       text,
  media_emoji     text,                 -- placeholder visual mientras no hay imagen
  is_collab       boolean not null default false,  -- marcado como collab
  collab_id       uuid,                            -- enlaza con tabla collabs (opcional)
  likes_count     integer not null default 0,
  comments_count  integer not null default 0,
  created_at      timestamptz not null default now()
);
create index if not exists idx_posts_author  on posts (author_id);
create index if not exists idx_posts_created on posts (created_at desc);

create table if not exists comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references posts (id) on delete cascade,
  author_id   uuid not null references profiles (id) on delete cascade,
  content     text not null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_comments_post on comments (post_id);

create table if not exists likes (
  user_id     uuid not null references profiles (id) on delete cascade,
  post_id     uuid not null references posts (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, post_id)
);


-- ============================================================
--  4. SEGUIDORES (follows)
-- ============================================================
create table if not exists follows (
  follower_id   uuid not null references profiles (id) on delete cascade,  -- quien sigue
  following_id  uuid not null references profiles (id) on delete cascade,  -- a quién sigue
  created_at    timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)   -- nadie se sigue a sí mismo
);
create index if not exists idx_follows_following on follows (following_id);


-- ============================================================
--  5. COLABORACIONES (collabs)
-- ============================================================
create table if not exists collabs (
  id            uuid primary key default gen_random_uuid(),
  initiator_id  uuid not null references profiles (id) on delete cascade,  -- quien propone
  partner_id    uuid not null references profiles (id) on delete cascade,  -- el otro artista
  title         text not null,
  description   text,
  status        text not null default 'propuesta'
                  check (status in ('propuesta', 'aceptada', 'en_curso', 'completada', 'rechazada')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (initiator_id <> partner_id)
);
create index if not exists idx_collabs_partner on collabs (partner_id);


-- ============================================================
--  6. MARKETPLACE: productos, pedidos y líneas de pedido
-- ============================================================
create table if not exists products (
  id            uuid primary key default gen_random_uuid(),
  seller_id     uuid not null references profiles (id) on delete cascade,
  discipline_id integer references disciplines (id),   -- categoría (ilustración, escultura…)
  title         text not null,
  description   text,
  image_url     text,
  image_emoji   text default '🖼️',
  price         numeric(10,2) not null check (price >= 0),
  currency      text not null default 'USD',
  is_physical   boolean not null default false,  -- ¿requiere envío?
  stock         integer,                          -- null = ilimitado (ej. comisión digital)
  is_active     boolean not null default true,
  sales_count   integer not null default 0,       -- veces vendido (mantenido por trigger)
  created_at    timestamptz not null default now()
);
create index if not exists idx_products_seller     on products (seller_id);
create index if not exists idx_products_discipline on products (discipline_id);

create table if not exists orders (
  id                uuid primary key default gen_random_uuid(),
  buyer_id          uuid not null references profiles (id) on delete restrict,
  status            text not null default 'pendiente'
                      check (status in ('pendiente', 'pagado', 'enviado', 'completado', 'cancelado')),
  subtotal          numeric(12,2) not null default 0,
  total             numeric(12,2) not null default 0,
  currency          text not null default 'USD',
  shipping_name     text,
  shipping_email    citext,
  shipping_address  text,
  created_at        timestamptz not null default now(),
  paid_at           timestamptz
);
create index if not exists idx_orders_buyer on orders (buyer_id);

create table if not exists order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references orders (id) on delete cascade,
  product_id  uuid not null references products (id) on delete restrict,
  seller_id   uuid not null references profiles (id) on delete restrict, -- denormalizado para reportes
  quantity    integer not null default 1 check (quantity > 0),
  unit_price  numeric(10,2) not null
);
create index if not exists idx_order_items_order  on order_items (order_id);
create index if not exists idx_order_items_seller on order_items (seller_id);


-- ============================================================
--  7. MENSAJES (chat directo)
-- ============================================================
create table if not exists messages (
  id            uuid primary key default gen_random_uuid(),
  sender_id     uuid not null references profiles (id) on delete cascade,
  recipient_id  uuid not null references profiles (id) on delete cascade,
  content       text not null,
  is_read       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index if not exists idx_messages_pair on messages (sender_id, recipient_id, created_at);


-- ============================================================
--  8. NOTIFICACIONES / ACTIVIDAD
-- ============================================================
-- Alimenta la página de Actividad: likes, follows, collabs, posts de seguidos.
create table if not exists notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references profiles (id) on delete cascade,  -- destinatario
  actor_id    uuid references profiles (id) on delete cascade,           -- quien generó el evento
  type        text not null check (type in ('like', 'follow', 'collab', 'post', 'comment', 'sale')),
  entity_id   uuid,                 -- id del post/collab/order relacionado
  message     text,
  is_read     boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists idx_notifications_user on notifications (user_id, created_at desc);


-- ============================================================
--  9. TRIGGERS: mantener contadores al día automáticamente
-- ============================================================

-- updated_at en profiles y collabs
create or replace function touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end; $$ language plpgsql;

drop trigger if exists trg_profiles_touch on profiles;
create trigger trg_profiles_touch before update on profiles
  for each row execute function touch_updated_at();

drop trigger if exists trg_collabs_touch on collabs;
create trigger trg_collabs_touch before update on collabs
  for each row execute function touch_updated_at();

-- ---- posts_count en el autor ----
create or replace function fn_posts_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update profiles set posts_count = posts_count + 1 where id = new.author_id;
  elsif tg_op = 'DELETE' then
    update profiles set posts_count = greatest(posts_count - 1, 0) where id = old.author_id;
  end if;
  return null;
end; $$ language plpgsql;

drop trigger if exists trg_posts_count on posts;
create trigger trg_posts_count after insert or delete on posts
  for each row execute function fn_posts_count();

-- ---- likes_count en el post + likes_received en el autor ----
create or replace function fn_likes_count() returns trigger as $$
declare v_author uuid;
begin
  if tg_op = 'INSERT' then
    update posts set likes_count = likes_count + 1 where id = new.post_id
      returning author_id into v_author;
    update profiles set likes_received = likes_received + 1 where id = v_author;
  elsif tg_op = 'DELETE' then
    update posts set likes_count = greatest(likes_count - 1, 0) where id = old.post_id
      returning author_id into v_author;
    update profiles set likes_received = greatest(likes_received - 1, 0) where id = v_author;
  end if;
  return null;
end; $$ language plpgsql;

drop trigger if exists trg_likes_count on likes;
create trigger trg_likes_count after insert or delete on likes
  for each row execute function fn_likes_count();

-- ---- comments_count en el post ----
create or replace function fn_comments_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif tg_op = 'DELETE' then
    update posts set comments_count = greatest(comments_count - 1, 0) where id = old.post_id;
  end if;
  return null;
end; $$ language plpgsql;

drop trigger if exists trg_comments_count on comments;
create trigger trg_comments_count after insert or delete on comments
  for each row execute function fn_comments_count();

-- ---- followers_count / following_count ----
create or replace function fn_follows_count() returns trigger as $$
begin
  if tg_op = 'INSERT' then
    update profiles set following_count = following_count + 1 where id = new.follower_id;
    update profiles set followers_count = followers_count + 1 where id = new.following_id;
  elsif tg_op = 'DELETE' then
    update profiles set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update profiles set followers_count = greatest(followers_count - 1, 0) where id = old.following_id;
  end if;
  return null;
end; $$ language plpgsql;

drop trigger if exists trg_follows_count on follows;
create trigger trg_follows_count after insert or delete on follows
  for each row execute function fn_follows_count();

-- ---- collabs_count (cuando una colaboración se completa) ----
create or replace function fn_collabs_count() returns trigger as $$
begin
  if new.status = 'completada' and old.status is distinct from 'completada' then
    update profiles set collabs_count = collabs_count + 1
      where id in (new.initiator_id, new.partner_id);
  elsif old.status = 'completada' and new.status is distinct from 'completada' then
    update profiles set collabs_count = greatest(collabs_count - 1, 0)
      where id in (new.initiator_id, new.partner_id);
  end if;
  return new;
end; $$ language plpgsql;

drop trigger if exists trg_collabs_count on collabs;
create trigger trg_collabs_count after update on collabs
  for each row execute function fn_collabs_count();

-- ---- obras_vendidas y ventas_totales (cuando una orden se paga) ----
-- Al pasar una orden a 'pagado', suma a cada vendedor sus piezas y dinero.
create or replace function fn_registrar_venta() returns trigger as $$
declare r record;
begin
  if new.status = 'pagado' and old.status is distinct from 'pagado' then
    new.paid_at = coalesce(new.paid_at, now());
    for r in
      select seller_id, product_id, sum(quantity) as qty, sum(quantity * unit_price) as monto
      from order_items where order_id = new.id group by seller_id, product_id
    loop
      update products set sales_count = sales_count + r.qty where id = r.product_id;
      update profiles
        set obras_vendidas = obras_vendidas + r.qty,
            ventas_totales = ventas_totales + r.monto
        where id = r.seller_id;
      -- notifica la venta al vendedor
      insert into notifications (user_id, actor_id, type, entity_id, message)
        values (r.seller_id, new.buyer_id, 'sale', new.id,
                'Vendiste ' || r.qty || ' pieza(s)');
    end loop;
  end if;
  return new;
end; $$ language plpgsql;

drop trigger if exists trg_registrar_venta on orders;
create trigger trg_registrar_venta before update on orders
  for each row execute function fn_registrar_venta();

-- ---- crear perfil automáticamente al registrarse un usuario en Auth ----
-- Toma username y nombre de los metadatos del signup (raw_user_meta_data).
create or replace function fn_nuevo_usuario() returns trigger as $$
begin
  insert into profiles (id, username, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end; $$ language plpgsql security definer;

drop trigger if exists trg_nuevo_usuario on auth.users;
create trigger trg_nuevo_usuario after insert on auth.users
  for each row execute function fn_nuevo_usuario();


-- ============================================================
-- 10. MATCH ENTRE ARTISTAS  (espeja la lógica del agente)
-- ============================================================
-- Devuelve candidatos ordenados por afinidad:
--   - cada disciplina EN COMÚN suma 2 puntos
--   - cada par COMPLEMENTARIO suma el "weight" del complemento
-- Úsala desde la app:  select * from artist_matches('<uuid>', 10);
create or replace function artist_matches(p_profile uuid, p_limit integer default 10)
returns table (
  profile_id     uuid,
  username       citext,
  display_name   text,
  avatar_emoji   text,
  score          integer,
  shared         text[],   -- disciplinas en común
  complementary  text[]    -- disciplinas que se complementan
) as $$
  with me as (
    select discipline_id from profile_disciplines where profile_id = p_profile
  ),
  -- puntos por disciplinas iguales (x2)
  comunes as (
    select pd.profile_id,
           array_agg(d.name) as shared,
           count(*) * 2 as pts
    from profile_disciplines pd
    join me on me.discipline_id = pd.discipline_id
    join disciplines d on d.id = pd.discipline_id
    where pd.profile_id <> p_profile
    group by pd.profile_id
  ),
  -- puntos por disciplinas complementarias (según discipline_complements)
  comp as (
    select pd.profile_id,
           array_agg(distinct (da.name || ' + ' || db.name)) as complementary,
           sum(dc.weight)::int as pts
    from me
    join discipline_complements dc on dc.discipline_a = me.discipline_id
    join profile_disciplines pd on pd.discipline_id = dc.discipline_b
    join disciplines da on da.id = dc.discipline_a
    join disciplines db on db.id = dc.discipline_b
    where pd.profile_id <> p_profile
    group by pd.profile_id
  ),
  candidatos as (
    select coalesce(c.profile_id, k.profile_id) as profile_id,
           coalesce(c.pts, 0) + coalesce(k.pts, 0) as score,
           coalesce(c.shared, '{}') as shared,
           coalesce(k.complementary, '{}') as complementary
    from comunes c
    full outer join comp k on k.profile_id = c.profile_id
  )
  select cd.profile_id, p.username, p.display_name, p.avatar_emoji,
         cd.score, cd.shared, cd.complementary
  from candidatos cd
  join profiles p on p.id = cd.profile_id
  where cd.score > 0
  order by cd.score desc, p.followers_count desc
  limit p_limit;
$$ language sql stable;


-- ============================================================
-- 11. VISTA: feed de actividad de la gente que sigues
-- ============================================================
create or replace view v_following_feed as
  select p.*, f.follower_id as viewer_id
  from posts p
  join follows f on f.following_id = p.author_id;


-- ============================================================
-- 12. SEGURIDAD: Row Level Security (RLS)
-- ============================================================
alter table profiles               enable row level security;
alter table disciplines            enable row level security;
alter table profile_disciplines    enable row level security;
alter table discipline_complements enable row level security;
alter table posts                  enable row level security;
alter table comments               enable row level security;
alter table likes                  enable row level security;
alter table follows                enable row level security;
alter table collabs                enable row level security;
alter table products               enable row level security;
alter table orders                 enable row level security;
alter table order_items            enable row level security;
alter table messages               enable row level security;
alter table notifications          enable row level security;

-- Catálogos: lectura pública
create policy "disciplinas visibles" on disciplines for select using (true);
create policy "complementos visibles" on discipline_complements for select using (true);

-- Perfiles: cualquiera puede ver; solo el dueño edita el suyo
create policy "perfiles visibles"  on profiles for select using (true);
create policy "edito mi perfil"    on profiles for update using (auth.uid() = id);

-- Tags de perfil: visibles para todos; solo el dueño gestiona los suyos
create policy "tags visibles"      on profile_disciplines for select using (true);
create policy "gestiono mis tags"  on profile_disciplines for all
  using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- Posts: visibles para todos; el autor crea/edita/borra los suyos
create policy "posts visibles"     on posts for select using (true);
create policy "creo mis posts"     on posts for insert with check (auth.uid() = author_id);
create policy "edito mis posts"    on posts for update using (auth.uid() = author_id);
create policy "borro mis posts"    on posts for delete using (auth.uid() = author_id);

-- Comentarios
create policy "comentarios visibles" on comments for select using (true);
create policy "comento yo"           on comments for insert with check (auth.uid() = author_id);
create policy "borro mi comentario"  on comments for delete using (auth.uid() = author_id);

-- Likes: visibles; cada quien gestiona los suyos
create policy "likes visibles"     on likes for select using (true);
create policy "doy mis likes"      on likes for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Follows: visibles; cada quien gestiona a quién sigue
create policy "follows visibles"   on follows for select using (true);
create policy "gestiono follows"   on follows for all
  using (auth.uid() = follower_id) with check (auth.uid() = follower_id);

-- Collabs: las ve quien participa; el iniciador las crea; ambos pueden actualizar
create policy "veo mis collabs"    on collabs for select
  using (auth.uid() in (initiator_id, partner_id));
create policy "propongo collab"    on collabs for insert with check (auth.uid() = initiator_id);
create policy "actualizo collab"   on collabs for update
  using (auth.uid() in (initiator_id, partner_id));

-- Productos: catálogo público; el vendedor gestiona los suyos
create policy "productos visibles" on products for select using (true);
create policy "gestiono productos" on products for all
  using (auth.uid() = seller_id) with check (auth.uid() = seller_id);

-- Pedidos: solo el comprador ve y crea los suyos
create policy "veo mis pedidos"    on orders for select using (auth.uid() = buyer_id);
create policy "creo mis pedidos"   on orders for insert with check (auth.uid() = buyer_id);
create policy "actualizo mi pedido" on orders for update using (auth.uid() = buyer_id);

-- Líneas de pedido: las ve el comprador del pedido o el vendedor implicado
create policy "veo mis lineas" on order_items for select
  using (
    auth.uid() = seller_id
    or auth.uid() = (select buyer_id from orders o where o.id = order_id)
  );
create policy "agrego lineas" on order_items for insert
  with check (auth.uid() = (select buyer_id from orders o where o.id = order_id));

-- Mensajes: solo emisor y receptor
create policy "veo mis mensajes"   on messages for select
  using (auth.uid() in (sender_id, recipient_id));
create policy "envio mensajes"     on messages for insert with check (auth.uid() = sender_id);
create policy "marco leido"        on messages for update using (auth.uid() = recipient_id);

-- Notificaciones: solo el destinatario
create policy "veo mis notifs"     on notifications for select using (auth.uid() = user_id);
create policy "actualizo mis notifs" on notifications for update using (auth.uid() = user_id);

-- ============================================================
--  FIN del esquema. Ejecuta seed.sql para cargar datos demo.
-- ============================================================
