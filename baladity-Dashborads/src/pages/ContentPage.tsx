import { useState, useEffect } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";
import { useNavigate } from "react-router-dom";
import type { Project, Facility, EmergencyContact, Department } from "../types";

export default function ContentPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState("projects");
  const [departments, setDepartments] = useState<Department[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [contacts, setContacts] = useState<EmergencyContact[]>([]);
  const [showForm, setShowForm] = useState(false);
  // Project fields
  const [projName, setProjName] = useState(""); const [projDesc, setProjDesc] = useState("");
  const [projProgress, setProjProgress] = useState(0); const [projDeptId, setProjDeptId] = useState("");
  // Facility fields
  const [facName, setFacName] = useState(""); const [facType, setFacType] = useState("park");
  const [facLat, setFacLat] = useState(""); const [facLng, setFacLng] = useState(""); const [facAddr, setFacAddr] = useState("");
  // Contact fields
  const [conName, setConName] = useState(""); const [conNumber, setConNumber] = useState("");
  const [conDesc, setConDesc] = useState(""); const [conIcon, setConIcon] = useState("📞");

  const resetForms = () => {
    setProjName(""); setProjDesc(""); setProjProgress(0); setProjDeptId("");
    setFacName(""); setFacType("park"); setFacLat(""); setFacLng(""); setFacAddr("");
    setConName(""); setConNumber(""); setConDesc(""); setConIcon("📞");
  };

  useEffect(() => { if (!isLoading && !user) navigate("/login"); }, [user, isLoading, navigate]);
  useEffect(() => { loadAll(); }, []);

  const loadAll = async () => {
    try { const r = await api.get<Department[]>("/api/admin/departments"); setDepartments(Array.isArray(r) ? r : []); } catch (e) { console.error("loadDepts", e); }
    try { const r = await api.get<Project[]>("/api/admin/projects"); setProjects(Array.isArray(r) ? r : []); } catch (e) { console.error("loadProjects", e); }
    try { const r = await api.get<Facility[]>("/api/admin/facilities"); setFacilities(Array.isArray(r) ? r : []); } catch (e) { console.error("loadFacilities", e); }
    try { const r = await api.get<EmergencyContact[]>("/api/admin/emergency-contacts"); setContacts(Array.isArray(r) ? r : []); } catch (e) { console.error("loadContacts", e); }
  };

  const handleCreateProject = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post("/api/admin/projects", { name: projName, description: projDesc, progress: projProgress, startDate: new Date().toISOString(), departmentId: projDeptId });
      setProjName(""); setProjDesc(""); setProjProgress(0); setProjDeptId(""); setShowForm(false); loadAll();
    } catch (err: any) { alert(err.message); }
  };

  const handleCreateFacility = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post("/api/admin/facilities", { name: facName, type: facType, lat: parseFloat(facLat), lng: parseFloat(facLng), address: facAddr });
      resetForms(); setShowForm(false); loadAll();
    } catch (err: any) { alert(err.message); }
  };

  const handleCreateContact = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await api.post("/api/admin/emergency-contacts", { name: conName, number: conNumber, description: conDesc, icon: conIcon });
      resetForms(); setShowForm(false); loadAll();
    } catch (err: any) { alert(err.message); }
  };

  const handleUpdateProgress = async (id: string, progress: number) => { try { await api.patch(`/api/admin/projects/${id}`, { progress }); loadAll(); } catch (e) { console.error("updateProgress", e); } };
  const handleDelete = async (type: string, id: string) => { if (!confirm("تأكيد الحذف؟")) return; try { await api.delete(`/api/admin/${type}/${id}`); loadAll(); } catch (e) { console.error("delete", e); } };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">إدارة المحتوى</h1>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">{showForm ? "إلغاء" : "إضافة"}</button>
      </div>
      <div className="flex gap-2">
        {[{ k: "projects", l: "المشاريع" }, { k: "facilities", l: "المرافق" }, { k: "contacts", l: "جهات الاتصال" }].map(t => (
          <button key={t.k} onClick={() => { setTab(t.k); setShowForm(false); }} className={`px-4 py-2 rounded-lg text-sm ${tab === t.k ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>{t.l}</button>
        ))}
      </div>

      {tab === "projects" && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateProject} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={projName} onChange={e => setProjName(e.target.value)} placeholder="اسم المشروع" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <textarea value={projDesc} onChange={e => setProjDesc(e.target.value)} placeholder="الوصف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
              <div className="grid grid-cols-2 gap-3">
                <select value={projDeptId} onChange={e => setProjDeptId(e.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                  <option value="">القسم...</option>
                  {departments.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}
                </select>
                <div className="flex items-center gap-2">
                  <span className="text-sm text-slate-400">{projProgress}%</span>
                  <input type="range" min="0" max="100" value={projProgress} onChange={e => setProjProgress(Number(e.target.value))} className="flex-1" />
                </div>
              </div>
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء</button>
            </form>
          )}
          {projects.map(p => (
            <div key={p.id} className="bg-slate-900 rounded-xl p-4 border border-slate-800">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <h3 className="font-medium">{p.name}</h3>
                  <p className="text-sm text-slate-400">{p.description}</p>
                  <span className="text-xs text-slate-500">{p.department?.name}</span>
                </div>
                <button onClick={() => handleDelete("projects", p.id)} className="text-red-400 text-xs">حذف</button>
              </div>
              <div className="flex items-center gap-3">
                <div className="flex-1 bg-slate-800 rounded-full h-2">
                  <div className="h-2 rounded-full bg-emerald-500 transition-all" style={{ width: `${p.progress}%` }} />
                </div>
                <span className="text-sm text-slate-400 w-12 text-left">{p.progress}%</span>
                <input type="range" min="0" max="100" value={p.progress} onChange={e => handleUpdateProgress(p.id, Number(e.target.value))} className="w-24" />
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === "facilities" && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateFacility} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={facName} onChange={e => setFacName(e.target.value)} placeholder="اسم المرفق" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <select value={facType} onChange={e => setFacType(e.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                <option value="park">حديقة</option><option value="restroom">دورة مياه</option><option value="clinic">عيادة</option>
                <option value="parking">موقف سيارات</option><option value="mosque">مسجد</option><option value="market">سوق</option>
              </select>
              <div className="grid grid-cols-2 gap-3">
                <input value={facLat} onChange={e => setFacLat(e.target.value)} placeholder="خط العرض" type="number" step="any" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
                <input value={facLng} onChange={e => setFacLng(e.target.value)} placeholder="خط الطول" type="number" step="any" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              </div>
              <input value={facAddr} onChange={e => setFacAddr(e.target.value)} placeholder="العنوان" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء</button>
            </form>
          )}
          <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
          <table className="w-full">
            <thead><tr className="border-b border-slate-800 text-sm text-slate-500">
              <th className="text-right p-3">الاسم</th><th className="text-right p-3">النوع</th><th className="text-right p-3">العنوان</th><th className="text-right p-3">إجراء</th>
            </tr></thead>
            <tbody>
              {facilities.map(f => (
                <tr key={f.id} className="border-b border-slate-800/50 text-sm">
                  <td className="p-3">{f.name}</td><td className="p-3 text-slate-400">{f.type}</td>
                  <td className="p-3 text-slate-400">{f.address}</td>
                  <td className="p-3"><button onClick={() => handleDelete("facilities", f.id)} className="text-red-400 text-xs">حذف</button></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      )}

      {tab === "contacts" && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateContact} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={conName} onChange={e => setConName(e.target.value)} placeholder="اسم الجهة" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <input value={conNumber} onChange={e => setConNumber(e.target.value)} placeholder="رقم الهاتف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required dir="ltr" />
              <input value={conDesc} onChange={e => setConDesc(e.target.value)} placeholder="وصف (اختياري)" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              <select value={conIcon} onChange={e => setConIcon(e.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                <option value="📞">📞 هاتف</option><option value="🚑">🚑 إسعاف</option><option value="🚒">🚒 إطفاء</option>
                <option value="👮">👮 شرطة</option><option value="💡">💡 كهرباء</option><option value="🔧">🔧 صيانة</option>
              </select>
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء</button>
            </form>
          )}
          <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
            <table className="w-full">
              <thead><tr className="border-b border-slate-800 text-sm text-slate-500">
                <th className="text-right p-3">الاسم</th><th className="text-right p-3">الرقم</th><th className="text-right p-3">الوصف</th><th className="text-right p-3">إجراء</th>
              </tr></thead>
              <tbody>
                {contacts.map(c => (
                  <tr key={c.id} className="border-b border-slate-800/50 text-sm">
                    <td className="p-3">{c.icon || "📞"} {c.name}</td><td className="p-3 text-emerald-400 font-bold">{c.number}</td>
                    <td className="p-3 text-slate-400">{c.description}</td>
                    <td className="p-3"><button onClick={() => handleDelete("emergency-contacts", c.id)} className="text-red-400 text-xs">حذف</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
