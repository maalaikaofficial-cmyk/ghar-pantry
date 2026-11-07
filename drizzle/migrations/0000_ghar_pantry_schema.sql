CREATE TYPE public.app_role AS ENUM ('admin','housekeeper');

CREATE TABLE public.households (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.household_settings (
  household_id uuid PRIMARY KEY REFERENCES public.households(id) ON DELETE CASCADE,
  monthly_budget numeric NOT NULL DEFAULT 100000,
  quiet_start time NOT NULL DEFAULT '22:00',
  quiet_end time NOT NULL DEFAULT '08:00',
  briefing_time time NOT NULL DEFAULT '11:00',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  display_name text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id)
);

CREATE TABLE public.devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id uuid,
  label text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  paired_at timestamptz,
  last_seen_at timestamptz,
  revoked_at timestamptz
);

CREATE TABLE public.pairing_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  device_id uuid NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  key text NOT NULL,
  name_en text NOT NULL,
  name_ur text NOT NULL,
  emoji text NOT NULL DEFAULT '📦',
  sort int NOT NULL DEFAULT 0,
  food boolean NOT NULL DEFAULT true,
  UNIQUE (household_id, key)
);

CREATE TABLE public.locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  key text NOT NULL,
  name_en text NOT NULL,
  name_ur text NOT NULL,
  UNIQUE (household_id, key)
);

CREATE TABLE public.items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES public.categories(id),
  location_id uuid REFERENCES public.locations(id),
  name_en text NOT NULL,
  name_ur text NOT NULL,
  emoji text NOT NULL DEFAULT '📦',
  image_path text,
  base_unit text NOT NULL DEFAULT 'pc' CHECK (base_unit IN ('g','ml','pc','pack')),
  default_purchase_qty numeric,
  low_threshold numeric,
  gf_status text NOT NULL DEFAULT 'unknown' CHECK (gf_status IN ('unknown','verified','naturally_gf','contains','na')),
  shelf_days int,
  active boolean NOT NULL DEFAULT true,
  sort int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, name_en)
);
CREATE INDEX items_hh_cat ON public.items(household_id, category_id);

CREATE TABLE public.stock_batches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  qty_initial numeric NOT NULL CHECK (qty_initial >= 0),
  qty_remaining numeric NOT NULL CHECK (qty_remaining >= 0),
  expiry_date date,
  expiry_source text NOT NULL DEFAULT 'none' CHECK (expiry_source IN ('package_verified','package_unverified','estimated','none')),
  received_at timestamptz NOT NULL DEFAULT now(),
  origin text NOT NULL
);
CREATE INDEX stock_batches_item ON public.stock_batches(household_id, item_id);

CREATE TABLE public.inventory_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  batch_id uuid REFERENCES public.stock_batches(id),
  event_type text NOT NULL CHECK (event_type IN ('opening','receive','consume','waste','reconciliation','return','adjustment')),
  qty numeric NOT NULL,
  actor uuid,
  op_id text,
  ref_type text,
  ref_id uuid,
  note text,
  reverses_event_id uuid REFERENCES public.inventory_events(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX inv_events_item ON public.inventory_events(household_id, item_id, created_at);

CREATE TABLE public.availability_checks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id) ON DELETE CASCADE,
  status text NOT NULL CHECK (status IN ('yes','no','unknown')),
  check_date date NOT NULL,
  actor uuid,
  op_id text,
  undone_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX avail_item_date ON public.availability_checks(household_id, item_id, check_date);

CREATE TABLE public.consumption_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  actor uuid,
  transcript text,
  audio_path text,
  status text NOT NULL CHECK (status IN ('pending_transcription','confirmed','rejected')),
  op_id text,
  undone_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.consumption_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  report_id uuid NOT NULL REFERENCES public.consumption_reports(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id),
  qty numeric,
  unit text,
  qty_base numeric,
  deducted numeric NOT NULL DEFAULT 0,
  shortfall numeric NOT NULL DEFAULT 0,
  note text
);

CREATE TABLE public.shopping_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid NOT NULL REFERENCES public.items(id),
  status text NOT NULL DEFAULT 'awaiting_approval' CHECK (status IN ('awaiting_approval','approved','partially_purchased','purchased','partially_received','received','rejected','cancelled')),
  suggested_qty numeric,
  approved_qty numeric,
  substitute_item_id uuid REFERENCES public.items(id),
  source text NOT NULL,
  note text,
  requested_by uuid,
  decided_by uuid,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_active_request_per_item ON public.shopping_requests(household_id, item_id)
  WHERE status IN ('awaiting_approval','approved','partially_purchased','purchased','partially_received');

