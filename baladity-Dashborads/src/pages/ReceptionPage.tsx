import { useState, useEffect } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";
import { useNavigate } from "react-router-dom";
import type { Report, Suggestion, PaginatedResponse, Department } from "../types";

const statusBadge: Record<string, string> = {
  NEW: "bg-blue-500/20 text-blue-400",
  ASSIGNED: "bg-amber-500/20 text-amber-400",
  IN_PROGRESS: "bg-purple-500/20 text-purple-400",
  RESOLVED: "bg-emerald-500/20 text-emerald-400",
  REJECTED: "bg-red-500/20 text-red-400",
};
const statusBadgeSuggestion: Record<string, string> = {
  NEW: "bg-blue-500/20 text-blue-400",
  UNDER_REVIEW: "bg-amber-500/20 text-amber-400",
  ACCEPTED: "bg-emerald-500/20 text-emerald-400",
  REJECTED: "bg-red-500/20 text-red-400",
  EXECUTING: "bg-purple-500/20 text-purple-400",
  IMPLEMENTED: "bg-emerald-500/20 text-emerald-400",
  CANCELLED: "bg-slate-500/20 text-slate-400",
};
const priorityBadge: Record<string, string> = {
  HIGH: "bg-red-500/20 text-red-400",
  MEDIUM: "bg-amber-500/20 text-amber-400",
  LOW: "bg-slate-500/20 text-slate-400",
};

