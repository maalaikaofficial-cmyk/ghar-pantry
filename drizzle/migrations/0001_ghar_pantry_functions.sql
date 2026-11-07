-- ===== internal helpers =====
CREATE OR REPLACE FUNCTION public._ctx(require_admin boolean DEFAULT false)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid;
BEGIN
  hh := public.my_household();
  IF hh IS NULL THEN RAISE EXCEPTION 'Not a member of any household' USING ERRCODE = '42501'; END IF;
  IF require_admin AND NOT public.is_admin() THEN RAISE EXCEPTION 'Admin only' USING ERRCODE = '42501'; END IF;
  RETURN hh;
END $$;

CREATE OR REPLACE FUNCTION public.convert_qty(p_qty numeric, p_unit text, p_base text)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE u text := lower(coalesce(p_unit, p_base));
BEGIN
  IF p_qty IS NULL THEN RETURN NULL; END IF;
  IF p_base = 'g' THEN
    RETURN CASE u WHEN 'g' THEN p_qty WHEN 'kg' THEN p_qty*1000 WHEN 'pao' THEN p_qty*250 ELSE NULL END;
  ELSIF p_base = 'ml' THEN
    RETURN CASE u WHEN 'ml' THEN p_qty WHEN 'l' THEN p_qty*1000 ELSE NULL END;
  ELSIF p_base = 'pc' THEN
    RETURN CASE u WHEN 'pc' THEN p_qty WHEN 'dozen' THEN p_qty*12 ELSE NULL END;
  ELSIF p_base = 'pack' THEN
    RETURN CASE u WHEN 'pack' THEN p_qty ELSE NULL END;
  END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public._begin_op(hh uuid, p_op text, p_type text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v uuid; r jsonb;
BEGIN
  IF p_op IS NULL OR length(p_op) < 8 THEN RAISE EXCEPTION 'client operation id required'; END IF;
  INSERT INTO sync_operations(household_id, op_id, op_type, actor)
  VALUES (hh, p_op, p_type, auth.uid())
  ON CONFLICT (household_id, op_id) DO NOTHING RETURNING id INTO v;
  IF v IS NULL THEN
    SELECT coalesce(result,'{}'::jsonb) || jsonb_build_object('duplicate', true) INTO r
    FROM sync_operations WHERE household_id = hh AND op_id = p_op;
    RETURN r;
  END IF;
  RETURN NULL;
END $$;

CREATE OR REPLACE FUNCTION public._finish_op(hh uuid, p_op text, p_result jsonb, p_undoable boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE sync_operations SET result = p_result, undoable = p_undoable WHERE household_id = hh AND op_id = p_op;
  RETURN p_result;
END $$;

CREATE OR REPLACE FUNCTION public._notify(hh uuid, p_kind text, p_sev text, p_title text, p_body text, p_dedup text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s household_settings; local_now timestamp; t time; deliver timestamptz := now();
BEGIN
  SELECT * INTO s FROM household_settings WHERE household_id = hh;
  IF p_sev = 'routine' AND s IS NOT NULL THEN
    local_now := now() AT TIME ZONE 'Asia/Karachi';
    t := local_now::time;
    IF (s.quiet_start > s.quiet_end AND (t >= s.quiet_start OR t < s.quiet_end))
       OR (s.quiet_start < s.quiet_end AND t >= s.quiet_start AND t < s.quiet_end) THEN
      deliver := ((CASE WHEN t >= s.quiet_end THEN local_now::date + 1 ELSE local_now::date END) + s.quiet_end) AT TIME ZONE 'Asia/Karachi';
    END IF;
  END IF;
  INSERT INTO notifications(household_id, kind, severity, title, body, dedup_key, deliver_after)
  VALUES (hh, p_kind, p_sev, p_title, p_body, p_dedup, deliver)
  ON CONFLICT (household_id, dedup_key) WHERE read_at IS NULL AND dedup_key IS NOT NULL
  DO UPDATE SET occurrences = notifications.occurrences + 1, body = EXCLUDED.body, updated_at = now();
END $$;

CREATE OR REPLACE FUNCTION public._stock(p_item uuid, OUT known boolean, OUT qty numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM inventory_events e WHERE e.item_id = p_item AND e.event_type IN ('opening','receive','reconciliation')),
         COALESCE((SELECT sum(qty_remaining) FROM stock_batches WHERE item_id = p_item),0)
$$;

CREATE OR REPLACE FUNCTION public._suggest_qty(p_item uuid)
RETURNS numeric LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT GREATEST(
    COALESCE(i.default_purchase_qty, 0),
    LEAST(
      COALESCE((SELECT sum(-e.qty) FROM inventory_events e WHERE e.item_id = i.id AND e.event_type='consume' AND e.created_at > now()-interval '30 days'),0) / 30.0 * 7,
      CASE WHEN i.shelf_days IS NULL THEN 1e12 ELSE COALESCE((SELECT sum(-e.qty) FROM inventory_events e WHERE e.item_id = i.id AND e.event_type='consume' AND e.created_at > now()-interval '30 days'),0) / 30.0 * i.shelf_days END
    ))
  FROM items i WHERE i.id = p_item
$$;

CREATE OR REPLACE FUNCTION public._ensure_request(hh uuid, p_item uuid, p_source text, p_qty numeric, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v uuid; created boolean := false;
BEGIN
  INSERT INTO shopping_requests(household_id, item_id, source, suggested_qty, note, requested_by)
  VALUES (hh, p_item, p_source, COALESCE(p_qty, NULLIF(public._suggest_qty(p_item),0)), p_note, auth.uid())
  ON CONFLICT (household_id, item_id) WHERE status IN ('awaiting_approval','approved','partially_purchased','purchased','partially_received')
  DO NOTHING RETURNING id INTO v;
  IF v IS NOT NULL THEN
    created := true;
    PERFORM public._notify(hh, 'approval', 'routine', 'Shopping requests awaiting approval', 'New items need your approval', 'approvals_pending');
  ELSE
    SELECT id INTO v FROM shopping_requests WHERE household_id = hh AND item_id = p_item
      AND status IN ('awaiting_approval','approved','partially_purchased','purchased','partially_received');
  END IF;
  RETURN jsonb_build_object('request_id', v, 'created', created);
END $$;

CREATE OR REPLACE FUNCTION public._check_low(hh uuid, p_item uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s record; th numeric;
BEGIN
  SELECT * INTO s FROM public._stock(p_item);
  SELECT low_threshold INTO th FROM items WHERE id = p_item;
  IF s.known AND th IS NOT NULL AND s.qty <= th THEN
    PERFORM public._ensure_request(hh, p_item, 'low_stock', NULL, NULL);
    PERFORM public._notify(hh, 'low_stock', 'routine', 'Items running low', 'Some items reached their low-stock level', 'low_stock');
  END IF;
END $$;

-- FEFO deduction: never drives stock below zero; returns amount actually deducted.
CREATE OR REPLACE FUNCTION public._deduct(hh uuid, p_item uuid, p_qty numeric, p_type text, p_op text, p_ref_type text, p_ref uuid, p_note text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b record; remaining numeric := p_qty; take numeric; done numeric := 0;
BEGIN
  IF p_qty IS NULL OR p_qty <= 0 THEN RETURN 0; END IF;
  FOR b IN SELECT * FROM stock_batches WHERE item_id = p_item AND household_id = hh AND qty_remaining > 0
           ORDER BY expiry_date NULLS LAST, received_at FOR UPDATE LOOP
    EXIT WHEN remaining <= 0;
    take := LEAST(b.qty_remaining, remaining);
    UPDATE stock_batches SET qty_remaining = qty_remaining - take WHERE id = b.id;
    INSERT INTO inventory_events(household_id, item_id, batch_id, event_type, qty, actor, op_id, ref_type, ref_id, note)
    VALUES (hh, p_item, b.id, p_type, -take, auth.uid(), p_op, p_ref_type, p_ref, p_note);
    remaining := remaining - take; done := done + take;
  END LOOP;
  RETURN done;
END $$;

CREATE OR REPLACE FUNCTION public._reverse_events(hh uuid, p_op text, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE e record;
BEGIN
  FOR e IN SELECT * FROM inventory_events WHERE household_id = hh AND op_id = p_op AND reverses_event_id IS NULL
           AND NOT EXISTS (SELECT 1 FROM inventory_events r WHERE r.reverses_event_id = inventory_events.id) LOOP
    IF e.batch_id IS NOT NULL THEN
      UPDATE stock_batches SET qty_remaining = qty_remaining - e.qty WHERE id = e.batch_id;
    END IF;
    INSERT INTO inventory_events(household_id, item_id, batch_id, event_type, qty, actor, op_id, ref_type, ref_id, note, reverses_event_id)
    VALUES (hh, e.item_id, e.batch_id, e.event_type, -e.qty, auth.uid(), p_op || ':undo', e.ref_type, e.ref_id, p_note, e.id);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public._reverse_op(hh uuid, so sync_operations, p_note text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF so.undone_at IS NOT NULL THEN RAISE EXCEPTION 'Already undone'; END IF;
  IF so.op_type = 'availability' THEN
    UPDATE availability_checks SET undone_at = now() WHERE household_id = hh AND op_id = so.op_id;
    IF (so.result->>'request_created')::boolean THEN
      UPDATE shopping_requests SET status = 'cancelled', updated_at = now()
      WHERE id = (so.result->>'request_id')::uuid AND status = 'awaiting_approval';
    END IF;
  ELSIF so.op_type = 'usage' THEN
    PERFORM public._reverse_events(hh, so.op_id, p_note);
    UPDATE consumption_reports SET undone_at = now() WHERE household_id = hh AND op_id = so.op_id;
  ELSIF so.op_type = 'waste' THEN
    PERFORM public._reverse_events(hh, so.op_id, p_note);
    UPDATE waste_events SET undone_at = now() WHERE household_id = hh AND op_id = so.op_id;
    UPDATE leftover_records SET status = 'available' WHERE id = (SELECT leftover_id FROM waste_events WHERE household_id = hh AND op_id = so.op_id LIMIT 1);
  ELSIF so.op_type = 'leftover' THEN
    UPDATE leftover_records SET status = 'discarded' WHERE household_id = hh AND op_id = so.op_id;
  ELSIF so.op_type = 'receive_report' THEN
    UPDATE receiving_lines SET status = 'rejected' WHERE household_id = hh AND op_id = so.op_id AND status = 'reported';
  ELSE
    RAISE EXCEPTION 'This action cannot be reversed automatically';
  END IF;
  UPDATE sync_operations SET undone_at = now() WHERE id = so.id;
END $$;

-- ===== household bootstrap =====
CREATE OR REPLACE FUNCTION public.create_household(p_name text, p_display_name text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in first'; END IF;
  IF EXISTS (SELECT 1 FROM user_roles WHERE user_id = auth.uid()) THEN RAISE EXCEPTION 'Already in a household'; END IF;
  INSERT INTO households(name) VALUES (coalesce(nullif(p_name,''),'Ghar')) RETURNING id INTO hh;
  INSERT INTO household_settings(household_id) VALUES (hh);
  INSERT INTO user_roles(user_id, household_id, role, display_name) VALUES (auth.uid(), hh, 'admin', p_display_name);
  INSERT INTO categories(household_id, key, name_en, name_ur, emoji, sort, food) VALUES
   (hh,'veg','Vegetables & Herbs','سبزیاں اور جڑی بوٹیاں','🥬',1,true),
   (hh,'fruit','Fruits','پھل','🍌',2,true),
   (hh,'meat','Meat, Poultry & Seafood','گوشت اور مرغی','🍗',3,true),
   (hh,'dairy','Dairy & Eggs','دودھ اور انڈے','🥚',4,true),
   (hh,'grains','Rice & Grains','چاول اور اناج','🍚',5,true),
   (hh,'pulses','Pulses & Beans','دالیں اور لوبیا','🫘',6,true),
   (hh,'spices','Spices & Seasonings','مصالحے','🌶️',7,true),
   (hh,'oils','Oils & Condiments','تیل اور چٹنیاں','🫒',8,true),
   (hh,'nuts','Nuts, Seeds & Snacks','میوے اور سنیکس','🥜',9,true),
   (hh,'breakfast','Breakfast','ناشتہ','🥞',10,true),
   (hh,'drinks','Drinks','مشروبات','💧',11,true),
   (hh,'cleaning','Cleaning & Kitchen Supplies','صفائی کا سامان','🧽',12,false),
   (hh,'personal','Personal Essentials','ذاتی ضروریات','🧴',13,false);
  INSERT INTO locations(household_id, key, name_en, name_ur) VALUES
   (hh,'fridge','Refrigerator','فریج'),(hh,'freezer','Freezer','فریزر'),(hh,'pantry','Pantry','الماری'),
   (hh,'spice','Spice cabinet','مصالحوں کی الماری'),(hh,'produce','Fruit & vegetables','سبزی کی ٹوکری'),(hh,'cleaning','Cleaning cupboard','صفائی کی الماری');
  INSERT INTO items(household_id, category_id, location_id, name_en, name_ur, emoji, base_unit, gf_status, shelf_days, sort)
  SELECT hh, c.id, l.id, t.name_en, t.name_ur, t.emoji, t.base_unit, t.gf_status, t.shelf_days, t.id
  FROM catalog_template t JOIN categories c ON c.household_id = hh AND c.key = t.cat_key
  LEFT JOIN locations l ON l.household_id = hh AND l.key = t.location_key;
  RETURN hh;
END $$;

-- ===== housekeeper + admin operations =====
CREATE OR REPLACE FUNCTION public.submit_availability(p_op text, p_item uuid, p_status text, p_date date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; s record; req jsonb := '{}'::jsonb; other text; th numeric;
BEGIN
  prev := public._begin_op(hh, p_op, 'availability'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  IF p_status NOT IN ('yes','no','unknown') THEN RAISE EXCEPTION 'bad status'; END IF;
  PERFORM 1 FROM items WHERE id = p_item AND household_id = hh; IF NOT FOUND THEN RAISE EXCEPTION 'item not found'; END IF;
  SELECT status INTO other FROM availability_checks WHERE household_id = hh AND item_id = p_item AND check_date = p_date
    AND undone_at IS NULL AND actor IS DISTINCT FROM auth.uid() AND status <> 'unknown' ORDER BY created_at DESC LIMIT 1;
  INSERT INTO availability_checks(household_id, item_id, status, check_date, actor, op_id) VALUES (hh, p_item, p_status, p_date, auth.uid(), p_op);
  SELECT * INTO s FROM public._stock(p_item);
  SELECT low_threshold INTO th FROM items WHERE id = p_item;
  IF p_status = 'yes' AND s.known AND s.qty = 0 THEN
    INSERT INTO conflict_cases(household_id, item_id, kind, details) VALUES (hh, p_item, 'availability_yes_but_stock_zero', jsonb_build_object('check_date', p_date));
    PERFORM public._notify(hh, 'conflict', 'routine', 'Stock contradictions to review', 'Availability check disagrees with recorded stock', 'conflicts_open');
  ELSIF p_status = 'no' AND s.known AND s.qty > COALESCE(th, 0) THEN
    INSERT INTO conflict_cases(household_id, item_id, kind, details) VALUES (hh, p_item, 'availability_no_but_stock_recorded', jsonb_build_object('check_date', p_date, 'recorded_qty', s.qty));
    PERFORM public._notify(hh, 'conflict', 'routine', 'Stock contradictions to review', 'Availability check disagrees with recorded stock', 'conflicts_open');
  END IF;
  IF other IS NOT NULL AND p_status <> 'unknown' AND other <> p_status THEN
    INSERT INTO conflict_cases(household_id, item_id, kind, details) VALUES (hh, p_item, 'contradictory_checks_same_day', jsonb_build_object('check_date', p_date, 'statuses', jsonb_build_array(other, p_status)));
  END IF;
  IF p_status = 'no' THEN
    req := public._ensure_request(hh, p_item, 'availability_no', NULL, NULL);
  END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'request_id', req->'request_id', 'request_created', COALESCE((req->>'created')::boolean,false)), true);
END $$;

CREATE OR REPLACE FUNCTION public.submit_usage(p_op text, p_transcript text, p_audio text, p_lines jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; rid uuid; l jsonb; it items; conv numeric; d numeric; s record; out jsonb := '[]'::jsonb;
BEGIN
  prev := public._begin_op(hh, p_op, 'usage'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  IF jsonb_array_length(coalesce(p_lines,'[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'no confirmed lines'; END IF;
  INSERT INTO consumption_reports(household_id, actor, transcript, audio_path, status, op_id)
  VALUES (hh, auth.uid(), p_transcript, p_audio, 'confirmed', p_op) RETURNING id INTO rid;
  FOR l IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    SELECT * INTO it FROM items WHERE id = (l->>'item_id')::uuid AND household_id = hh;
    IF it.id IS NULL THEN RAISE EXCEPTION 'item not found'; END IF;
    conv := public.convert_qty((l->>'qty')::numeric, l->>'unit', it.base_unit);
    IF (l->>'qty') IS NOT NULL AND conv IS NULL THEN RAISE EXCEPTION 'unit % not compatible with %', l->>'unit', it.name_en; END IF;
    d := public._deduct(hh, it.id, conv, 'consume', p_op, 'consumption_report', rid, NULL);
    SELECT * INTO s FROM public._stock(it.id);
    INSERT INTO consumption_lines(household_id, report_id, item_id, qty, unit, qty_base, deducted, shortfall, note)
    VALUES (hh, rid, it.id, (l->>'qty')::numeric, l->>'unit', conv, d, COALESCE(conv,0) - d,
      CASE WHEN conv IS NULL THEN 'quantity unknown - no deduction' WHEN NOT s.known THEN 'stock never recorded - no deduction' END);
    IF conv IS NOT NULL AND conv - d > 0 AND s.known THEN
      INSERT INTO conflict_cases(household_id, item_id, kind, details) VALUES (hh, it.id, 'usage_exceeds_recorded_stock', jsonb_build_object('reported', conv, 'deducted', d, 'report_id', rid));
      PERFORM public._notify(hh, 'conflict', 'routine', 'Stock contradictions to review', 'Reported usage exceeds recorded stock', 'conflicts_open');
    END IF;
    PERFORM public._check_low(hh, it.id);
    out := out || jsonb_build_object('item_id', it.id, 'deducted', d, 'requested', conv);
  END LOOP;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'report_id', rid, 'lines', out), true);
END $$;

CREATE OR REPLACE FUNCTION public.save_pending_audio(p_op text, p_kind text, p_audio text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; rid uuid;
BEGIN
  prev := public._begin_op(hh, p_op, 'pending_audio'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  INSERT INTO consumption_reports(household_id, actor, audio_path, status, op_id, transcript)
  VALUES (hh, auth.uid(), p_audio, 'pending_transcription', p_op, '['||coalesce(p_kind,'usage')||'] awaiting review') RETURNING id INTO rid;
  PERFORM public._notify(hh, 'audio', 'routine', 'Voice notes waiting for review', 'Housekeeper recorded audio that needs transcription', 'audio_pending');
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'report_id', rid), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_close_audio(p_report uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN
  UPDATE consumption_reports SET status = 'rejected' WHERE id = p_report AND household_id = hh AND status = 'pending_transcription';
END $$;

CREATE OR REPLACE FUNCTION public.report_waste(p_op text, p_item uuid, p_qty numeric, p_unit text, p_reason text, p_leftover uuid, p_audio text, p_photo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; it items; conv numeric; d numeric := 0; wid uuid; price numeric;
BEGIN
  prev := public._begin_op(hh, p_op, 'waste'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  IF p_item IS NULL AND p_leftover IS NULL THEN RAISE EXCEPTION 'choose an item or leftover'; END IF;
  IF p_leftover IS NOT NULL THEN
    -- Leftover ingredients were already deducted when used; discarding the dish never deducts again.
    UPDATE leftover_records SET status = 'discarded' WHERE id = p_leftover AND household_id = hh;
  ELSE
    SELECT * INTO it FROM items WHERE id = p_item AND household_id = hh;
    IF it.id IS NULL THEN RAISE EXCEPTION 'item not found'; END IF;
    conv := public.convert_qty(p_qty, p_unit, it.base_unit);
    IF p_qty IS NOT NULL AND conv IS NULL THEN RAISE EXCEPTION 'unit not compatible'; END IF;
    SELECT pl.price_per_base INTO price FROM purchase_lines pl JOIN purchases p ON p.id = pl.purchase_id
      WHERE pl.item_id = it.id AND p.status = 'verified' ORDER BY p.purchased_at DESC LIMIT 1;
  END IF;
  INSERT INTO waste_events(household_id, item_id, leftover_id, qty, unit, qty_base, reason, estimated_value, audio_path, photo_path, actor, op_id)
  VALUES (hh, p_item, p_leftover, p_qty, p_unit, conv, coalesce(p_reason,'unspecified'), conv * price, p_audio, p_photo, auth.uid(), p_op) RETURNING id INTO wid;
  IF conv IS NOT NULL THEN
    d := public._deduct(hh, p_item, conv, 'waste', p_op, 'waste_event', wid, p_reason);
    UPDATE waste_events SET deducted = d WHERE id = wid;
    PERFORM public._check_low(hh, p_item);
  END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'waste_id', wid, 'deducted', d), true);
END $$;

CREATE OR REPLACE FUNCTION public.record_leftover(p_op text, p_dish text, p_prepared timestamptz, p_stored timestamptz, p_storage text, p_cooled boolean, p_portions numeric, p_gluten text, p_audio text, p_photo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; lid uuid;
BEGIN
  prev := public._begin_op(hh, p_op, 'leftover'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  INSERT INTO leftover_records(household_id, dish_name, prepared_at, stored_at, storage, cooled_properly, portions, contains_gluten, audio_path, photo_path, actor, op_id)
  VALUES (hh, p_dish, p_prepared, p_stored, p_storage, p_cooled, p_portions, coalesce(p_gluten,'unknown'), p_audio, p_photo, auth.uid(), p_op) RETURNING id INTO lid;
  IF p_storage IN ('counter','unknown') OR p_cooled IS NOT TRUE THEN
    PERFORM public._notify(hh, 'food_safety', 'urgent', 'Leftover storage uncertain', p_dish || ' was not confirmed as safely refrigerated. It is excluded from meal suggestions.', 'food_safety_' || lid);
  END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'leftover_id', lid), true);
END $$;

CREATE OR REPLACE FUNCTION public.set_leftover_status(p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx();
BEGIN
  IF p_status NOT IN ('available','eaten','discarded') THEN RAISE EXCEPTION 'bad status'; END IF;
  UPDATE leftover_records SET status = p_status WHERE id = p_id AND household_id = hh;
END $$;

CREATE OR REPLACE FUNCTION public.undo_last_action()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); so sync_operations;
BEGIN
  SELECT * INTO so FROM sync_operations WHERE household_id = hh AND actor = auth.uid() AND undone_at IS NULL AND op_type NOT LIKE 'admin_%'
    ORDER BY created_at DESC LIMIT 1 FOR UPDATE;
  IF so.id IS NULL THEN RAISE EXCEPTION 'Nothing to undo'; END IF;
  IF NOT so.undoable THEN RAISE EXCEPTION 'Last action cannot be undone'; END IF;
  IF so.created_at < now() - interval '30 minutes' THEN RAISE EXCEPTION 'Too old to undo - ask admin for a correction'; END IF;
  PERFORM public._reverse_op(hh, so, 'undo by actor');
  RETURN jsonb_build_object('ok', true, 'undone', so.op_type);
END $$;

CREATE OR REPLACE FUNCTION public.request_correction(p_sync_op uuid, p_reason text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); v uuid;
BEGIN
  PERFORM 1 FROM sync_operations WHERE id = p_sync_op AND household_id = hh AND actor = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'not found'; END IF;
  INSERT INTO correction_requests(household_id, sync_operation_id, reason, requested_by) VALUES (hh, p_sync_op, p_reason, auth.uid()) RETURNING id INTO v;
  PERFORM public._notify(hh, 'correction', 'routine', 'Correction requests', 'A correction needs your approval', 'corrections_pending');
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.admin_decide_correction(p_id uuid, p_approve boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); c correction_requests; so sync_operations;
BEGIN
  SELECT * INTO c FROM correction_requests WHERE id = p_id AND household_id = hh AND status = 'pending' FOR UPDATE;
  IF c.id IS NULL THEN RAISE EXCEPTION 'not pending'; END IF;
  IF p_approve THEN
    SELECT * INTO so FROM sync_operations WHERE id = c.sync_operation_id FOR UPDATE;
    PERFORM public._reverse_op(hh, so, 'admin-approved correction');
  END IF;
  UPDATE correction_requests SET status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END, decided_by = auth.uid(), decided_at = now() WHERE id = p_id;
END $$;

-- Receiving (housekeeper side sees only items and quantities, never prices)
CREATE OR REPLACE FUNCTION public.pending_receipts()
RETURNS TABLE(purchase_line_id uuid, item_id uuid, name_en text, name_ur text, emoji text, base_unit text, qty_expected numeric, qty_received numeric, reported boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT pl.id, i.id, i.name_en, i.name_ur, i.emoji, i.base_unit, pl.qty_base, pl.qty_received_base,
    EXISTS (SELECT 1 FROM receiving_lines r WHERE r.purchase_line_id = pl.id AND r.status = 'reported')
  FROM purchase_lines pl JOIN items i ON i.id = pl.item_id
  WHERE pl.household_id = public._ctx() AND pl.qty_received_base < pl.qty_base
  ORDER BY i.name_en
$$;

CREATE OR REPLACE FUNCTION public.report_received(p_op text, p_line uuid, p_qty_base numeric, p_photo text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); prev jsonb; v uuid;
BEGIN
  prev := public._begin_op(hh, p_op, 'receive_report'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  PERFORM 1 FROM purchase_lines WHERE id = p_line AND household_id = hh; IF NOT FOUND THEN RAISE EXCEPTION 'line not found'; END IF;
  INSERT INTO receiving_lines(household_id, purchase_line_id, reported_qty_base, photo_path, reported_by, op_id)
  VALUES (hh, p_line, p_qty_base, p_photo, auth.uid(), p_op) RETURNING id INTO v;
  PERFORM public._notify(hh, 'receiving', 'routine', 'Deliveries to verify', 'Housekeeper reported received items', 'receiving_pending');
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'receiving_id', v), true);
END $$;

-- ===== admin-only operations =====
CREATE OR REPLACE FUNCTION public.admin_record_opening(p_op text, p_item uuid, p_qty numeric, p_unit text, p_expiry date, p_expiry_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb; it items; conv numeric; bid uuid; s record;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_opening'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  SELECT * INTO it FROM items WHERE id = p_item AND household_id = hh FOR UPDATE;
  IF it.id IS NULL THEN RAISE EXCEPTION 'item not found'; END IF;
  SELECT * INTO s FROM public._stock(p_item);
  IF s.known THEN RAISE EXCEPTION 'Opening balance already recorded - use a stock count instead'; END IF;
  conv := public.convert_qty(p_qty, p_unit, it.base_unit);
  IF conv IS NULL OR conv < 0 THEN RAISE EXCEPTION 'invalid quantity/unit'; END IF;
  IF conv > 0 THEN
    INSERT INTO stock_batches(household_id, item_id, qty_initial, qty_remaining, expiry_date, expiry_source, origin)
    VALUES (hh, p_item, conv, conv, p_expiry, coalesce(p_expiry_source, CASE WHEN p_expiry IS NULL THEN 'none' ELSE 'estimated' END), 'opening') RETURNING id INTO bid;
  END IF;
  INSERT INTO inventory_events(household_id, item_id, batch_id, event_type, qty, actor, op_id, note)
  VALUES (hh, p_item, bid, 'opening', conv, auth.uid(), p_op, 'opening balance');
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_reconcile(p_op text, p_item uuid, p_counted numeric, p_unit text, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb; it items; conv numeric; s record; bid uuid;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_reconcile'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  SELECT * INTO it FROM items WHERE id = p_item AND household_id = hh FOR UPDATE;
  conv := public.convert_qty(p_counted, p_unit, it.base_unit);
  IF conv IS NULL OR conv < 0 THEN RAISE EXCEPTION 'invalid quantity/unit'; END IF;
  SELECT * INTO s FROM public._stock(p_item);
  IF conv < s.qty THEN
    PERFORM public._deduct(hh, p_item, s.qty - conv, 'reconciliation', p_op, NULL, NULL, coalesce(p_note,'stock count'));
  ELSIF conv > s.qty OR NOT s.known THEN
    IF conv > s.qty THEN
      INSERT INTO stock_batches(household_id, item_id, qty_initial, qty_remaining, origin) VALUES (hh, p_item, conv - s.qty, conv - s.qty, 'reconciliation') RETURNING id INTO bid;
    END IF;
    INSERT INTO inventory_events(household_id, item_id, batch_id, event_type, qty, actor, op_id, note)
    VALUES (hh, p_item, bid, 'reconciliation', conv - s.qty, auth.uid(), p_op, coalesce(p_note,'stock count'));
  END IF;
  PERFORM public._check_low(hh, p_item);
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'before', s.qty, 'after', conv), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_batch_expiry(p_batch uuid, p_expiry date, p_source text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN
  UPDATE stock_batches SET expiry_date = p_expiry, expiry_source = p_source WHERE id = p_batch AND household_id = hh;
END $$;

CREATE OR REPLACE FUNCTION public.admin_upsert_item(p_id uuid, p jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); v uuid;
BEGIN
  IF p_id IS NULL THEN
    INSERT INTO items(household_id, category_id, location_id, name_en, name_ur, emoji, base_unit, default_purchase_qty, low_threshold, gf_status, shelf_days)
    VALUES (hh, (p->>'category_id')::uuid, nullif(p->>'location_id','')::uuid, p->>'name_en', p->>'name_ur', coalesce(p->>'emoji','📦'), coalesce(p->>'base_unit','pc'),
      nullif(p->>'default_purchase_qty','')::numeric, nullif(p->>'low_threshold','')::numeric, coalesce(p->>'gf_status','unknown'), nullif(p->>'shelf_days','')::int)
    RETURNING id INTO v;
  ELSE
    UPDATE items SET
      category_id = coalesce((p->>'category_id')::uuid, category_id),
      location_id = CASE WHEN p ? 'location_id' THEN nullif(p->>'location_id','')::uuid ELSE location_id END,
      name_en = coalesce(p->>'name_en', name_en), name_ur = coalesce(p->>'name_ur', name_ur), emoji = coalesce(p->>'emoji', emoji),
      default_purchase_qty = CASE WHEN p ? 'default_purchase_qty' THEN nullif(p->>'default_purchase_qty','')::numeric ELSE default_purchase_qty END,
      low_threshold = CASE WHEN p ? 'low_threshold' THEN nullif(p->>'low_threshold','')::numeric ELSE low_threshold END,
      gf_status = coalesce(p->>'gf_status', gf_status),
      shelf_days = CASE WHEN p ? 'shelf_days' THEN nullif(p->>'shelf_days','')::int ELSE shelf_days END,
      active = coalesce((p->>'active')::boolean, active)
    WHERE id = p_id AND household_id = hh RETURNING id INTO v;
    IF v IS NULL THEN RAISE EXCEPTION 'item not found'; END IF;
  END IF;
  RETURN v;
END $$;

CREATE OR REPLACE FUNCTION public.admin_create_request(p_item uuid, p_qty numeric, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN
  PERFORM 1 FROM items WHERE id = p_item AND household_id = hh; IF NOT FOUND THEN RAISE EXCEPTION 'item not found'; END IF;
  RETURN public._ensure_request(hh, p_item, 'admin', p_qty, p_note);
END $$;

CREATE OR REPLACE FUNCTION public.admin_decide_request(p_id uuid, p_approve boolean, p_qty numeric, p_substitute uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); r shopping_requests;
BEGIN
  SELECT * INTO r FROM shopping_requests WHERE id = p_id AND household_id = hh FOR UPDATE;
  IF r.id IS NULL THEN RAISE EXCEPTION 'not found'; END IF;
  IF r.status NOT IN ('awaiting_approval','approved') THEN RAISE EXCEPTION 'request already %', r.status; END IF;
  IF p_substitute IS NOT NULL THEN
    PERFORM 1 FROM items WHERE id = p_substitute AND household_id = hh; IF NOT FOUND THEN RAISE EXCEPTION 'substitute not found'; END IF;
  END IF;
  UPDATE shopping_requests SET
    status = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    approved_qty = CASE WHEN p_approve THEN coalesce(p_qty, suggested_qty) END,
    substitute_item_id = p_substitute, decided_by = auth.uid(), decided_at = now(), updated_at = now()
  WHERE id = p_id;
END $$;

CREATE OR REPLACE FUNCTION public.admin_record_purchase(p_op text, p_vendor text, p_date date, p_paid_from text, p_receipt text, p_ocr jsonb, p_lines jsonb, p_verify boolean)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb; pid uuid; l jsonb; it items; r shopping_requests; conv numeric; tot numeric := 0; bought numeric;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_purchase'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  IF jsonb_array_length(coalesce(p_lines,'[]'::jsonb)) = 0 THEN RAISE EXCEPTION 'add at least one line'; END IF;
  INSERT INTO purchases(household_id, vendor, purchased_at, paid_from, receipt_path, ocr_suggestion, created_by)
  VALUES (hh, p_vendor, coalesce(p_date, current_date), coalesce(p_paid_from,'housekeeper_cash'), p_receipt, p_ocr, auth.uid()) RETURNING id INTO pid;
  FOR l IN SELECT * FROM jsonb_array_elements(p_lines) LOOP
    SELECT * INTO it FROM items WHERE id = (l->>'item_id')::uuid AND household_id = hh;
    IF it.id IS NULL THEN RAISE EXCEPTION 'item not found'; END IF;
    r := NULL;
    IF (l->>'request_id') IS NOT NULL THEN
      SELECT * INTO r FROM shopping_requests WHERE id = (l->>'request_id')::uuid AND household_id = hh FOR UPDATE;
      IF r.status NOT IN ('approved','partially_purchased') THEN RAISE EXCEPTION 'request for % is not approved', it.name_en; END IF;
      IF it.id <> r.item_id AND it.id IS DISTINCT FROM r.substitute_item_id THEN RAISE EXCEPTION 'substitution for % was not approved', it.name_en; END IF;
    END IF;
    conv := public.convert_qty((l->>'qty')::numeric, l->>'unit', it.base_unit);
    IF conv IS NULL OR conv <= 0 THEN RAISE EXCEPTION 'bad quantity/unit for %', it.name_en; END IF;
    INSERT INTO purchase_lines(household_id, purchase_id, request_id, item_id, qty, unit, qty_base, line_total)
    VALUES (hh, pid, r.id, it.id, (l->>'qty')::numeric, l->>'unit', conv, (l->>'line_total')::numeric);
    tot := tot + (l->>'line_total')::numeric;
    IF r.id IS NOT NULL THEN
      SELECT sum(qty_base) INTO bought FROM purchase_lines WHERE request_id = r.id;
      UPDATE shopping_requests SET status = CASE WHEN r.approved_qty IS NULL OR bought >= r.approved_qty THEN 'purchased' ELSE 'partially_purchased' END, updated_at = now() WHERE id = r.id;
    END IF;
  END LOOP;
  UPDATE purchases SET total = tot WHERE id = pid;
  IF p_verify THEN PERFORM public.admin_verify_purchase(pid); END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'purchase_id', pid, 'total', tot), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_verify_purchase(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); p purchases;
BEGIN
  SELECT * INTO p FROM purchases WHERE id = p_id AND household_id = hh FOR UPDATE;
  IF p.id IS NULL THEN RAISE EXCEPTION 'not found'; END IF;
  IF p.status = 'verified' THEN RETURN; END IF;
  UPDATE purchases SET status = 'verified', verified_by = auth.uid(), verified_at = now() WHERE id = p_id;
  INSERT INTO finance_ledger(household_id, entry_type, amount, purchase_id, affects_cash, note, created_by)
  VALUES (hh, 'expense', p.total, p.id, p.paid_from = 'housekeeper_cash', coalesce(p.vendor,'purchase'), auth.uid())
  ON CONFLICT (purchase_id) WHERE entry_type = 'expense' DO NOTHING;
END $$;

CREATE OR REPLACE FUNCTION public.admin_verify_receiving(p_op text, p_line uuid, p_receiving uuid, p_qty_base numeric, p_expiry date, p_expiry_source text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb; pl purchase_lines; bid uuid; it items; open_lines int; rq shopping_requests; exp date := p_expiry; src text := p_expiry_source;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_receive'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  SELECT * INTO pl FROM purchase_lines WHERE id = p_line AND household_id = hh FOR UPDATE;
  IF pl.id IS NULL THEN RAISE EXCEPTION 'line not found'; END IF;
  IF p_qty_base IS NULL OR p_qty_base <= 0 THEN RAISE EXCEPTION 'quantity must be positive'; END IF;
  IF pl.qty_received_base + p_qty_base > pl.qty_base THEN RAISE EXCEPTION 'cannot receive more than purchased (% remaining)', pl.qty_base - pl.qty_received_base; END IF;
  SELECT * INTO it FROM items WHERE id = pl.item_id;
  IF exp IS NULL AND it.shelf_days IS NOT NULL THEN exp := current_date + it.shelf_days; src := 'estimated'; END IF;
  INSERT INTO stock_batches(household_id, item_id, qty_initial, qty_remaining, expiry_date, expiry_source, origin)
  VALUES (hh, pl.item_id, p_qty_base, p_qty_base, exp, coalesce(src, CASE WHEN exp IS NULL THEN 'none' ELSE 'estimated' END), 'receive') RETURNING id INTO bid;
  INSERT INTO inventory_events(household_id, item_id, batch_id, event_type, qty, actor, op_id, ref_type, ref_id)
  VALUES (hh, pl.item_id, bid, 'receive', p_qty_base, auth.uid(), p_op, 'purchase_line', pl.id);
  UPDATE purchase_lines SET qty_received_base = qty_received_base + p_qty_base WHERE id = pl.id;
  IF p_receiving IS NOT NULL THEN
    UPDATE receiving_lines SET status = 'verified', verified_qty_base = p_qty_base, verified_by = auth.uid(), expiry_date = exp, expiry_source = src
    WHERE id = p_receiving AND household_id = hh;
  ELSE
    INSERT INTO receiving_lines(household_id, purchase_line_id, verified_qty_base, status, expiry_date, expiry_source, verified_by, op_id)
    VALUES (hh, pl.id, p_qty_base, 'verified', exp, src, auth.uid(), p_op);
  END IF;
  IF pl.request_id IS NOT NULL THEN
    SELECT * INTO rq FROM shopping_requests WHERE id = pl.request_id FOR UPDATE;
    SELECT count(*) INTO open_lines FROM purchase_lines WHERE request_id = rq.id AND qty_received_base < qty_base;
    UPDATE shopping_requests SET status = CASE WHEN open_lines = 0 AND rq.status = 'purchased' THEN 'received' ELSE 'partially_received' END, updated_at = now()
    WHERE id = rq.id;
  END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'batch_id', bid), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_return(p_op text, p_line uuid, p_qty_base numeric, p_refund numeric, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb; pl purchase_lines; p purchases; d numeric := 0;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_return'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  SELECT * INTO pl FROM purchase_lines WHERE id = p_line AND household_id = hh FOR UPDATE;
  SELECT * INTO p FROM purchases WHERE id = pl.purchase_id;
  IF coalesce(p_qty_base,0) > 0 THEN
    IF p_qty_base > pl.qty_received_base THEN RAISE EXCEPTION 'cannot return more than received'; END IF;
    d := public._deduct(hh, pl.item_id, p_qty_base, 'return', p_op, 'purchase_line', pl.id, p_note);
  END IF;
  IF coalesce(p_refund,0) > 0 THEN
    INSERT INTO finance_ledger(household_id, entry_type, amount, purchase_id, affects_cash, note, op_id, created_by)
    VALUES (hh, 'refund', p_refund, p.id, p.paid_from = 'housekeeper_cash', p_note, p_op, auth.uid());
  END IF;
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true, 'returned', d), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_finance_entry(p_op text, p_type text, p_amount numeric, p_note text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); prev jsonb;
BEGIN
  prev := public._begin_op(hh, p_op, 'admin_finance'); IF prev IS NOT NULL THEN RETURN prev; END IF;
  IF p_type NOT IN ('advance','change_return','correction') THEN RAISE EXCEPTION 'use purchases/returns for expenses and refunds'; END IF;
  IF p_type <> 'correction' AND (p_amount IS NULL OR p_amount <= 0) THEN RAISE EXCEPTION 'amount must be positive'; END IF;
  INSERT INTO finance_ledger(household_id, entry_type, amount, affects_cash, note, op_id, created_by)
  VALUES (hh, p_type, p_amount, true, p_note, p_op, auth.uid());
  RETURN public._finish_op(hh, p_op, jsonb_build_object('ok', true), false);
END $$;

CREATE OR REPLACE FUNCTION public.admin_plan_meal(p_date date, p_slot text, p_recipe text, p_title text, p_portions text, p_leftover uuid, p_missing uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); m uuid; n int := 0; r jsonb;
BEGIN
  INSERT INTO meal_plans(household_id, plan_date, slot, recipe_key, title, portions, leftover_id, created_by)
  VALUES (hh, p_date, p_slot, p_recipe, p_title, p_portions, p_leftover, auth.uid())
  ON CONFLICT (household_id, plan_date, slot) DO UPDATE SET recipe_key = EXCLUDED.recipe_key, title = EXCLUDED.title, portions = EXCLUDED.portions, leftover_id = EXCLUDED.leftover_id;
  IF p_missing IS NOT NULL THEN
    FOREACH m IN ARRAY p_missing LOOP
      PERFORM 1 FROM items WHERE id = m AND household_id = hh;
      IF FOUND THEN r := public._ensure_request(hh, m, 'meal_plan', NULL, p_title); IF (r->>'created')::boolean THEN n := n + 1; END IF; END IF;
    END LOOP;
  END IF;
  RETURN jsonb_build_object('ok', true, 'requests_created', n);
END $$;

CREATE OR REPLACE FUNCTION public.admin_remove_meal(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN DELETE FROM meal_plans WHERE id = p_id AND household_id = hh; END $$;

CREATE OR REPLACE FUNCTION public.admin_update_settings(p_budget numeric, p_quiet_start time, p_quiet_end time)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN
  UPDATE household_settings SET monthly_budget = coalesce(p_budget, monthly_budget), quiet_start = coalesce(p_quiet_start, quiet_start),
    quiet_end = coalesce(p_quiet_end, quiet_end), updated_at = now() WHERE household_id = hh;
END $$;

CREATE OR REPLACE FUNCTION public.admin_resolve_conflict(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN UPDATE conflict_cases SET status = 'resolved', resolved_by = auth.uid(), resolved_at = now() WHERE id = p_id AND household_id = hh; END $$;

CREATE OR REPLACE FUNCTION public.admin_mark_notifications_read(p_ids uuid[])
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN UPDATE notifications SET read_at = now() WHERE household_id = hh AND (p_ids IS NULL OR id = ANY(p_ids)) AND read_at IS NULL; END $$;

CREATE OR REPLACE FUNCTION public.admin_revoke_device(p_device uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true); d devices;
BEGIN
  SELECT * INTO d FROM devices WHERE id = p_device AND household_id = hh FOR UPDATE;
  IF d.id IS NULL THEN RAISE EXCEPTION 'device not found'; END IF;
  UPDATE devices SET revoked_at = now() WHERE id = d.id;
  UPDATE pairing_tokens SET used_at = coalesce(used_at, now()) WHERE device_id = d.id;
  IF d.user_id IS NOT NULL THEN UPDATE user_roles SET active = false WHERE user_id = d.user_id AND household_id = hh AND role = 'housekeeper'; END IF;
  RETURN d.user_id;
END $$;

CREATE OR REPLACE FUNCTION public.device_heartbeat()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE devices SET last_seen_at = now() WHERE user_id = auth.uid() AND revoked_at IS NULL
$$;

-- Briefing (cron + on demand)
CREATE OR REPLACE FUNCTION public._generate_briefing(hh uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE b jsonb; month_start date := date_trunc('month', (now() AT TIME ZONE 'Asia/Karachi'))::date;
BEGIN
  SELECT jsonb_build_object(
    'low_stock', (SELECT count(*) FROM items i, LATERAL public._stock(i.id) s WHERE i.household_id = hh AND s.known AND i.low_threshold IS NOT NULL AND s.qty <= i.low_threshold),
    'approvals', (SELECT count(*) FROM shopping_requests WHERE household_id = hh AND status = 'awaiting_approval'),
    'to_receive', (SELECT count(*) FROM receiving_lines WHERE household_id = hh AND status = 'reported'),
    'expiring', (SELECT count(*) FROM stock_batches WHERE household_id = hh AND qty_remaining > 0 AND expiry_date <= current_date + 2),
    'unsafe_leftovers', (SELECT count(*) FROM leftover_records WHERE household_id = hh AND status = 'available' AND (storage IN ('counter','unknown') OR cooled_properly IS NOT TRUE)),
    'meals_today', (SELECT count(*) FROM meal_plans WHERE household_id = hh AND plan_date = (now() AT TIME ZONE 'Asia/Karachi')::date),
    'waste_7d', (SELECT count(*) FROM waste_events WHERE household_id = hh AND undone_at IS NULL AND created_at > now() - interval '7 days'),
    'spent_month', (SELECT coalesce(sum(CASE entry_type WHEN 'expense' THEN amount WHEN 'refund' THEN -amount ELSE 0 END),0) FROM finance_ledger WHERE household_id = hh AND created_at >= month_start),
    'conflicts', (SELECT count(*) FROM conflict_cases WHERE household_id = hh AND status = 'open')
  ) INTO b;
  PERFORM public._notify(hh, 'briefing', 'routine', '11am briefing',
    format('%s low · %s approvals · %s to receive · %s expiring · %s meals planned · PKR %s spent this month',
      b->>'low_stock', b->>'approvals', b->>'to_receive', b->>'expiring', b->>'meals_today', round((b->>'spent_month')::numeric)),
    'briefing_' || (now() AT TIME ZONE 'Asia/Karachi')::date);
  RETURN b;
END $$;

CREATE OR REPLACE FUNCTION public.admin_briefing()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(true);
BEGIN RETURN public._generate_briefing(hh); END $$;

CREATE OR REPLACE FUNCTION public.run_daily_briefings()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE h record;
BEGIN FOR h IN SELECT id FROM households LOOP PERFORM public._generate_briefing(h.id); END LOOP; END $$;

-- ===== permissions on functions =====
DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig, p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.prokind = 'f' LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f.sig);
    IF f.proname LIKE '\_%' OR f.proname IN ('run_daily_briefings','audit_row','forbid_mutation') THEN
      EXECUTE format('REVOKE ALL ON FUNCTION %s FROM authenticated', f.sig);
    ELSE
      EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f.sig);
    END IF;
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', f.sig);
  END LOOP;
END $$;