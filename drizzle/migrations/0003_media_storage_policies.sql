CREATE POLICY "members upload household media" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'media' AND (storage.foldername(name))[1] = public.my_household()::text);
CREATE POLICY "members read household media" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'media' AND (storage.foldername(name))[1] = public.my_household()::text);