-- ============================================================
--  StarBonds · Bonds — Datos de ejemplo (seed)
-- ------------------------------------------------------------
--  Ejecuta esto DESPUÉS de schema.sql.
--
--  NOTA sobre los perfiles demo:
--    En producción cada profile.id debe coincidir con un usuario real
--    de auth.users. Para poder sembrar datos de prueba sin pasar por el
--    registro, este script inserta filas directamente en auth.users con
--    UUIDs fijos. Esto es solo para DEMO/desarrollo.
--    Si tu proyecto bloquea inserciones en auth.users, crea los usuarios
--    desde el panel de Supabase (Authentication → Users) y reemplaza
--    los UUID de abajo por los reales.
-- ============================================================

-- ---------- Disciplinas (catálogo) ----------
insert into disciplines (slug, name, icon, category) values
  ('ilustracion',    'Ilustración',     '🎨', 'visual'),
  ('escultura',      'Escultura',       '🗿', 'visual'),
  ('musica',         'Música',          '🎵', 'sonora'),
  ('fotografia',     'Fotografía',      '📷', 'visual'),
  ('escritura',      'Escritura',       '✍️', 'escrita'),
  ('diseno-grafico', 'Diseño gráfico',  '🖥️', 'visual'),
  ('comic',          'Cómic',           '💬', 'visual'),
  ('acuarela',       'Acuarela',        '🖌️', 'visual'),
  ('ceramica',       'Cerámica',        '🏺', 'visual'),
  ('3d',             'Modelado 3D',     '🧊', 'visual'),
  ('composicion',    'Composición',     '🎼', 'sonora'),
  ('animacion',      'Animación',       '🎞️', 'visual'),
  ('guion',          'Guion',           '📜', 'escrita'),
  ('poesia',         'Poesía',          '🪶', 'escrita'),
  ('edicion',        'Edición',         '✂️', 'visual'),
  ('cine',           'Cine',            '🎬', 'visual')
on conflict (slug) do nothing;

-- ---------- Complementos entre disciplinas ----------
-- (espeja COMPLEMENTOS del agente: disciplinas que juntas crean algo)
insert into discipline_complements (discipline_a, discipline_b, weight)
select a.id, b.id, w.weight
from (values
  ('ilustracion','escritura',1),
  ('ilustracion','musica',1),
  ('ilustracion','animacion',1),
  ('escritura','ilustracion',1),
  ('escritura','musica',1),
  ('escritura','guion',1),
  ('musica','animacion',1),
  ('musica','cine',1),
  ('musica','escritura',1),
  ('animacion','musica',1),
  ('animacion','guion',1),
  ('fotografia','edicion',1),
  ('fotografia','diseno-grafico',1),
  ('escultura','3d',1),
  ('escultura','ceramica',1),
  ('poesia','ilustracion',1),
  ('guion','cine',1)
) as w(slug_a, slug_b, weight)
join disciplines a on a.slug = w.slug_a
join disciplines b on b.slug = w.slug_b
on conflict do nothing;


-- ---------- Usuarios demo (auth.users + profiles) ----------
-- UUIDs fijos para poder enlazar relaciones abajo.
insert into auth.users (id, email, raw_user_meta_data, created_at)
values
  ('11111111-1111-1111-1111-111111111111','lia@bonds.demo',   '{"username":"lia.draws","display_name":"Lía Moreno"}', now()),
  ('22222222-2222-2222-2222-222222222222','marco@bonds.demo', '{"username":"marco.clay","display_name":"Marco Ruiz"}', now()),
  ('33333333-3333-3333-3333-333333333333','sofia@bonds.demo', '{"username":"sofivega","display_name":"Sofía Vega"}', now()),
  ('44444444-4444-4444-4444-444444444444','dani@bonds.demo',  '{"username":"danicruz","display_name":"Dani Cruz"}', now()),
  ('55555555-5555-5555-5555-555555555555','noa@bonds.demo',   '{"username":"noa.writes","display_name":"Noa Pérez"}', now())
on conflict (id) do nothing;

-- El trigger fn_nuevo_usuario ya creó los profiles. Completamos sus datos:
update profiles set
  avatar_emoji = '🖌️', bio = 'Ilustradora freelance. Acepto comisiones de personajes y portadas.',
  location = 'CDMX', sells_art = true, is_verified = true
  where username = 'lia.draws';
update profiles set
  avatar_emoji = '🗿', bio = 'Escultor en barro y resina. Piezas únicas hechas a mano.',
  location = 'Guadalajara', sells_art = true
  where username = 'marco.clay';
update profiles set
  avatar_emoji = '🎻', bio = 'Compositora y violinista. Hago bandas sonoras para tus proyectos.',
  location = 'Monterrey', sells_art = true, is_verified = true
  where username = 'sofivega';
