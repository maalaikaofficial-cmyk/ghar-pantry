-- Three-choice visual stock checks for housekeepers.
ALTER TABLE public.availability_checks DROP CONSTRAINT IF EXISTS availability_checks_status_check;
ALTER TABLE public.availability_checks ADD CONSTRAINT availability_checks_status_check CHECK (status IN ('yes','some','no','unknown'));

CREATE OR REPLACE FUNCTION public.submit_housekeeper_stock(p_item uuid, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE hh uuid := public._ctx(); v_item public.items; v_id uuid; v_request jsonb := '{}'::jsonb;
BEGIN
  IF p_status NOT IN ('yes','some','no') THEN RAISE EXCEPTION 'Invalid stock status'; END IF;
  SELECT * INTO v_item FROM public.items WHERE id=p_item AND household_id=hh AND active;
  IF NOT FOUND THEN RAISE EXCEPTION 'Product not found'; END IF;
  INSERT INTO public.availability_checks(household_id,item_id,status,check_date,actor)
  VALUES(hh,p_item,p_status,(now() AT TIME ZONE 'Asia/Karachi')::date,auth.uid())
  RETURNING id INTO v_id;
  IF p_status IN ('some','no') THEN
    v_request := public._ensure_request(hh,p_item,'housekeeper_stock',NULL,
      CASE WHEN p_status='some' THEN 'Some left' ELSE 'Finished' END);
  END IF;
  RETURN jsonb_build_object('check_id',v_id,'status',p_status,'shopping_request',v_request);
END $$;
REVOKE ALL ON FUNCTION public.submit_housekeeper_stock(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_housekeeper_stock(uuid,text) TO authenticated;
