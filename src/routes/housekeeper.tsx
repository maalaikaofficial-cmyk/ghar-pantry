import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";

type Item = { id: string; name_en: string; name_ur: string; emoji: string; image_path: string | null; category_id: string };
type Category = { id: string; name_en: string; name_ur: string; sort: number };
type Status = "yes" | "some" | "no";
const choices: { value: Status; ur: string; en: string; color: string }[] = [
  { value: "yes", ur: "موجود ہے", en: "Available", color: "bg-green-100 border-green-600" },
  { value: "some", ur: "تھوڑا باقی ہے", en: "Some left", color: "bg-amber-100 border-amber-600" },
  { value: "no", ur: "ختم ہو گیا", en: "Finished", color: "bg-red-100 border-red-600" },
];

export const Route = createFileRoute("/housekeeper")({ component: Housekeeper });

function Housekeeper() {
  const [items, setItems] = useState<Item[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [category, setCategory] = useState<string>("all");
  const [checks, setChecks] = useState<Record<string, Status>>({});
  const [saving, setSaving] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [ready, setReady] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const { data: auth, error: authError } = await supabase.auth.getUser();
        if (authError) throw authError;
        if (!auth.user) { if (alive) setReady(true); return; }
        if (alive) setAuthenticated(true);
        const [itemResult, categoryResult] = await Promise.all([
          supabase.from("items").select("id,name_en,name_ur,emoji,image_path,category_id").eq("active",true).order("sort"),
          supabase.from("categories").select("id,name_en,name_ur,sort").order("sort"),
        ]);
        if (itemResult.error) throw itemResult.error;
        if (categoryResult.error) throw categoryResult.error;
        if (alive) {
          setItems(itemResult.data ?? []);
          setCategories(categoryResult.data ?? []);
        }
      } catch (e) { if (alive) setError(e instanceof Error ? e.message : String(e)); }
      finally { if (alive) setReady(true); }
    })();
    return () => { alive = false; };
  }, []);

  async function save(item: Item, status: Status) {
    if (saving) return;
    setSaving(item.id); setError("");
    try {
      const { error: saveError } = await supabase.rpc("submit_housekeeper_stock", { p_item: item.id, p_status: status });
      if (saveError) throw saveError;
      setChecks(previous => ({ ...previous, [item.id]: status }));
    } catch (e) { setError(e instanceof Error ? e.message : String(e)); }
    finally { setSaving(null); }
  }

  const visible = items.filter(item => category === "all" || item.category_id === category);
  return (
    <main className="mx-auto min-h-screen max-w-3xl bg-white px-4 py-6 text-slate-900">
      <header className="mb-6 text-center">
        <h1 className="text-3xl font-bold" lang="ur">گھر پینٹری</h1>
        <p className="mt-2 text-lg" lang="ur">گھر میں کیا موجود ہے؟</p>
        <p className="text-sm text-slate-500">Tap one answer for each product</p>
      </header>
      {!ready && <p role="status">Loading products…</p>}
      {ready && !authenticated && <p role="alert" className="rounded-xl bg-amber-100 p-4">Please sign in to your household account first.</p>}
      {error && <p role="alert" className="mb-4 rounded-xl bg-red-50 p-4 text-red-800">{error}</p>}
      {authenticated && (
        <>
          <nav className="mb-6 flex gap-2 overflow-x-auto pb-2" aria-label="Product categories">
            <button type="button" onClick={() => setCategory("all")} className={`shrink-0 rounded-full border-2 px-5 py-3 font-semibold ${category==="all"?"border-slate-900 bg-slate-100":"border-slate-200"}`}>سب</button>
            {categories.map(c => <button key={c.id} type="button" onClick={() => setCategory(c.id)} className={`shrink-0 rounded-full border-2 px-5 py-3 font-semibold ${category===c.id?"border-slate-900 bg-slate-100":"border-slate-200"}`}>{c.name_ur}</button>)}
          </nav>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {visible.map(item => (
              <section key={item.id} className="rounded-2xl border border-slate-200 p-4 shadow-sm">
                <div className="flex min-h-32 flex-col items-center justify-center gap-2">
                  {item.image_path ? <img src={item.image_path} alt={item.name_en} className="h-28 w-28 object-contain" /> : <span aria-hidden="true" className="text-7xl">{item.emoji}</span>}
                  <h2 className="text-center text-2xl font-bold" lang="ur" dir="rtl">{item.name_ur}</h2>
                  <p className="text-sm text-slate-500">{item.name_en}</p>
                </div>
                <div className="mt-4 grid grid-cols-3 gap-2">
                  {choices.map(choice => (
                    <button type="button" key={choice.value} disabled={saving !== null}
                      aria-pressed={checks[item.id]===choice.value}
                      onClick={() => save(item,choice.value)}
                      className={`min-h-20 rounded-xl border-2 px-1 py-3 text-center disabled:opacity-50 ${checks[item.id]===choice.value?choice.color:"border-slate-200 bg-white"}`}>
                      <span className="block text-base font-bold" lang="ur" dir="rtl">{choice.ur}</span>
                      <span className="mt-1 block text-xs text-slate-600">{choice.en}</span>
                    </button>
                  ))}
                </div>
                {saving===item.id && <p role="status" className="mt-2 text-center text-sm">Saving…</p>}
                {checks[item.id] && <p role="status" className="mt-2 text-center text-sm text-green-700">✓ محفوظ ہو گیا</p>}
              </section>
            ))}
          </div>
          {ready && visible.length===0 && <p className="text-center text-slate-500">No products in this category.</p>}
        </>
      )}
    </main>
  );
}