update profiles set
  avatar_emoji = '📷', bio = 'Fotógrafo de retrato y calle. La luz lo es todo.',
  location = 'Puebla', sells_art = true
  where username = 'danicruz';
update profiles set
  avatar_emoji = '✍️', bio = 'Escritora. Busco ilustradores para un libro de poemas.',
  location = 'CDMX', sells_art = false
  where username = 'noa.writes';

-- ---------- Tags (disciplinas) de cada artista ----------
insert into profile_disciplines (profile_id, discipline_id, is_primary)
select pr.id, d.id, t.is_primary
from (values
  ('lia.draws','ilustracion',true), ('lia.draws','comic',false), ('lia.draws','acuarela',false),
  ('marco.clay','escultura',true),  ('marco.clay','ceramica',false), ('marco.clay','3d',false),
  ('sofivega','musica',true),       ('sofivega','composicion',false),
  ('danicruz','fotografia',true),   ('danicruz','edicion',false), ('danicruz','cine',false),
  ('noa.writes','escritura',true),  ('noa.writes','poesia',false), ('noa.writes','guion',false)
) as t(username, slug, is_primary)
join profiles pr on pr.username = t.username
join disciplines d on d.slug = t.slug
on conflict do nothing;

-- ---------- Posts de ejemplo ----------
insert into posts (author_id, content, media_emoji, is_collab, created_at)
select pr.id, p.content, p.emoji, p.collab, now() - (p.horas || ' hours')::interval
from (values
  ('lia.draws','Nuevo dragón terminado para una comisión 🐉 ¿qué les parece la paleta?','🐉',false,2),
  ('sofivega','Subí el demo de la banda sonora del corto. Busco ilustrador para la portada 👀','🎼',true,5),
  ('marco.clay','Proceso de torneado de esta vasija. El barro tiene su propio ritmo.','🏺',false,8),
  ('danicruz','Serie de fotos nocturnas de la ciudad. Disponibles en el marketplace.','🌆',false,12),
  ('noa.writes','Fragmento del nuevo poemario. ¿Alguien se anima a ilustrarlo? #collab','📖',true,24)
) as p(username, content, emoji, collab, horas)
join profiles pr on pr.username = p.username;

-- ---------- Algunos follows ----------
insert into follows (follower_id, following_id)
select a.id, b.id
from (values
  ('noa.writes','lia.draws'),
  ('lia.draws','sofivega'),
  ('sofivega','lia.draws'),
  ('marco.clay','danicruz'),
  ('danicruz','sofivega')
) as f(seguidor, seguido)
join profiles a on a.username = f.seguidor
join profiles b on b.username = f.seguido
on conflict do nothing;

-- ---------- Productos del marketplace ----------
insert into products (seller_id, discipline_id, title, image_emoji, price, is_physical, stock)
select pr.id, d.id, p.title, p.emoji, p.precio, p.fisico, p.stock
from (values
  ('lia.draws','ilustracion','Retrato digital personalizado','🧑‍🎨',35,false,null),
  ('lia.draws','ilustracion','Ilustración de portada de libro','📕',90,false,null),
  ('marco.clay','escultura','Escultura de cerámica artesanal','🏺',120,true,3),
  ('marco.clay','escultura','Figura escultórica en resina','🗿',150,true,2),
  ('sofivega','musica','Composición musical original','🎵',80,false,null),
  ('sofivega','musica','Jingle / intro musical','🎙️',45,false,null),
  ('danicruz','fotografia','Sesión de fotos de retrato','📸',60,false,null),
  ('danicruz','fotografia','Pack de fotos urbanas','🌃',30,false,null),
  ('noa.writes','escritura','Poema personalizado','📜',20,false,null)
) as p(username, disc, title, emoji, precio, fisico, stock)
join profiles pr on pr.username = p.username
join disciplines d on d.slug = p.disc;

-- ---------- Un pedido pagado de ejemplo (para que haya obras vendidas) ----------
do $$
declare
  v_buyer uuid; v_order uuid;
  v_prod uuid;  v_seller uuid; v_price numeric;
begin
  select id into v_buyer from profiles where username = 'noa.writes';
  select id, seller_id, price into v_prod, v_seller, v_price
    from products where title = 'Retrato digital personalizado' limit 1;

  insert into orders (buyer_id, status, subtotal, total, shipping_name, shipping_email)
    values (v_buyer, 'pendiente', v_price, v_price, 'Noa Pérez', 'noa@bonds.demo')
    returning id into v_order;

  insert into order_items (order_id, product_id, seller_id, quantity, unit_price)
    values (v_order, v_prod, v_seller, 1, v_price);

  -- al marcar 'pagado' se disparan los contadores de venta
  update orders set status = 'pagado' where id = v_order;
end $$;

-- ============================================================
--  Comprueba el resultado:
--    select username, posts_count, followers_count, obras_vendidas from profiles;
--    select * from artist_matches((select id from profiles where username='noa.writes'));
-- ============================================================
