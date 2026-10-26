-- ISOLATED PostgreSQL SHIM ONLY. No actual file decoding is claimed by this
-- fixture. Decoder/HTTP tests exercise bytes separately. This temporary
-- privileged helper models the trusted worker, NEVER an app-facing RPC.
create schema local_test;
grant usage on schema local_test to authenticated;
create function local_test.fixture_verify_photo(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare u public.evidence_upload%rowtype; t jsonb; mime text;
begin
  select * into u from public.evidence_upload where upload_id=p_id;
  t := public.claim_evidence_validation(u.booking_id,u.upload_id,u.provider_id);
  assert t->>'state'='processing';
  mime := case when right(u.object_path,4)='.jpg' then 'image/jpeg' else 'image/png' end;
  insert into storage.objects(bucket_id,name,metadata) values('cleaning-evidence',u.object_path,
    jsonb_build_object('size',128,'mimetype',mime));
  assert public.finish_evidence_validation(u.upload_id,(t->>'token')::uuid,u.sha256,
    repeat('e',64),128,1,1,mime);
end $$;
-- Global function defaults are now deny-by-default, even for local fixtures.
grant execute on function local_test.fixture_verify_photo(uuid) to authenticated;
