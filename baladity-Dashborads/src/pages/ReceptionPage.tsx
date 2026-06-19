import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department } from "../types";

interface Category {
  id: string;
  category_name: string;
  department?: Department | null;
}

interface ReportImage {
  id: string;
  image_url: string;
  image_type?: string;
}

interface ReportLog {
  id: string;
  action: string;
  old_status?: string | null;
  new_status?: string | null;
  note?: string | null;
  actor?: { full_name?: string; name?: string } | null;
}

interface ReportComment {
  id: string;
  comment_text: string;
  user?: { full_name?: string; name?: string; role?: { role_name: string } } | null;
}

interface Report {
  id: string;
  report_number?: string;
  title?: string;
  description?: string | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  severity?: string | null;
  status: string;
  sla_color?: string | null;
  sla_status?: string | null;
  sla_due_at?: string | null;
  category_id?: string | null;
  dept_id?: string | null;
  citizen?: { full_name?: string; name?: string; phone?: string } | null;
  category?: Category | null;
  department?: Department | null;
  images?: ReportImage[];
  logs?: ReportLog[];
  comments?: ReportComment[];
  created_at?: string;
}

const statusLabels: Record<string, string> = {
  new: "جديد",
  under_review: "قيد المراجعة",
  transferred: "محول",
  in_progress: "قيد التنفيذ",
  pending: "معلق",
  closed: "مغلق",
  rejected: "مرفوض",
};

const statusClasses: Record<string, string> = {
  new: "bg-blue-500/20 text-blue-400",
  under_review: "bg-amber-500/20 text-amber-400",
  transferred: "bg-purple-500/20 text-purple-400",
  in_progress: "bg-cyan-500/20 text-cyan-400",
  pending: "bg-orange-500/20 text-orange-400",
  closed: "bg-emerald-500/20 text-emerald-400",
  rejected: "bg-red-500/20 text-red-400",
};

const severityClasses: Record<string, string> = {
  low: "bg-slate-500/20 text-slate-300",
  medium: "bg-amber-500/20 text-amber-400",
  high: "bg-red-500/20 text-red-400",
};

const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  return `http://127.0.0.1:8000${url.startsWith("/") ? url : `/${url}`}`;
};

const personName = (person?: { full_name?: string; name?: string } | null) => person?.full_name || person?.name || "-";
const departmentName = (department?: Department | null) => department?.dept_name || department?.name || "-";

