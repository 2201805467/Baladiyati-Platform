import { useState, useEffect } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";
import { useNavigate } from "react-router-dom";
import type { Report, PaginatedResponse } from "../types";

const statusBadge: Record<string, string> = {
  NEW: "bg-blue-500/20 text-blue-400", ASSIGNED: "bg-amber-500/20 text-amber-400",
  IN_PROGRESS: "bg-purple-500/20 text-purple-400", RESOLVED: "bg-emerald-500/20 text-emerald-400", REJECTED: "bg-red-500/20 text-red-400",
};

export default function TechnicalPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<Report[]>([]);
  const [selected, setSelected] = useState<Report | null>(null);
  const [filter, setFilter] = useState("");
  const [noteText, setNoteText] = useState("");
  const [resolveNote, setResolveNote] = useState("");
  const [showResolve, setShowResolve] = useState(false);

  useEffect(() => { if (!isLoading && !user) navigate("/login"); }, [user, isLoading, navigate]);
  useEffect(() => { loadReports(); }, [filter]);

  const loadReports = async () => {
    try {
      const qs = filter ? `?status=${filter}` : "";
      setReports((await api.get<PaginatedResponse<Report>>(`/department/reports${qs}`)).data);
    } catch (e) { console.error("loadReports", e); }
  };

  const handleStatus = async (reportId: string, status: string, note?: string) => {
    try { await api.patch(`/department/reports/${reportId}/status`, { status: status.toLowerCase(), note }); loadReports(); setSelected(null); } catch (e: any) { alert(e.message); }
  };

  const handleAddNote = async (reportId: string) => {
    if (!noteText.trim()) return;
    try { await api.post(`/department/reports/${reportId}/comments`, { comment: noteText }); setNoteText(""); loadReports(); } catch (e: any) { alert(e.message); }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  const filtered = reports;
  const counts = { NEW: reports.filter(r => r.status === "NEW").length, IN_PROGRESS: reports.filter(r => r.status === "IN_PROGRESS").length, RESOLVED: reports.filter(r => r.status === "RESOLVED").length };

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-emerald-400">لوحة الصيانة</h1>
      <div className="grid grid-cols-4 gap-4">
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center">
          <div className="text-2xl font-bold text-blue-400">{counts.NEW}</div><div className="text-xs text-slate-500">جديد</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center">
          <div className="text-2xl font-bold text-purple-400">{counts.IN_PROGRESS}</div><div className="text-xs text-slate-500">قيد المعالجة</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center">
          <div className="text-2xl font-bold text-emerald-400">{counts.RESOLVED}</div><div className="text-xs text-slate-500">محلول</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center">
          <div className="text-2xl font-bold text-slate-400">{reports.length}</div><div className="text-xs text-slate-500">المجموع</div>
        </div>
      </div>

      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="flex gap-2 mb-4 flex-wrap">
            {["", "NEW", "ASSIGNED", "IN_PROGRESS", "RESOLVED"].map(s => (
              <button key={s} onClick={() => setFilter(s)} className={`px-3 py-1.5 rounded-lg text-xs ${filter === s ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>{s || "الكل"}</button>
            ))}
          </div>
          <div className="grid grid-cols-2 gap-3 max-h-[600px] overflow-y-auto">
            {filtered.map(r => (
              <div key={r.id} onClick={() => setSelected(r)} className={`p-3 rounded-lg cursor-pointer border ${selected?.id === r.id ? "bg-emerald-600/10 border-emerald-600" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                <div className="flex gap-2">
                  {r.imageUrl && <img src={r.imageUrl} alt="" className="w-10 h-10 rounded object-cover shrink-0" />}
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between mb-1">
                      <span className="font-medium text-sm line-clamp-1">{r.title}</span>
                      <span className={`px-2 py-0.5 rounded text-xs shrink-0 ${statusBadge[r.status]}`}>{r.status}</span>
                    </div>
                    <p className="text-xs text-slate-500 line-clamp-2">{r.description}</p>
                    {r.slaDeadline && <p className={`text-xs mt-1 ${new Date(r.slaDeadline) < new Date() ? "text-red-400" : "text-slate-600"}`}>SLA: {new Date(r.slaDeadline).toLocaleDateString("ar")}</p>}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
          {selected ? (
            <div className="space-y-4">
              <h2 className="text-lg font-bold">{selected.title}</h2>
              <span className={`px-2 py-1 rounded text-xs ${statusBadge[selected.status]}`}>{selected.status}</span>
              <p className="text-sm text-slate-400"><strong>المواطن:</strong> {selected.citizen?.name}</p>
              <p className="text-sm text-slate-400"><strong>القسم:</strong> {selected.department?.name || "-"}</p>
              {selected.rating && <p className="text-sm text-slate-400"><strong>التقييم:</strong> {"⭐".repeat(selected.rating)}</p>}
              <p className="text-sm">{selected.description}</p>
              {(selected.imageUrl || selected.afterImageUrl) && (
                <div className="grid grid-cols-2 gap-2">
                  {selected.imageUrl && (
                    <div>
                      <p className="text-xs text-slate-500 mb-1">قبل</p>
                      <img src={selected.imageUrl} alt="قبل" className="w-full h-32 object-cover rounded-lg cursor-pointer" onClick={() => window.open(selected.imageUrl!, "_blank")} />
                    </div>
                  )}
                  {selected.afterImageUrl && (
                    <div>
                      <p className="text-xs text-slate-500 mb-1">بعد</p>
                      <img src={selected.afterImageUrl} alt="بعد" className="w-full h-32 object-cover rounded-lg cursor-pointer" onClick={() => window.open(selected.afterImageUrl!, "_blank")} />
                    </div>
                  )}
                </div>
              )}
              <div className="flex flex-wrap gap-2">
                {selected.status === "ASSIGNED" && <button onClick={() => handleStatus(selected.id, "IN_PROGRESS", noteText)} className="px-4 py-2 bg-purple-600 rounded-lg text-sm">المباشرة بالصيانة</button>}
                {selected.status === "IN_PROGRESS" && <button onClick={() => setShowResolve(true)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">تم الحل</button>}
              </div>
              <div>
                <label className="block text-sm text-slate-400 mb-1">ملاحظة:</label>
                <div className="flex gap-2">
                  <input value={noteText} onChange={e => setNoteText(e.target.value)} placeholder="اكتب ملاحظة..." className="flex-1 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
                  <button onClick={() => handleAddNote(selected.id)} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">إرسال</button>
                </div>
              </div>
              {showResolve && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50">
                  <div className="bg-slate-900 p-6 rounded-xl border border-slate-700 w-96">
                    <h3 className="font-bold mb-3">تأكيد حل البلاغ</h3>
                    <textarea value={resolveNote} onChange={e => setResolveNote(e.target.value)} placeholder="تقرير الإنجاز..." className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm mb-3 h-24" />
                    <div className="flex gap-2 justify-end">
                      <button onClick={() => setShowResolve(false)} className="px-3 py-1.5 bg-slate-700 rounded-lg text-sm">إلغاء</button>
                      <button onClick={() => { handleStatus(selected.id, "RESOLVED", resolveNote); setShowResolve(false); }} className="px-3 py-1.5 bg-emerald-600 rounded-lg text-sm">تأكيد</button>
                    </div>
                  </div>
                </div>
              )}
            </div>
          ) : <p className="text-slate-500 text-sm text-center py-12">اختر بلاغاً لعرض التفاصيل</p>}
        </div>
      </div>
    </div>
  );
}