CREATE TABLE public.purchases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  vendor text,
  purchased_at date NOT NULL DEFAULT current_date,
  paid_from text NOT NULL DEFAULT 'housekeeper_cash' CHECK (paid_from IN ('housekeeper_cash','admin')),
  receipt_path text,
  ocr_suggestion jsonb,
  status text NOT NULL DEFAULT 'recorded' CHECK (status IN ('recorded','verified')),
  total numeric NOT NULL DEFAULT 0,
  created_by uuid,
  verified_by uuid,
  verified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.purchase_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  purchase_id uuid NOT NULL REFERENCES public.purchases(id) ON DELETE CASCADE,
  request_id uuid REFERENCES public.shopping_requests(id),
  item_id uuid NOT NULL REFERENCES public.items(id),
  qty numeric NOT NULL CHECK (qty > 0),
  unit text NOT NULL,
  qty_base numeric NOT NULL CHECK (qty_base > 0),
  line_total numeric NOT NULL CHECK (line_total >= 0),
  qty_received_base numeric NOT NULL DEFAULT 0 CHECK (qty_received_base >= 0),
  price_per_base numeric GENERATED ALWAYS AS (line_total / qty_base) STORED
);

CREATE TABLE public.receiving_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  purchase_line_id uuid NOT NULL REFERENCES public.purchase_lines(id) ON DELETE CASCADE,
  reported_qty_base numeric,
  verified_qty_base numeric,
  status text NOT NULL DEFAULT 'reported' CHECK (status IN ('reported','verified','rejected')),
  photo_path text,
  expiry_date date,
  expiry_source text,
  reported_by uuid,
  verified_by uuid,
  op_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.finance_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  entry_type text NOT NULL CHECK (entry_type IN ('advance','change_return','expense','refund','correction')),
  amount numeric NOT NULL,
  purchase_id uuid REFERENCES public.purchases(id),
  affects_cash boolean NOT NULL DEFAULT true,
  note text,
  op_id text,
  reverses_id uuid REFERENCES public.finance_ledger(id),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX one_expense_per_purchase ON public.finance_ledger(purchase_id) WHERE entry_type = 'expense';

CREATE TABLE public.waste_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid REFERENCES public.items(id),
  leftover_id uuid,
  qty numeric,
  unit text,
  qty_base numeric,
  deducted numeric NOT NULL DEFAULT 0,
  reason text NOT NULL,
  estimated_value numeric,
  audio_path text,
  photo_path text,
  actor uuid,
  op_id text,
  undone_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.leftover_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  dish_name text NOT NULL,
  prepared_at timestamptz NOT NULL,
  stored_at timestamptz,
  storage text NOT NULL CHECK (storage IN ('fridge','freezer','counter','unknown')),
  cooled_properly boolean,
  portions numeric,
  contains_gluten text NOT NULL DEFAULT 'unknown' CHECK (contains_gluten IN ('no','yes','unknown')),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','eaten','discarded')),
  audio_path text,
  photo_path text,
  actor uuid,
  op_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.meal_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  plan_date date NOT NULL,
  slot text NOT NULL CHECK (slot IN ('breakfast','lunch','dinner','snack')),
  recipe_key text,
  title text NOT NULL,
  portions text,
  leftover_id uuid REFERENCES public.leftover_records(id),
  notes text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, plan_date, slot)
);

CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  kind text NOT NULL,
  severity text NOT NULL DEFAULT 'routine' CHECK (severity IN ('routine','urgent')),
  title text NOT NULL,
  body text,
  dedup_key text,
  occurrences int NOT NULL DEFAULT 1,
  deliver_after timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX notif_dedup ON public.notifications(household_id, dedup_key) WHERE read_at IS NULL AND dedup_key IS NOT NULL;

CREATE TABLE public.sync_operations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  op_id text NOT NULL,
  op_type text NOT NULL,
  actor uuid,
  result jsonb,
  undoable boolean NOT NULL DEFAULT false,
  undone_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (household_id, op_id)
);

CREATE TABLE public.conflict_cases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  item_id uuid REFERENCES public.items(id),
  kind text NOT NULL,
  details jsonb,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved')),
  resolved_by uuid,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.correction_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id uuid NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  sync_operation_id uuid REFERENCES public.sync_operations(id),
  reason text,
  requested_by uuid,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  decided_by uuid,
  decided_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  household_id uuid,
  actor uuid,
  action text NOT NULL,
  table_name text NOT NULL,
  row_id uuid,
  data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_hh ON public.audit_log(household_id, created_at DESC);

CREATE TABLE public.catalog_template (
  id serial PRIMARY KEY,
  cat_key text NOT NULL,
  name_en text NOT NULL,
  name_ur text NOT NULL,
  emoji text NOT NULL,
  base_unit text NOT NULL,
  location_key text NOT NULL,
  gf_status text NOT NULL,
  shelf_days int
);

