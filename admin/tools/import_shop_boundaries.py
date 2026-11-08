"""Run with an authenticated Supabase CLI; no database keys are embedded."""
import gzip,json,pathlib,subprocess,tempfile,argparse
parser=argparse.ArgumentParser()
parser.add_argument('--apply',action='store_true',help='Write the archive to the linked database')
args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[2]
rows=json.loads(gzip.decompress((root/'admin/data/shop_boundaries/india_subdistricts.json.gz').read_bytes()))
print(f'{len(rows)} sub-district boundaries in archive')
if not args.apply:
 print('Dry run. Use --apply after checking the linked project.');raise SystemExit(0)
cli=root/'node_modules/.bin/supabase.cmd'
chunks=[];chunk=[];size=0
for r in rows:
 s=json.dumps(r,separators=(',',':'))
 if size+len(s)>2000000 and chunk:chunks.append(chunk);chunk=[];size=0
 chunk.append(s);size+=len(s)
if chunk:chunks.append(chunk)
for i,chunk in enumerate(chunks):
 sql="""insert into public.administrative_region_boundaries(region_id,geometry,source_url,source_shape_id,source_year)
select j->>'region_id',j->'geometry',j->>'source_url',j->>'source_shape_id',(j->>'source_year')::int
from jsonb_array_elements($boundary$["""+','.join(chunk)+"""]$boundary$::jsonb) j
on conflict(region_id) do update set geometry=excluded.geometry,source_url=excluded.source_url,source_shape_id=excluded.source_shape_id,source_year=excluded.source_year,imported_at=now();"""
 with tempfile.NamedTemporaryFile(mode='w',suffix='.sql',encoding='utf-8',delete=False) as f:
  f.write(sql);name=f.name
 try:
  for attempt in range(3):
   result=subprocess.run([str(cli),'db','query','--linked','--file',name,'--output','json'],cwd=root,capture_output=True,text=True)
   if not result.returncode:break
   if 'Transport error' not in result.stderr:raise RuntimeError(result.stderr)
  else:raise RuntimeError(result.stderr)
 finally:pathlib.Path(name).unlink(missing_ok=True)
 print(f'Imported {i+1}/{len(chunks)}')
