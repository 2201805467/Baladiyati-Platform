import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

interface ReportImage {
  id: string;
  image_url: string;
  image_type?: string;
}

interface ReportLog {
  id: string;
  action: string;
  new_status?: string | null;
  note?: string | null;
}

interface ReportComment {
  id: string;
  comment_text: string;
  created_at?: string | null;
  user?: { full_name?: string; name?: string; role?: { role_name?: string } } | null;
}

interface Report {
  id: string;
  report_number?: string;
  title?: string;
  description?: string | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  status: string;
  sla_status?: string | null;
  sla_color?: string | null;
  sla_due_at?: string | null;
  completion_report?: string | null;
  citizen?: { full_name?: string; name?: string; phone?: string } | null;
  category?: { category_name?: string } | null;
  department?: { dept_name?: string; name?: string } | null;
  images?: ReportImage[];
  comments?: ReportComment[];
  logs?: ReportLog[];
  rating?: { stars?: number; comment?: string | null } | null;
}

const statusLabels: Record<string, string> = {
  transferred: "محول",
  in_progress: "قيد التنفيذ",
  pending: "معلق",
  closed: "مغلق",
};

const statusClasses: Record<string, string> = {
  transferred: "bg-purple-500/20 text-purple-400",
  in_progress: "bg-cyan-500/20 text-cyan-400",
  pending: "bg-orange-500/20 text-orange-400",
  closed: "bg-emerald-500/20 text-emerald-400",
};

const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  const apiOrigin = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");
  return `${apiOrigin}${url.startsWith("/") ? url : `/${url}`}`;
};