export default function ReceptionPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<Report[]>([]);
  const [selected, setSelected] = useState<Report | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [severity, setSeverity] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [note, setNote] = useState("");
  const [rejectReason, setRejectReason] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadReports();
  }, [status, severity]);

  useEffect(() => {
    loadDepartments();
    loadCategories();
  }, []);

  const loadReports = async () => {
    try {
      const params = new URLSearchParams();
      if (status) params.set("status", status);
      if (severity) params.set("severity", severity);
      if (search) params.set("search", search);
      params.set("per_page", "30");
      const response = await api.get<any>(`/reception/reports?${params.toString()}`);
      setReports(response.data || []);
    } catch (error) {
      console.error("loadReports", error);
    }
  };

  const loadDepartments = async () => {
    try {
      const response = await api.get<any>("/admin/departments?per_page=100");
      setDepartments(response.data || []);
    } catch (error) {
      console.error("loadDepartments", error);
    }
  };

  const loadCategories = async () => {
    try {
      const response = await api.get<{ categories: Category[] }>("/reception/categories");
      setCategories(response.categories || []);
    } catch (error) {
      console.error("loadCategories", error);
    }
  };

  const openReport = async (reportId: string) => {
    setLoadingDetails(true);
    try {
      const response = await api.get<{ report: Report }>(`/reception/reports/${reportId}`);
      setSelected(response.report);
      setCategoryId(String(response.report.category_id || response.report.category?.id || ""));
      setDepartmentId(String(response.report.dept_id || response.report.department?.id || ""));
      setNote("");
      setRejectReason("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    } finally {
      setLoadingDetails(false);
    }
  };

  const classifyReport = async () => {
    if (!selected || !categoryId) return;
    try {
      const response = await api.patch<{ report: Report }>(`/reception/reports/${selected.id}/classify`, {
        category_id: categoryId,
        note: note || undefined,
      });
      setSelected((current) => current ? { ...current, ...response.report } : response.report);
      setDepartmentId(String(response.report.dept_id || response.report.department?.id || ""));
      setNote("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const assignReport = async () => {
    if (!selected || !departmentId) return;
    try {
      const response = await api.patch<{ report: Report }>(`/reception/reports/${selected.id}/assign`, {
        dept_id: departmentId,
        note: note || undefined,
      });
      setSelected((current) => current ? { ...current, ...response.report } : response.report);
      setNote("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const rejectReport = async () => {
    if (!selected || !rejectReason.trim()) return;
    if (!confirm("هل أنت متأكد من رفض البلاغ وحذفه نهائياً؟")) return;
    try {
      await api.delete(`/reception/reports/${selected.id}`, { rejection_reason: rejectReason });
      setSelected(null);
      setRejectReason("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const firstImage = useMemo(() => selected?.images?.[0], [selected]);

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">لوحة الاستقبال</h1>
        <button onClick={loadReports} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
        <section className="xl:col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="flex flex-wrap gap-2 mb-4">
            <input value={search} onChange={(event) => setSearch(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadReports()} placeholder="بحث برقم البلاغ أو العنوان" className="flex-1 min-w-52 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <select value={status} onChange={(event) => setStatus(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
              <option value="">الجديدة فقط</option>
              <option value="under_review">قيد المراجعة</option>
              <option value="transferred">محولة</option>
              <option value="new">جديدة</option>
            </select>
            <select value={severity} onChange={(event) => setSeverity(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
              <option value="">كل الخطورة</option>
              <option value="low">منخفضة</option>
              <option value="medium">متوسطة</option>
              <option value="high">عالية</option>
            </select>
            <button onClick={loadReports} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
          </div>

          <div className="space-y-2 max-h-[650px] overflow-y-auto">
            {reports.map((report) => (
              <button key={report.id} onClick={() => openReport(report.id)} className={`w-full text-right p-3 rounded-lg border transition-colors ${selected?.id === report.id ? "bg-emerald-600/10 border-emerald-500" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="font-medium truncate">{report.report_number || `#${report.id}`} - {report.title || "بلاغ بدون عنوان"}</div>
                    <p className="text-xs text-slate-500 line-clamp-1 mt-1">{report.description || "-"}</p>
                    <div className="flex flex-wrap gap-2 mt-2 text-xs">
                      <span>{personName(report.citizen)}</span>
                      <span>{report.category?.category_name || "بدون تصنيف"}</span>
                      <span>{departmentName(report.department)}</span>
                    </div>
                  </div>
                  <div className="flex flex-col gap-1 items-end">
                    <span className={`px-2 py-0.5 rounded text-xs ${statusClasses[report.status] || "bg-slate-500/20 text-slate-400"}`}>{statusLabels[report.status] || report.status}</span>
                    <span className={`px-2 py-0.5 rounded text-xs ${severityClasses[report.severity || ""] || "bg-slate-500/20 text-slate-400"}`}>{report.severity || "-"}</span>
                  </div>
                </div>
              </button>
            ))}
            {reports.length === 0 && <p className="text-slate-500 text-sm text-center py-10">لا توجد بلاغات مطابقة</p>}
          </div>
        </section>

        <section className="xl:col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
          {!selected ? (
            <p className="text-slate-500 text-sm text-center py-16">اختر بلاغاً لعرض التفاصيل</p>
          ) : (
            <div className="space-y-4">
              {loadingDetails && <p className="text-xs text-emerald-400">جاري تحديث التفاصيل...</p>}
              <div>
                <h2 className="text-lg font-bold">{selected.report_number || `#${selected.id}`}</h2>
                <p className="text-sm text-slate-400">{selected.title || "بلاغ بدون عنوان"}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <span className={`px-2 py-1 rounded text-xs ${statusClasses[selected.status] || "bg-slate-500/20 text-slate-400"}`}>{statusLabels[selected.status] || selected.status}</span>
                <span className={`px-2 py-1 rounded text-xs ${severityClasses[selected.severity || ""] || "bg-slate-500/20 text-slate-400"}`}>{selected.severity || "-"}</span>
                {selected.sla_status && <span className="px-2 py-1 rounded text-xs bg-slate-800 text-slate-300">SLA: {selected.sla_status}</span>}
              </div>

              {firstImage && <img src={assetUrl(firstImage.image_url)} alt="صورة البلاغ" className="w-full h-56 object-cover rounded-lg border border-slate-800" />}

              <div className="text-sm text-slate-300 space-y-1">
                <p><strong>المواطن:</strong> {personName(selected.citizen)} {selected.citizen?.phone ? `- ${selected.citizen.phone}` : ""}</p>
                <p><strong>التصنيف الحالي:</strong> {selected.category?.category_name || "بدون تصنيف"}</p>
                <p><strong>القسم الحالي:</strong> {departmentName(selected.department)}</p>
                <p><strong>الموقع:</strong> {selected.latitude || "-"}, {selected.longitude || "-"}</p>
              </div>
              <p className="text-sm leading-7">{selected.description || "-"}</p>

              <div className="space-y-2 border-t border-slate-800 pt-4">
                <label className="block text-sm text-slate-400">التصنيف</label>
                <select value={categoryId} onChange={(event) => setCategoryId(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                  <option value="">اختر التصنيف</option>
                  {categories.map((category) => <option key={category.id} value={category.id}>{category.category_name} - {departmentName(category.department)}</option>)}
                </select>
                <button onClick={classifyReport} disabled={!categoryId} className="px-3 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">تأكيد التصنيف</button>
              </div>

              <div className="space-y-2 border-t border-slate-800 pt-4">
                <label className="block text-sm text-slate-400">تحويل إلى قسم</label>
                <select value={departmentId} onChange={(event) => setDepartmentId(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                  <option value="">اختر القسم</option>
                  {departments.map((department) => <option key={department.id} value={department.id}>{departmentName(department)}</option>)}
                </select>
                <textarea value={note} onChange={(event) => setNote(event.target.value)} placeholder="ملاحظة اختيارية" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
                <button onClick={assignReport} disabled={!departmentId} className="px-3 py-2 bg-blue-600 disabled:opacity-50 rounded-lg text-sm">تحويل البلاغ</button>
              </div>

              <div className="space-y-2 border-t border-slate-800 pt-4">
                <label className="block text-sm text-red-300">رفض البلاغ</label>
                <textarea value={rejectReason} onChange={(event) => setRejectReason(event.target.value)} placeholder="سبب الرفض إلزامي" className="w-full px-3 py-2 bg-slate-800 border border-red-900/50 rounded-lg text-sm h-20" />
                <button onClick={rejectReport} disabled={!rejectReason.trim()} className="px-3 py-2 bg-red-600 disabled:opacity-50 rounded-lg text-sm">رفض وحذف</button>
              </div>

              <div className="border-t border-slate-800 pt-4">
                <h3 className="font-bold mb-2">سجل الإجراءات</h3>
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {(selected.logs || []).map((log) => (
                    <div key={log.id} className="text-xs bg-slate-800/60 rounded-lg p-2">
                      <div className="text-slate-300">{log.action} {log.new_status ? `- ${log.new_status}` : ""}</div>
                      {log.note && <div className="text-slate-500 mt-1">{log.note}</div>}
                    </div>
                  ))}
                  {(!selected.logs || selected.logs.length === 0) && <p className="text-xs text-slate-500">لا يوجد سجل بعد</p>}
                </div>
              </div>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