-- Helper functions
CREATE OR REPLACE FUNCTION public.my_household() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT household_id FROM public.user_roles WHERE user_id = auth.uid() AND active LIMIT 1
$$;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role AND active)
$$;

CREATE OR REPLACE FUNCTION public.is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.has_role(auth.uid(), 'admin')
$$;

-- Immutability guards
CREATE OR REPLACE FUNCTION public.forbid_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'This ledger is append-only; post a correcting entry instead'; END $$;
CREATE TRIGGER inv_events_immutable BEFORE UPDATE OR DELETE ON public.inventory_events FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();
CREATE TRIGGER finance_immutable BEFORE UPDATE OR DELETE ON public.finance_ledger FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();
CREATE TRIGGER audit_immutable BEFORE UPDATE OR DELETE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();

-- Generic audit trigger
CREATE OR REPLACE FUNCTION public.audit_row() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE r jsonb;
BEGIN
  r := to_jsonb(COALESCE(NEW, OLD));
  INSERT INTO public.audit_log(household_id, actor, action, table_name, row_id, data)
  VALUES ((r->>'household_id')::uuid, auth.uid(), TG_OP, TG_TABLE_NAME, (r->>'id')::uuid, r);
  RETURN COALESCE(NEW, OLD);
END $$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['household_settings','user_roles','devices','categories','locations','items','stock_batches','inventory_events','availability_checks','consumption_reports','consumption_lines','shopping_requests','purchases','purchase_lines','receiving_lines','finance_ledger','waste_events','leftover_records','meal_plans','conflict_cases','correction_requests'] LOOP
    EXECUTE format('CREATE TRIGGER audit_%1$s AFTER INSERT OR UPDATE OR DELETE ON public.%1$s FOR EACH ROW EXECUTE FUNCTION public.audit_row()', t);
  END LOOP;
END $$;

-- Grants: read-only via Data API; all writes go through checked RPC functions.
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['households','household_settings','user_roles','devices','categories','locations','items','stock_batches','inventory_events','availability_checks','consumption_reports','consumption_lines','shopping_requests','purchases','purchase_lines','receiving_lines','finance_ledger','waste_events','leftover_records','meal_plans','notifications','sync_operations','conflict_cases','correction_requests','audit_log'] LOOP
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', t);
    EXECUTE format('GRANT ALL ON public.%I TO service_role', t);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END $$;
GRANT ALL ON public.pairing_tokens, public.catalog_template TO service_role;
ALTER TABLE public.pairing_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalog_template ENABLE ROW LEVEL SECURITY;

-- Member-readable operational tables
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['categories','locations','items','availability_checks','consumption_reports','consumption_lines','shopping_requests','waste_events','leftover_records','meal_plans'] LOOP
    EXECUTE format('CREATE POLICY "members read %1$s" ON public.%1$s FOR SELECT TO authenticated USING (household_id = public.my_household())', t);
  END LOOP;
END $$;

-- Admin-only tables (finance, devices, ledger detail, audit)
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['household_settings','devices','stock_batches','inventory_events','purchases','purchase_lines','receiving_lines','finance_ledger','notifications','conflict_cases','correction_requests','audit_log'] LOOP
    EXECUTE format('CREATE POLICY "admin read %1$s" ON public.%1$s FOR SELECT TO authenticated USING (household_id = public.my_household() AND public.is_admin())', t);
  END LOOP;
END $$;

CREATE POLICY "members read household" ON public.households FOR SELECT TO authenticated USING (id = public.my_household());
CREATE POLICY "read own role or admin reads all" ON public.user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR (household_id = public.my_household() AND public.is_admin()));
CREATE POLICY "own ops or admin" ON public.sync_operations FOR SELECT TO authenticated
  USING (household_id = public.my_household() AND (actor = auth.uid() OR public.is_admin()));

-- Stock view (admin-only via underlying RLS on stock_batches/inventory_events)
CREATE VIEW public.item_stock WITH (security_invoker = true) AS
SELECT i.id AS item_id, i.household_id,
  EXISTS (SELECT 1 FROM public.inventory_events e WHERE e.item_id = i.id AND e.event_type IN ('opening','receive','reconciliation')) AS known,
  COALESCE((SELECT sum(b.qty_remaining) FROM public.stock_batches b WHERE b.item_id = i.id), 0) AS qty,
  (SELECT min(b.expiry_date) FROM public.stock_batches b WHERE b.item_id = i.id AND b.qty_remaining > 0) AS next_expiry,
  (SELECT COALESCE(sum(-e.qty),0) FROM public.inventory_events e WHERE e.item_id = i.id AND e.event_type = 'consume' AND e.created_at > now() - interval '30 days') AS used_30d
FROM public.items i;
GRANT SELECT ON public.item_stock TO authenticated;