const personName = (person?: { full_name?: string; name?: string } | null) => person?.full_name || person?.name || "-";
const commenterRole = (comment: ReportComment) => {
  const role = comment.user?.role?.role_name;
  if (role === "citizen") return "مواطن";
  if (role === "department") return "موظف القسم";
  if (role === "reception") return "موظف الاستقبال";
  return "موظف";
};
const formatDateTime = (value?: string | null) => {
  if (!value) return "";
  return new Intl.DateTimeFormat("ar-LY", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

export default function TechnicalPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const departmentTitle = user?.department?.dept_name ? `لوحة موظف قسم ${user.department.dept_name}` : "لوحة موظف القسم";
  const [reports, setReports] = useState<Report[]>([]);
  const [selected, setSelected] = useState<Report | null>(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [search, setSearch] = useState("");
  const [statusNote, setStatusNote] = useState("");
  const [commentText, setCommentText] = useState("");
  const [completionReport, setCompletionReport] = useState("");
  const [completionImage, setCompletionImage] = useState<File | null>(null);

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadReports();
  }, [statusFilter]);

  useEffect(() => {
    const reportId = new URLSearchParams(location.search).get("reportId");
    if (!reportId) return;

    openReport(reportId);
  }, [location.search]);

  const loadReports = async () => {
    try {
      const params = new URLSearchParams();
      if (statusFilter) params.set("status", statusFilter);
      if (search) params.set("search", search);
      params.set("per_page", "30");
      const response = await api.get<any>(`/department/reports?${params.toString()}`);
      setReports(response.data || []);
    } catch (error) {
      console.error("loadReports", error);
    }
  };

  const openReport = async (reportId: string) => {
    try {
      const response = await api.get<{ report: Report }>(`/department/reports/${reportId}`);
      setSelected(response.report);
      setReports((current) => current.some((report) => report.id === response.report.id)
        ? current.map((report) => report.id === response.report.id ? response.report : report)
        : [response.report, ...current]);
      setStatusNote("");
      setCommentText("");
      setCompletionReport("");
      setCompletionImage(null);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const openReportOnMap = (report: Report) => {
    if (!report.latitude || !report.longitude) {
      alert("لا توجد إحداثيات محفوظة لهذا البلاغ.");
      return;
    }

    navigate(`/admin/map?reportId=${report.id}`);
  };

  const updateStatus = async (status: "in_progress" | "pending") => {
    if (!selected || !statusNote.trim()) return;
    try {
      const response = await api.patch<{ report: Report }>(`/department/reports/${selected.id}/status`, {
        status,
        note: statusNote,
      });
      setSelected((current) => current ? { ...current, ...response.report } : response.report);
      setStatusNote("");
      loadReports();
      openReport(selected.id);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const addComment = async () => {
    if (!selected || !commentText.trim()) return;
    try {
      const response = await api.post<{ comment: ReportComment }>(`/department/reports/${selected.id}/comments`, { comment_text: commentText });
      setSelected((current) => current
        ? { ...current, comments: [...(current.comments || []), response.comment] }
        : current);
      setCommentText("");
    } catch (error: any) {
      alert(error.message || "تعذر إرسال التعليق. النص محفوظ ويمكنك إعادة المحاولة.");
    }
  };

  const closeReport = async () => {
    if (!selected || !completionReport.trim() || !completionImage) return;
    const form = new FormData();
    form.append("_method", "PATCH");
    form.append("completion_report", completionReport);
    form.append("completion_image", completionImage);

    try {
      const response = await api.post<{ report: Report }>(`/department/reports/${selected.id}/close`, form);
      setSelected((current) => current ? { ...current, ...response.report } : response.report);
      setCompletionReport("");
      setCompletionImage(null);
      loadReports();
      openReport(selected.id);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const counts = useMemo(() => ({
    transferred: reports.filter((report) => report.status === "transferred").length,
    in_progress: reports.filter((report) => report.status === "in_progress").length,
    pending: reports.filter((report) => report.status === "pending").length,
  }), [reports]);

  const firstImage = selected?.images?.[0];
  const afterImages = selected?.images?.filter((image) => image.image_type === "after") || [];

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">{departmentTitle}</h1>
        <button onClick={loadReports} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center"><div className="text-2xl font-bold text-purple-400">{counts.transferred}</div><div className="text-xs text-slate-500">محولة</div></div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center"><div className="text-2xl font-bold text-cyan-400">{counts.in_progress}</div><div className="text-xs text-slate-500">قيد التنفيذ</div></div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center"><div className="text-2xl font-bold text-orange-400">{counts.pending}</div><div className="text-xs text-slate-500">معلقة</div></div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800 text-center"><div className="text-2xl font-bold text-slate-300">{reports.length}</div><div className="text-xs text-slate-500">المجموع</div></div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
        <section className="xl:col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="flex flex-wrap gap-2 mb-4">
            <input value={search} onChange={(event) => setSearch(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadReports()} placeholder="بحث في بلاغات القسم" className="flex-1 min-w-52 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
              <option value="">النشطة</option>
              <option value="transferred">محولة</option>
              <option value="in_progress">قيد التنفيذ</option>
              <option value="pending">معلقة</option>
              <option value="closed">مغلقة</option>
            </select>
            <button onClick={loadReports} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-3 max-h-[650px] overflow-y-auto">
            {reports.map((report) => (
              <button key={report.id} onClick={() => openReport(report.id)} className={`text-right p-3 rounded-lg border transition-colors ${selected?.id === report.id ? "bg-emerald-600/10 border-emerald-500" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0">
                    <div className="font-medium truncate">{report.report_number || `#${report.id}`}</div>
                    <p className="text-xs text-slate-500 line-clamp-2 mt-1">{report.title || report.description || "-"}</p>
                    <p className="text-xs text-slate-600 mt-2">{report.category?.category_name || "بدون تصنيف"}</p>
                  </div>
                  <div className="flex flex-col gap-1 items-end">
                    <span className={`px-2 py-0.5 rounded text-xs ${statusClasses[report.status] || "bg-slate-500/20 text-slate-400"}`}>{statusLabels[report.status] || report.status}</span>
                  </div>
                </div>
              </button>
            ))}
            {reports.length === 0 && <p className="text-slate-500 text-sm text-center py-10 md:col-span-2">لا توجد بلاغات للقسم</p>}
          </div>
        </section>

        <section className="xl:col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
          {!selected ? (
            <p className="text-slate-500 text-sm text-center py-16">اختر بلاغاً لعرض التفاصيل</p>
          ) : (
            <div className="space-y-4">
              <div>
                <h2 className="text-lg font-bold">{selected.report_number || `#${selected.id}`}</h2>
                <p className="text-sm text-slate-400">{selected.title || "بلاغ بدون عنوان"}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                <span className={`px-2 py-1 rounded text-xs ${statusClasses[selected.status] || "bg-slate-500/20 text-slate-400"}`}>{statusLabels[selected.status] || selected.status}</span>
                {selected.sla_status && <span className="px-2 py-1 rounded text-xs bg-slate-800 text-slate-300">SLA: {selected.sla_status}</span>}
              </div>

              {firstImage && <img src={assetUrl(firstImage.image_url)} alt="صورة البلاغ" className="w-full h-56 object-cover rounded-lg border border-slate-800" />}

              <div className="text-sm text-slate-300 space-y-1">
                <p><strong>المواطن:</strong> {personName(selected.citizen)} {selected.citizen?.phone ? `- ${selected.citizen.phone}` : ""}</p>
                <p><strong>التصنيف:</strong> {selected.category?.category_name || "-"}</p>
                <div className="flex items-center gap-2">
                  <strong>الموقع:</strong>
                  <button type="button" onClick={() => openReportOnMap(selected)} className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 rounded-lg text-xs">
                    عرض على الخريطة
                  </button>
                </div>
              </div>
              <p className="text-sm leading-7">{selected.description || "-"}</p>

              {selected.status !== "closed" && (
                <div className="space-y-2 border-t border-slate-800 pt-4">
                  <label className="block text-sm text-slate-400">ملاحظة الحالة</label>
                  <textarea value={statusNote} onChange={(event) => setStatusNote(event.target.value)} placeholder="الملاحظة إلزامية عند تحديث الحالة" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
                  <div className="flex flex-wrap gap-2">
                    <button onClick={() => updateStatus("in_progress")} disabled={!statusNote.trim()} className="px-3 py-2 bg-cyan-600 disabled:opacity-50 rounded-lg text-sm">بدء التنفيذ</button>
                    <button onClick={() => updateStatus("pending")} disabled={!statusNote.trim()} className="px-3 py-2 bg-orange-600 disabled:opacity-50 rounded-lg text-sm">تعليق البلاغ</button>
                  </div>
                </div>
              )}

              <div className="space-y-2 border-t border-slate-800 pt-4">
                <label className="block text-sm text-slate-400">رد للمواطن</label>
                <textarea value={commentText} onChange={(event) => setCommentText(event.target.value)} placeholder="اكتب الرد..." className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
                <button onClick={addComment} disabled={!commentText.trim()} className="px-3 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">إرسال الرد</button>
              </div>

              {selected.status !== "closed" && (
                <div className="space-y-2 border-t border-slate-800 pt-4">
                  <label className="block text-sm text-slate-400">إغلاق البلاغ</label>
                  <textarea value={completionReport} onChange={(event) => setCompletionReport(event.target.value)} placeholder="تقرير الإنجاز إلزامي" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-24" />
                  <input type="file" accept="image/*" onChange={(event) => setCompletionImage(event.target.files?.[0] || null)} className="w-full text-sm text-slate-400 file:ml-2 file:px-3 file:py-1.5 file:bg-slate-800 file:border file:border-slate-700 file:rounded-lg file:text-sm file:text-white" />
                  <button onClick={closeReport} disabled={!completionReport.trim() || !completionImage} className="px-3 py-2 bg-emerald-700 disabled:opacity-50 rounded-lg text-sm">إغلاق البلاغ</button>
                </div>
              )}

              {afterImages.length > 0 && (
                <div className="border-t border-slate-800 pt-4">
                  <h3 className="font-bold mb-2">صور الإنجاز</h3>
                  <div className="grid grid-cols-2 gap-2">
                    {afterImages.map((image) => <img key={image.id} src={assetUrl(image.image_url)} alt="صورة إنجاز" className="h-28 w-full object-cover rounded-lg border border-slate-800" />)}
                  </div>
                </div>
              )}

              <div className="border-t border-slate-800 pt-4">
                <h3 className="font-bold mb-2">التعليقات والمناقشة</h3>
                <div className="space-y-2 max-h-36 overflow-y-auto">
                  {(selected.comments || []).map((comment) => (
                    <div key={comment.id} className="text-xs bg-slate-800/60 rounded-lg p-2">
                      <div className="flex items-center justify-between gap-2 text-slate-300">
                        <span>{personName(comment.user)} · {commenterRole(comment)}</span>
                        {comment.created_at && <span className="text-slate-500">{formatDateTime(comment.created_at)}</span>}
                      </div>
                      <div className="text-slate-500 mt-1 whitespace-pre-line">{comment.comment_text}</div>
                    </div>
                  ))}
                  {(!selected.comments || selected.comments.length === 0) && <p className="text-xs text-slate-500">لا توجد تعليقات</p>}
                </div>
              </div>

              <div className="border-t border-slate-800 pt-4">
                <h3 className="font-bold mb-2">سجل الإجراءات</h3>
                <div className="space-y-2 max-h-36 overflow-y-auto">
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