export default function ReceptionPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<Report[]>([]);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [selected, setSelected] = useState<Report | null>(null);
  const [tab, setTab] = useState<"reports" | "suggestions">("reports");
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("");
  const [departmentFilter, setDepartmentFilter] = useState("");
  const [priorityFilter, setPriorityFilter] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [suggestionSearch, setSuggestionSearch] = useState("");
  const [suggestionStatusFilter, setSuggestionStatusFilter] = useState("");
  const [noteText, setNoteText] = useState("");
  const [rejectReason, setRejectReason] = useState("");
  const [showReject, setShowReject] = useState(false);
  const [showResolve, setShowResolve] = useState(false);
  const [resolveImage, setResolveImage] = useState<string>("");
  const [editingCategory, setEditingCategory] = useState(false);
  const [newCategory, setNewCategory] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => { loadReports(); loadDepartments(); loadSuggestions(); }, []);

  // Reload reports when any filter changes
  useEffect(() => { const t = setTimeout(loadReports, 400); return () => clearTimeout(t); }, [statusFilter, departmentFilter, priorityFilter, dateFrom, dateTo]);

  // Reload suggestions when filters change
  useEffect(() => { const t = setTimeout(loadSuggestions, 400); return () => clearTimeout(t); }, [suggestionSearch, suggestionStatusFilter]);

  const loadReports = async () => {
    try {
      const params = new URLSearchParams();
      if (statusFilter) params.set("status", statusFilter);
      if (departmentFilter) params.set("departmentId", departmentFilter);
      if (priorityFilter) params.set("priority", priorityFilter);
      if (search) params.set("search", search);
      if (dateFrom) params.set("dateFrom", dateFrom);
      if (dateTo) params.set("dateTo", dateTo);
      const qs = params.toString();
      setReports((await api.get<PaginatedResponse<Report>>(`/reception/reports${qs ? `?${qs}` : ""}`)).data);
    } catch (e) { console.error("loadReports", e); }
  };
  const loadDepartments = async () => { try { const r = await api.get<any>("/admin/departments"); setDepartments(Array.isArray(r) ? r : (r.data || [])); } catch (e) { console.error("loadDepartments", e); } };
  const loadSuggestions = async () => {
    try {
      const params = new URLSearchParams();
      if (suggestionStatusFilter) params.set("status", suggestionStatusFilter);
      if (suggestionSearch) params.set("search", suggestionSearch);
      const qs = params.toString();
      setSuggestions((await api.get<PaginatedResponse<Suggestion>>(`/reception/suggestions${qs ? `?${qs}` : ""}`)).data);
    } catch (e) { console.error("loadSuggestions", e); }
  };

  const handleAssign = async (reportId: string, deptId: string) => {
    try { await api.patch(`/reception/reports/${reportId}/assign`, { dept_id: deptId }); loadReports(); } catch (e: any) { alert(e.message); }
  };

  const handleResolve = async (reportId: string) => {
    alert("إغلاق البلاغ يتم من لوحة موظف القسم بعد إضافة تقرير الإنجاز.");
    setShowResolve(false);
    setResolveImage("");
    setNoteText("");
  };

  const handleReject = async (reportId: string) => {
    try { await api.delete(`/reception/reports/${reportId}`); setShowReject(false); setRejectReason(""); loadReports(); } catch (e: any) { alert(e.message); }
  };

  const handleAddNote = async (reportId: string) => {
    if (!noteText.trim()) return;
    alert("تعليقات الاستقبال تحتاج مسار backend منفصل. سنربطها بعد إضافته.");
    setNoteText("");
  };

  const handleDeleteReport = async (reportId: string) => {
    if (!confirm("هل أنت متأكد من حذف هذا البلاغ المرفوض؟")) return;
    try { await api.delete(`/reception/reports/${reportId}`); setSelected(null); loadReports(); } catch (e: any) { alert(e.message); }
  };

  const updateSuggestionStatus = async (id: string, status: string, note?: string) => {
    try {
      if (status === "ACCEPTED") await api.patch(`/reception/suggestions/${id}/accept`);
      else if (status === "REJECTED") await api.patch(`/reception/suggestions/${id}/reject`, { reason: note || "Rejected by reception." });
      else await api.patch(`/reception/suggestions/${id}/implementation`, { status });
      loadSuggestions();
    } catch (e: any) { alert(e.message); }
  };

  const handleCategoryUpdate = async (reportId: string, category: string) => {
    alert("تعديل التصنيف يحتاج اختيار category_id وربطه بمسار classify في backend.");
    setEditingCategory(false);
  };

  const acceptSuggestion = async (id: string) => { try { await api.patch(`/reception/suggestions/${id}/accept`); loadSuggestions(); } catch (e) { console.error("acceptSuggestion", e); } };
  const rejectSuggestion = async (id: string) => { try { await api.patch(`/reception/suggestions/${id}/reject`, { reason: rejectReason || "Rejected by reception." }); loadSuggestions(); } catch (e) { console.error("rejectSuggestion", e); } };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-emerald-400">لوحة الاستقبال</h1>
      <div className="flex gap-2">
        <button onClick={() => setTab("reports")} className={`px-4 py-2 rounded-lg text-sm ${tab === "reports" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>البلاغات ({reports.length})</button>
        <button onClick={() => setTab("suggestions")} className={`px-4 py-2 rounded-lg text-sm ${tab === "suggestions" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>الاقتراحات ({suggestions.length})</button>
      </div>

      {tab === "reports" && (
        <div className="grid grid-cols-12 gap-6">
          <div className="col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
            <div className="flex flex-wrap gap-2 mb-4">
              <input placeholder="بحث..." value={search} onChange={e => { setSearch(e.target.value); setTimeout(loadReports, 300); }} className="flex-1 min-w-[120px] px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white placeholder-slate-500" />
              <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setTimeout(loadReports, 0); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
                <option value="">جميع الحالات</option>
                <option value="NEW">جديد</option>
                <option value="ASSIGNED">مسند</option>
                <option value="IN_PROGRESS">قيد المعالجة</option>
                <option value="RESOLVED">محلول</option>
                <option value="REJECTED">مرفوض</option>
              </select>
              <select value={departmentFilter} onChange={e => { setDepartmentFilter(e.target.value); setTimeout(loadReports, 0); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
                <option value="">جميع الأقسام</option>
                {departments.map(d => <option key={d.id} value={d.id}>{d.dept_name || d.name}</option>)}
              </select>
              <select value={priorityFilter} onChange={e => { setPriorityFilter(e.target.value); setTimeout(loadReports, 0); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
                <option value="">جميع الأولويات</option>
                <option value="HIGH">عالية</option>
                <option value="MEDIUM">متوسطة</option>
                <option value="LOW">منخفضة</option>
              </select>
              <input type="date" value={dateFrom} onChange={e => { setDateFrom(e.target.value); setTimeout(loadReports, 0); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white" title="من تاريخ" />
              <input type="date" value={dateTo} onChange={e => { setDateTo(e.target.value); setTimeout(loadReports, 0); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white" title="إلى تاريخ" />
            </div>
            <div className="space-y-2 max-h-[600px] overflow-y-auto">
              {reports.map(r => (
                <div key={r.id} onClick={() => setSelected(r)} className={`p-3 rounded-lg cursor-pointer border transition-colors ${selected?.id === r.id ? "bg-emerald-600/10 border-emerald-600" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                  <div className="flex gap-2">
                    {r.imageUrl && <img src={r.imageUrl} alt="" className="w-12 h-12 rounded object-cover shrink-0" />}
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between mb-1">
                        <span className="font-medium text-sm truncate">{r.title}</span>
                        <div className="flex gap-1 shrink-0">
                          <span className={`px-2 py-0.5 rounded text-xs ${statusBadge[r.status]}`}>{r.status}</span>
                          <span className={`px-2 py-0.5 rounded text-xs ${priorityBadge[r.priority || ""] || "bg-slate-500/20 text-slate-400"}`}>{r.priority || "-"}</span>
                        </div>
                      </div>
                      <p className="text-xs text-slate-500 line-clamp-1">{r.description}</p>
                      <div className="flex gap-2 mt-1 text-xs text-slate-600">
                        <span>{r.citizen?.name}</span>
                        <span>{r._count?.notes} ملاحظات</span>
                        {r.slaDeadline && <span className={new Date(r.slaDeadline) < new Date() ? "text-red-400" : ""}>SLA: {new Date(r.slaDeadline).toLocaleDateString("ar")}</span>}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
              {reports.length === 0 && <p className="text-slate-500 text-sm text-center py-8">لا توجد بلاغات</p>}
            </div>
          </div>

          <div className="col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
            {selected ? (
              <div className="space-y-4">
                <h2 className="text-lg font-bold">{selected.title}</h2>
                <div className="flex gap-2">
                  <span className={`px-2 py-1 rounded text-xs ${statusBadge[selected.status]}`}>{selected.status}</span>
                  <span className={`px-2 py-1 rounded text-xs ${priorityBadge[selected.priority || ""] || "bg-slate-500/20 text-slate-400"}`}>{selected.priority || "-"}</span>
                </div>
                <div className="text-sm text-slate-400">
                  <p><strong>المواطن:</strong> {selected.citizen?.name} ({selected.citizen?.phone})</p>
                  <p><strong>التصنيف:</strong>
                    {editingCategory ? (
                      <>
                        <select value={newCategory} onChange={e => setNewCategory(e.target.value)} className="mr-1 px-2 py-0.5 bg-slate-800 border border-slate-700 rounded text-xs">
                          <option value="">اختر تصنيف...</option>
                          <option value="بنية تحتية">بنية تحتية</option>
                          <option value="نظافة">نظافة</option>
                          <option value="طرق">طرق</option>
                          <option value="إنارة">إنارة</option>
                          <option value="مياه">مياه</option>
                          <option value="صرف صحي">صرف صحي</option>
                          <option value="حدائق">حدائق</option>
                          <option value="مرافق عامة">مرافق عامة</option>
                          <option value="أمان">أمان</option>
                          <option value="بيئة">بيئة</option>
                          <option value="أخرى">أخرى</option>
                        </select>
                        <button onClick={() => handleCategoryUpdate(selected.id, newCategory || selected.category)} className="mr-1 px-2 py-0.5 bg-emerald-600 rounded text-xs">حفظ</button>
                        <button onClick={() => setEditingCategory(false)} className="px-2 py-0.5 bg-slate-700 rounded text-xs">إلغاء</button>
                      </>
                    ) : (
                      <>
                        {selected.category}
                        <button onClick={() => { setNewCategory(selected.category); setEditingCategory(true); }} className="mr-2 px-2 py-0.5 bg-slate-800 hover:bg-slate-700 rounded text-xs">تعديل</button>
                      </>
                    )}
                  </p>
                  {selected.aiConfidence && <p><strong>AI:</strong> {selected.aiReason} (الثقة: {selected.aiConfidence}%)</p>}
                  {selected.department && <p><strong>القسم:</strong> {selected.department.dept_name || selected.department.name}</p>}
                </div>
                <p className="text-sm">{selected.description}</p>
                {selected.status === "NEW" && (
                  <div>
                    <label className="block text-sm text-slate-400 mb-1">إسناد إلى قسم:</label>
                    <select onChange={e => { if (e.target.value) handleAssign(selected.id, e.target.value); }} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                      <option value="">اختر القسم...</option>
                      {departments.map(d => <option key={d.id} value={d.id}>{d.dept_name || d.name}</option>)}
                    </select>
                  </div>
                )}
                <div className="flex gap-2">
                  {selected.status === "IN_PROGRESS" && (
                    <button onClick={() => setShowResolve(true)} className="px-3 py-1.5 bg-emerald-600 rounded-lg text-sm">حل</button>
                  )}
                  {selected.status !== "REJECTED" && selected.status !== "RESOLVED" && (
                    <button onClick={() => setShowReject(true)} className="px-3 py-1.5 bg-red-600/20 text-red-400 rounded-lg text-sm">رفض</button>
                  )}
                  {selected.status === "REJECTED" && (
                    <button onClick={() => handleDeleteReport(selected.id)} className="px-3 py-1.5 bg-red-600/40 text-red-300 rounded-lg text-sm">حذف</button>
                  )}
                </div>
                {(selected.imageUrl || selected.afterImageUrl) && (
                  <div className="grid grid-cols-2 gap-2">
                    {selected.imageUrl && (
                      <div>
                        <p className="text-xs text-slate-500 mb-1">قبل</p>
                        <img src={selected.imageUrl} alt="قبل" className="w-full h-36 object-cover rounded-lg cursor-pointer" onClick={() => window.open(selected.imageUrl!, "_blank")} />
                      </div>
                    )}
                    {selected.afterImageUrl && (
                      <div>
                        <p className="text-xs text-slate-500 mb-1">بعد</p>
                        <img src={selected.afterImageUrl} alt="بعد" className="w-full h-36 object-cover rounded-lg cursor-pointer" onClick={() => window.open(selected.afterImageUrl!, "_blank")} />
                      </div>
                    )}
                  </div>
                )}
                <div>
                  <label className="block text-sm text-slate-400 mb-1">إضافة ملاحظة:</label>
                  <div className="flex gap-2">
                    <input value={noteText} onChange={e => setNoteText(e.target.value)} placeholder="اكتب ملاحظة..." className="flex-1 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white" />
                    <button onClick={() => handleAddNote(selected.id)} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">إرسال</button>
                  </div>
                </div>
                {showReject && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50">
                    <div className="bg-slate-900 p-6 rounded-xl border border-slate-700 w-96">
                      <h3 className="font-bold mb-3">سبب الرفض</h3>
                      <input value={rejectReason} onChange={e => setRejectReason(e.target.value)} placeholder="اذكر سبب الرفض..." className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm mb-3" />
                      <div className="flex gap-2 justify-end">
                        <button onClick={() => setShowReject(false)} className="px-3 py-1.5 bg-slate-700 rounded-lg text-sm">إلغاء</button>
                        <button onClick={() => handleReject(selected.id)} className="px-3 py-1.5 bg-red-600 rounded-lg text-sm">تأكيد</button>
                      </div>
                    </div>
                  </div>
                )}
                {showResolve && (
                  <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50">
                    <div className="bg-slate-900 p-6 rounded-xl border border-slate-700 w-96">
                      <h3 className="font-bold mb-3">حل البلاغ</h3>
                      <textarea value={noteText} onChange={e => setNoteText(e.target.value)} placeholder="تفاصيل الحل..." className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm mb-3 text-white" rows={3} />
                      <div className="mb-3">
                        <label className="block text-sm text-slate-400 mb-1">إرفاق صورة (اختياري):</label>
                        <input type="file" accept="image/*" onChange={e => { const f = e.target.files?.[0]; if (f) { const reader = new FileReader(); reader.onload = () => setResolveImage(reader.result as string); reader.readAsDataURL(f); } }} className="w-full text-sm text-slate-400 file:mr-2 file:px-3 file:py-1.5 file:bg-slate-800 file:border file:border-slate-700 file:rounded-lg file:text-sm file:text-white" />
                      </div>
                      {resolveImage && <img src={resolveImage} alt="معاينة" className="max-h-32 rounded-lg mb-3" />}
                      <div className="flex gap-2 justify-end">
                        <button onClick={() => { setShowResolve(false); setResolveImage(""); }} className="px-3 py-1.5 bg-slate-700 rounded-lg text-sm">إلغاء</button>
                        <button onClick={() => handleResolve(selected.id)} className="px-3 py-1.5 bg-emerald-600 rounded-lg text-sm">تأكيد الحل</button>
                      </div>
                    </div>
                  </div>
                )}
              </div>
            ) : (
              <p className="text-slate-500 text-sm text-center py-12">اختر بلاغاً لعرض التفاصيل</p>
            )}
          </div>
        </div>
      )}

      {tab === "suggestions" && (
        <div className="space-y-3">
          <div className="flex gap-2">
            <input value={suggestionSearch} onChange={e => setSuggestionSearch(e.target.value)} placeholder="بحث في المقترحات..." className="flex-1 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white placeholder-slate-500" />
            <select value={suggestionStatusFilter} onChange={e => setSuggestionStatusFilter(e.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
              <option value="">جميع الحالات</option>
              <option value="NEW">جديد</option>
              <option value="UNDER_REVIEW">قيد المراجعة</option>
              <option value="ACCEPTED">مقبول</option>
              <option value="REJECTED">مرفوض</option>
              <option value="EXECUTING">قيد التنفيذ</option>
              <option value="IMPLEMENTED">منفذ</option>
              <option value="CANCELLED">ملغي</option>
            </select>
          </div>
          <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
            {suggestions.map(s => (
              <div key={s.id} className="p-4 bg-slate-800/50 rounded-lg border border-slate-700 mb-3">
                <div className="flex items-start justify-between">
                  <div>
                    <h3 className="font-medium">{s.title}</h3>
                    <p className="text-sm text-slate-400 mt-1">{s.description}</p>
                    <div className="flex gap-3 mt-2 text-xs text-slate-500">
                      <span>{s.citizen.name}</span>
                      <span>👍 {s.votes}</span>
                      <span className={`px-2 py-0.5 rounded text-xs ${statusBadgeSuggestion[s.status] || "bg-slate-500/20 text-slate-400"}`}>{s.status}</span>
                    </div>
                  </div>
                  {s.status === "NEW" && (
                    <div className="flex items-center gap-2">
                      <button onClick={() => updateSuggestionStatus(s.id, "ACCEPTED")} className="px-3 py-1 bg-emerald-600 rounded text-xs">قبول</button>
                      <button onClick={() => { const r = prompt("سبب الرفض:"); if (r && r.length >= 10) updateSuggestionStatus(s.id, "REJECTED", r); else alert("يجب كتابة 10 أحرف على الأقل"); }} className="px-3 py-1 bg-red-600/50 rounded text-xs">رفض</button>
                    </div>
                  )}
                  {s.status === "ACCEPTED" && (
                    <div className="flex gap-1">
                      <button onClick={() => updateSuggestionStatus(s.id, "EXECUTING")} className="px-2 py-1 bg-purple-600/50 rounded text-xs">بدء التنفيذ</button>
                      <button onClick={() => { const r = prompt("سبب الإلغاء:"); if (r && r.length >= 10) updateSuggestionStatus(s.id, "CANCELLED", r); else alert("يجب كتابة 10 أحرف على الأقل"); }} className="px-2 py-1 bg-red-600/20 text-red-400 rounded text-xs">إلغاء</button>
                    </div>
                  )}
                  {s.status === "EXECUTING" && (
                    <div className="flex gap-1">
                      <button onClick={() => updateSuggestionStatus(s.id, "IMPLEMENTED")} className="px-2 py-1 bg-emerald-600/50 rounded text-xs">تم التنفيذ</button>
                      <button onClick={() => { const r = prompt("سبب الإلغاء:"); if (r && r.length >= 10) updateSuggestionStatus(s.id, "CANCELLED", r); else alert("يجب كتابة 10 أحرف على الأقل"); }} className="px-2 py-1 bg-red-600/20 text-red-400 rounded text-xs">إلغاء</button>
                    </div>
                  )}
                </div>
              </div>
            ))}
            {suggestions.length === 0 && <p className="text-slate-500 text-sm text-center py-8">لا توجد اقتراحات</p>}
          </div>
        </div>
      )}
    </div>
  );
}
