-- ============================================================
-- Seed: use_cases catalogue (ar / en / fr)
-- Idempotent: re-running updates labels but keeps ids stable.
-- ============================================================

insert into public.use_cases (code, label_ar, label_en, label_fr, icon_name, sort_order) values
  ('delivery',            'التوصيل',                        'Delivery',                       'Livraison',                                'box',        10),
  ('personal_use',        'الاستخدام الشخصي',               'Personal use',                   'Usage personnel',                          'user',       20),
  ('navigation',          'الملاحة والتنقل',                'Navigation and transportation',  'Navigation et déplacements',               'compass',    30),
  ('driver',              'العمل كسائق',                    'Working as a driver',            'Travail en tant que conducteur',           'steering',   40),
  ('delivery_driver',     'مندوب توصيل',                    'Delivery driver',                'Livreur',                                  'scooter',    50),
  ('fleet_management',    'إدارة أسطول مركبات',             'Fleet management',               'Gestion de flotte',                        'truck',      60),
  ('business_management', 'إدارة أعمال أو شركة',            'Business or company management', 'Gestion d''entreprise',                    'briefcase',  70),
  ('route_planning',      'تخطيط الرحلات والمسارات',        'Trip and route planning',        'Planification des trajets et itinéraires', 'route',      80),
  ('field_operations',    'متابعة العمليات الميدانية',      'Field operations',               'Opérations sur le terrain',                'radar',      90),
  ('field_sales',         'المبيعات والزيارات الميدانية',   'Sales and field visits',         'Ventes et visites sur le terrain',         'chart',     100),
  ('other',               'استخدام آخر',                    'Other use',                      'Autre utilisation',                        'dots',      110)
on conflict (code) do update set
  label_ar   = excluded.label_ar,
  label_en   = excluded.label_en,
  label_fr   = excluded.label_fr,
  icon_name  = excluded.icon_name,
  sort_order = excluded.sort_order,
  is_active  = true;
