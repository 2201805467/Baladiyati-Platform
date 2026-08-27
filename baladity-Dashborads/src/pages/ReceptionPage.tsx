import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate } from "react-router-dom";
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
  upvotes_count?: number;
  downvotes_count?: number;
  category_id?: string | null;
  dept_id?: string | null;
  citizen?: { full_name?: string; name?: string; phone?: string } | null;
  category?: Category | null;
  department?: Department | null;
  images?: ReportImage[];
  logs?: ReportLog[];
  comments?: ReportComment[];
}

interface Suggestion {
  id: string;
  title: string;
  description: string;
  category?: string | null;
  status: string;
  rejection_reason?: string | null;
  implementation_status?: string | null;
  implementation_progress_percent?: number | null;
  implementation_note?: string | null;
  support_votes_count?: number;
  oppose_votes_count?: number;
  citizen?: { full_name?: string; name?: string } | null;
  reviewer?: { full_name?: string; name?: string } | null;
  created_at?: string;
}

const reportStatusLabels: Record<string, string> = {
  new: "جديد",
  under_review: "قيد المراجعة",
  transferred: "محول",
  in_progress: "قيد التنفيذ",
  pending: "معلق",
  closed: "مغلق",
  rejected: "مرفوض",
};

const reportStatusClasses: Record<string, string> = {
  new: "bg-blue-500/20 text-blue-400",
  under_review: "bg-amber-500/20 text-amber-400",
  transferred: "bg-purple-500/20 text-purple-400",
  in_progress: "bg-cyan-500/20 text-cyan-400",
  pending: "bg-orange-500/20 text-orange-400",
  closed: "bg-emerald-500/20 text-emerald-400",
  rejected: "bg-red-500/20 text-red-400",
};

const suggestionStatusLabels: Record<string, string> = {
  under_review: "قيد المراجعة",
  accepted: "مقبول",
  rejected: "مرفوض",
};

const suggestionStatusClasses: Record<string, string> = {
  under_review: "bg-amber-500/20 text-amber-400",
  accepted: "bg-emerald-500/20 text-emerald-400",
  rejected: "bg-red-500/20 text-red-400",
};

const implementationLabels: Record<string, string> = {
  planned: "مخطط",
  in_progress: "قيد التنفيذ",
  completed: "مكتمل",
  paused: "متوقف مؤقتاً",
  cancelled: "ملغي",
};

const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  const apiOrigin = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");
  return `${apiOrigin}${url.startsWith("/") ? url : `/${url}`}`;
};

const reportThumbnailUrl = (report: Report) => {
  const image = report.images?.find((item) => item.image_type !== "after") || report.images?.[0];
  return assetUrl(image?.image_url);
};

const ReportThumbnail = ({ report }: { report: Report }) => {
  const thumbnail = reportThumbnailUrl(report);

  if (!thumbnail) {
    return (
      <div className="h-16 w-20 shrink-0 rounded-lg border border-slate-700 bg-slate-800/80 flex items-center justify-center text-slate-500">
        📷
      </div>
    );
  }

  return (
    <img
      src={thumbnail}
      alt="صورة البلاغ"
      className="h-16 w-20 shrink-0 rounded-lg border border-slate-700 object-cover"
      loading="lazy"
    />
  );
};

const personName = (person?: { full_name?: string; name?: string } | null) => person?.full_name || person?.name || "-";
const departmentName = (department?: Department | null) => department?.dept_name || department?.name || "-";
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

export default function ReceptionPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [tab, setTab] = useState<"reports" | "suggestions">("reports");

  const [reports, setReports] = useState<Report[]>([]);
  const [selectedReport, setSelectedReport] = useState<Report | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [loadingDetails, setLoadingDetails] = useState(false);
  const [reportSearch, setReportSearch] = useState("");
  const [reportStatus, setReportStatus] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [note, setNote] = useState("");
  const [rejectReason, setRejectReason] = useState("");
  const [commentText, setCommentText] = useState("");

  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [selectedSuggestion, setSelectedSuggestion] = useState<Suggestion | null>(null);
  const [suggestionSearch, setSuggestionSearch] = useState("");
  const [suggestionStatus, setSuggestionStatus] = useState("");
  const [suggestionCategory, setSuggestionCategory] = useState("");
  const [suggestionRejectReason, setSuggestionRejectReason] = useState("");
  const [implementationStatus, setImplementationStatus] = useState("planned");
  const [implementationProgress, setImplementationProgress] = useState(0);
  const [implementationNote, setImplementationNote] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadReports();
  }, [reportStatus]);

  useEffect(() => {
    loadSuggestions();
  }, [suggestionStatus]);

  useEffect(() => {
    loadDepartments();
    loadCategories();
  }, []);

  useEffect(() => {
    const reportId = new URLSearchParams(location.search).get("reportId");
    if (!reportId) return;

    setTab("reports");
    openReport(reportId);
  }, [location.search]);

  const loadReports = async () => {
    try {
      const params = new URLSearchParams();
      if (reportStatus) params.set("status", reportStatus);
      if (reportSearch) params.set("search", reportSearch);
      params.set("per_page", "30");
      const response = await api.get<any>(`/reception/reports?${params.toString()}`);
      setReports(response.data || []);
    } catch (error) {
      console.error("loadReports", error);
    }
  };

  const loadDepartments = async () => {
    try {
      const response = await api.get<{ departments: Department[] }>("/reception/departments");
      setDepartments(response.departments || []);
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
      setSelectedReport(response.report);
      setReports((current) => current.some((report) => report.id === response.report.id)
        ? current.map((report) => report.id === response.report.id ? response.report : report)
        : [response.report, ...current]);
      setCategoryId(String(response.report.category_id || response.report.category?.id || ""));
      setDepartmentId(String(response.report.dept_id || response.report.department?.id || ""));
      setNote("");
      setRejectReason("");
      setCommentText("");
    } catch (error: any) {
      alert(error.message);
    } finally {
      setLoadingDetails(false);
    }
  };

  const openReportOnMap = (report: Report) => {
    if (!report.latitude || !report.longitude) {
      alert("لا توجد إحداثيات محفوظة لهذا البلاغ.");
      return;
    }

    navigate(`/admin/map?reportId=${report.id}`);
  };

  const classifyReport = async () => {
    if (!selectedReport || !categoryId) return;
    try {
      const response = await api.patch<{ report: Report }>(`/reception/reports/${selectedReport.id}/classify`, {
        category_id: categoryId,
        note: note || undefined,
      });
      setSelectedReport((current) => current ? { ...current, ...response.report } : response.report);
      setDepartmentId(String(response.report.dept_id || response.report.department?.id || ""));
      setNote("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const assignReport = async () => {
    if (!selectedReport || !departmentId) return;
    try {
      const response = await api.patch<{ report: Report }>(`/reception/reports/${selectedReport.id}/assign`, {
        dept_id: departmentId,
        note: note || undefined,
      });
      setSelectedReport((current) => current ? { ...current, ...response.report } : response.report);
      setNote("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const rejectReport = async () => {
    if (!selectedReport || !rejectReason.trim()) return;
    if (!confirm("هل أنت متأكد من رفض البلاغ وحذفه نهائياً؟")) return;
    try {
      await api.delete(`/reception/reports/${selectedReport.id}`, { rejection_reason: rejectReason });
      setSelectedReport(null);
      setRejectReason("");
      loadReports();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const addReportComment = async () => {
    if (!selectedReport || !commentText.trim()) return;
    try {
      const response = await api.post<{ comment: ReportComment }>(`/reception/reports/${selectedReport.id}/comments`, {
        comment_text: commentText,
      });
      setSelectedReport((current) => current
        ? { ...current, comments: [...(current.comments || []), response.comment] }
        : current);
      setCommentText("");
    } catch (error: any) {
      alert(error.message || "تعذر إرسال التعليق. النص محفوظ ويمكنك إعادة المحاولة.");
    }
  };

  const loadSuggestions = async () => {
    try {
      const params = new URLSearchParams();
      if (suggestionStatus) params.set("status", suggestionStatus);
      if (suggestionSearch) params.set("search", suggestionSearch);
      if (suggestionCategory) params.set("category", suggestionCategory);
      params.set("per_page", "30");
      const response = await api.get<any>(`/reception/suggestions?${params.toString()}`);
      setSuggestions(response.data || []);
    } catch (error) {
      console.error("loadSuggestions", error);
    }
  };

  const selectSuggestion = (suggestion: Suggestion) => {
    setSelectedSuggestion(suggestion);
    setSuggestionRejectReason(suggestion.rejection_reason || "");
    setImplementationStatus(suggestion.implementation_status || "planned");
    setImplementationProgress(suggestion.implementation_progress_percent || 0);
    setImplementationNote(suggestion.implementation_note || "");
  };

  const replaceSuggestion = (suggestion: Suggestion) => {
    setSuggestions((current) => current.map((item) => item.id === suggestion.id ? { ...item, ...suggestion } : item));
    setSelectedSuggestion((current) => current?.id === suggestion.id ? { ...current, ...suggestion } : current);
  };

  const acceptSuggestion = async () => {
    if (!selectedSuggestion) return;
    try {
      const response = await api.patch<{ suggestion: Suggestion }>(`/reception/suggestions/${selectedSuggestion.id}/accept`);
      replaceSuggestion(response.suggestion);
      setSuggestionStatus("accepted");
      loadSuggestions();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const rejectSuggestion = async () => {
    if (!selectedSuggestion || !suggestionRejectReason.trim()) return;
    try {
      const response = await api.patch<{ suggestion: Suggestion }>(`/reception/suggestions/${selectedSuggestion.id}/reject`, {
        rejection_reason: suggestionRejectReason,
      });
      replaceSuggestion(response.suggestion);
      setSuggestionStatus("rejected");
      loadSuggestions();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const updateImplementation = async () => {
    if (!selectedSuggestion) return;
    try {
      const response = await api.patch<{ suggestion: Suggestion }>(`/reception/suggestions/${selectedSuggestion.id}/implementation`, {
        implementation_status: implementationStatus,
        implementation_progress_percent: implementationProgress,
        implementation_note: implementationNote || undefined,
      });
      replaceSuggestion(response.suggestion);
      loadSuggestions();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const firstImage = useMemo(() => selectedReport?.images?.[0], [selectedReport]);

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">لوحة استقبال البلاغات</h1>
        <button onClick={tab === "reports" ? loadReports : loadSuggestions} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setTab("reports")} className={`px-4 py-2 rounded-lg text-sm ${tab === "reports" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>البلاغات ({reports.length})</button>
        <button onClick={() => setTab("suggestions")} className={`px-4 py-2 rounded-lg text-sm ${tab === "suggestions" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>المقترحات ({suggestions.length})</button>
      </div>

      {tab === "reports" ? (
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
          <section className="xl:col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
            <div className="flex flex-wrap gap-2 mb-4">
              <input value={reportSearch} onChange={(event) => setReportSearch(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadReports()} placeholder="بحث برقم البلاغ أو العنوان" className="flex-1 min-w-52 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              <select value={reportStatus} onChange={(event) => setReportStatus(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                <option value="">الجديدة فقط</option>
                <option value="under_review">قيد المراجعة</option>
                <option value="transferred">محولة</option>
              </select>
              <button onClick={loadReports} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
            </div>

            <div className="space-y-2 max-h-[650px] overflow-y-auto">
              {reports.map((report) => (
                <button key={report.id} onClick={() => openReport(report.id)} className={`w-full text-right p-3 rounded-lg border transition-colors ${selectedReport?.id === report.id ? "bg-emerald-600/10 border-emerald-500" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex min-w-0 flex-1 items-start gap-3">
                      <ReportThumbnail report={report} />
                      <div className="min-w-0 flex-1">
                        <div className="font-medium truncate">{report.report_number || `#${report.id}`} - {report.title || "بلاغ بدون عنوان"}</div>
                        <p className="text-xs text-slate-500 line-clamp-1 mt-1">{report.description || "-"}</p>
                        <div className="flex flex-wrap gap-2 mt-2 text-xs">
                          <span>{personName(report.citizen)}</span>
                          <span>{report.category?.category_name || "بدون تصنيف"}</span>
                          <span>{departmentName(report.department)}</span>
                          <span className="text-emerald-400">👍 {report.upvotes_count ?? 0}</span>
                          <span className="text-red-400">👎 {report.downvotes_count ?? 0}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col gap-1 items-end">
                      <span className={`px-2 py-0.5 rounded text-xs ${reportStatusClasses[report.status] || "bg-slate-500/20 text-slate-400"}`}>{reportStatusLabels[report.status] || report.status}</span>
                    </div>
                  </div>
                </button>
              ))}
              {reports.length === 0 && <p className="text-slate-500 text-sm text-center py-10">لا توجد بلاغات مطابقة</p>}
            </div>
          </section>

          <section className="xl:col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
            {!selectedReport ? (
              <p className="text-slate-500 text-sm text-center py-16">اختر بلاغاً لعرض التفاصيل</p>
            ) : (
              <div className="space-y-4">
                {loadingDetails && <p className="text-xs text-emerald-400">جاري تحديث التفاصيل...</p>}
                <div>
                  <h2 className="text-lg font-bold">{selectedReport.report_number || `#${selectedReport.id}`}</h2>
                  <p className="text-sm text-slate-400">{selectedReport.title || "بلاغ بدون عنوان"}</p>
                </div>
                <div className="flex flex-wrap gap-2">
                  <span className={`px-2 py-1 rounded text-xs ${reportStatusClasses[selectedReport.status] || "bg-slate-500/20 text-slate-400"}`}>{reportStatusLabels[selectedReport.status] || selectedReport.status}</span>
                  {selectedReport.sla_status && <span className="px-2 py-1 rounded text-xs bg-slate-800 text-slate-300">SLA: {selectedReport.sla_status}</span>}
                  <span className="px-2 py-1 rounded text-xs bg-emerald-500/10 text-emerald-300">تأييد: {selectedReport.upvotes_count ?? 0}</span>
                  <span className="px-2 py-1 rounded text-xs bg-red-500/10 text-red-300">عدم تأييد: {selectedReport.downvotes_count ?? 0}</span>
                </div>

                {firstImage && <img src={assetUrl(firstImage.image_url)} alt="صورة البلاغ" className="w-full h-56 object-cover rounded-lg border border-slate-800" />}

                <div className="text-sm text-slate-300 space-y-1">
                  <p><strong>المواطن:</strong> {personName(selectedReport.citizen)} {selectedReport.citizen?.phone ? `- ${selectedReport.citizen.phone}` : ""}</p>
                  <p><strong>التصنيف الحالي:</strong> {selectedReport.category?.category_name || "بدون تصنيف"}</p>
                  <p><strong>القسم الحالي:</strong> {departmentName(selectedReport.department)}</p>
                  <div className="flex items-center gap-2">
                    <strong>الموقع:</strong>
                    <button type="button" onClick={() => openReportOnMap(selectedReport)} className="px-3 py-1.5 bg-slate-800 hover:bg-slate-700 rounded-lg text-xs">
                      عرض على الخريطة
                    </button>
                  </div>
                </div>
                <p className="text-sm leading-7">{selectedReport.description || "-"}</p>

                <div className="border-t border-slate-800 pt-4">
                  <h3 className="font-bold mb-3">التعليقات والمناقشة</h3>
                  <div className="space-y-2 max-h-48 overflow-y-auto mb-3">
                    {(selectedReport.comments || []).map((comment) => (
                      <div key={comment.id} className="text-xs bg-slate-800/60 rounded-lg p-2">
                        <div className="flex items-center justify-between gap-2 text-slate-300">
                          <span>{personName(comment.user)} · {commenterRole(comment)}</span>
                          {comment.created_at && <span className="text-slate-500">{formatDateTime(comment.created_at)}</span>}
                        </div>
                        <div className="text-slate-500 mt-1 whitespace-pre-line">{comment.comment_text}</div>
                      </div>
                    ))}
                    {(!selectedReport.comments || selectedReport.comments.length === 0) && (
                      <p className="text-xs text-slate-500">لا توجد تعليقات بعد</p>
                    )}
                  </div>
                  {["new", "under_review"].includes(selectedReport.status) ? (
                    <div className="space-y-2">
                      <textarea value={commentText} onChange={(event) => setCommentText(event.target.value)} placeholder="اكتب رداً أو استفساراً للمواطن" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
                      <button onClick={addReportComment} disabled={!commentText.trim()} className="px-3 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">إرسال التعليق</button>
                    </div>
                  ) : (
                    <p className="text-xs text-slate-500">بعد تحويل البلاغ يصبح قسم التعليقات للمتابعة فقط، والرد الفعلي ينتقل لموظف القسم.</p>
                  )}
                </div>

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
                    {(selectedReport.logs || []).map((log) => (
                      <div key={log.id} className="text-xs bg-slate-800/60 rounded-lg p-2">
                        <div className="text-slate-300">{log.action} {log.new_status ? `- ${log.new_status}` : ""}</div>
                        {log.note && <div className="text-slate-500 mt-1">{log.note}</div>}
                      </div>
                    ))}
                    {(!selectedReport.logs || selectedReport.logs.length === 0) && <p className="text-xs text-slate-500">لا يوجد سجل بعد</p>}
                  </div>
                </div>
              </div>
            )}
          </section>
        </div>
      ) : (
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
          <section className="xl:col-span-7 bg-slate-900 rounded-xl p-4 border border-slate-800">
            <div className="grid grid-cols-3 gap-2 mb-4">
              {[
                { value: "under_review", label: "قيد المراجعة", color: "text-amber-400" },
                { value: "accepted", label: "مقبولة", color: "text-emerald-400" },
                { value: "rejected", label: "مرفوضة", color: "text-red-400" },
              ].map((item) => (
                <button key={item.value} onClick={() => setSuggestionStatus(item.value)} className={`bg-slate-800/60 border rounded-lg p-3 text-right ${suggestionStatus === item.value ? "border-emerald-500" : "border-slate-800"}`}>
                  <div className={`text-xl font-bold ${item.color}`}>{suggestions.filter((suggestion) => suggestion.status === item.value).length}</div>
                  <div className="text-xs text-slate-500">{item.label}</div>
                </button>
              ))}
            </div>
            <div className="flex flex-wrap gap-2 mb-4">
              <input value={suggestionSearch} onChange={(event) => setSuggestionSearch(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadSuggestions()} placeholder="بحث في المقترحات" className="flex-1 min-w-52 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              <select value={suggestionStatus} onChange={(event) => setSuggestionStatus(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                <option value="">كل الحالات</option>
                <option value="under_review">قيد المراجعة</option>
                <option value="accepted">مقبولة</option>
                <option value="rejected">مرفوضة</option>
              </select>
              <input value={suggestionCategory} onChange={(event) => setSuggestionCategory(event.target.value)} placeholder="التصنيف" className="w-36 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              <button onClick={loadSuggestions} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
            </div>

            <div className="space-y-2 max-h-[650px] overflow-y-auto">
              {suggestions.map((suggestion) => (
                <button key={suggestion.id} onClick={() => selectSuggestion(suggestion)} className={`w-full text-right p-3 rounded-lg border transition-colors ${selectedSuggestion?.id === suggestion.id ? "bg-emerald-600/10 border-emerald-500" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      <div className="font-medium truncate">{suggestion.title}</div>
                      <p className="text-xs text-slate-500 line-clamp-2 mt-1">{suggestion.description}</p>
                      <div className="flex flex-wrap gap-2 mt-2 text-xs text-slate-400">
                        <span>{personName(suggestion.citizen)}</span>
                        <span>{suggestion.category || "بدون تصنيف"}</span>
                        <span>تأييد: {suggestion.support_votes_count || 0}</span>
                        <span>رفض: {suggestion.oppose_votes_count || 0}</span>
                      </div>
                    </div>
                    <span className={`px-2 py-0.5 rounded text-xs ${suggestionStatusClasses[suggestion.status] || "bg-slate-500/20 text-slate-400"}`}>{suggestionStatusLabels[suggestion.status] || suggestion.status}</span>
                  </div>
                </button>
              ))}
              {suggestions.length === 0 && <p className="text-slate-500 text-sm text-center py-10">لا توجد مقترحات مطابقة</p>}
            </div>
          </section>

          <section className="xl:col-span-5 bg-slate-900 rounded-xl p-4 border border-slate-800">
            {!selectedSuggestion ? (
              <p className="text-slate-500 text-sm text-center py-16">اختر مقترحاً لعرض التفاصيل</p>
            ) : (
              <div className="space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h2 className="text-lg font-bold">{selectedSuggestion.title}</h2>
                    <p className="text-sm text-slate-400">{selectedSuggestion.category || "بدون تصنيف"}</p>
                  </div>
                  <span className={`px-2 py-1 rounded text-xs ${suggestionStatusClasses[selectedSuggestion.status] || "bg-slate-500/20 text-slate-400"}`}>{suggestionStatusLabels[selectedSuggestion.status] || selectedSuggestion.status}</span>
                </div>

                <div className="text-sm text-slate-300 space-y-1">
                  <p><strong>المواطن:</strong> {personName(selectedSuggestion.citizen)}</p>
                  <p><strong>الأصوات:</strong> تأييد {selectedSuggestion.support_votes_count || 0} / رفض {selectedSuggestion.oppose_votes_count || 0}</p>
                  {selectedSuggestion.reviewer && <p><strong>راجع بواسطة:</strong> {personName(selectedSuggestion.reviewer)}</p>}
                </div>
                <p className="text-sm leading-7">{selectedSuggestion.description}</p>

                {selectedSuggestion.status === "under_review" && (
                  <div className="space-y-3 border-t border-slate-800 pt-4">
                    <div className="flex flex-wrap gap-2">
                      <button onClick={acceptSuggestion} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">قبول المقترح</button>
                    </div>
                    <textarea value={suggestionRejectReason} onChange={(event) => setSuggestionRejectReason(event.target.value)} placeholder="سبب الرفض إلزامي عند الرفض" className="w-full px-3 py-2 bg-slate-800 border border-red-900/50 rounded-lg text-sm h-20" />
                    <button onClick={rejectSuggestion} disabled={!suggestionRejectReason.trim()} className="px-3 py-2 bg-red-600 disabled:opacity-50 rounded-lg text-sm">رفض المقترح</button>
                  </div>
                )}

                {selectedSuggestion.status === "accepted" && (
                  <div className="space-y-3 border-t border-slate-800 pt-4">
                    <h3 className="font-bold">تحديث التنفيذ</h3>
                    <select value={implementationStatus} onChange={(event) => setImplementationStatus(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                      <option value="planned">مخطط</option>
                      <option value="in_progress">قيد التنفيذ</option>
                      <option value="completed">مكتمل</option>
                      <option value="paused">متوقف مؤقتاً</option>
                      <option value="cancelled">ملغي</option>
                    </select>
                    <div className="flex items-center gap-3">
                      <input type="range" min="0" max="100" value={implementationProgress} onChange={(event) => setImplementationProgress(Number(event.target.value))} className="flex-1" />
                      <span className="text-sm text-slate-300 w-12">{implementationProgress}%</span>
                    </div>
                    <textarea value={implementationNote} onChange={(event) => setImplementationNote(event.target.value)} placeholder="ملاحظة تنفيذ اختيارية" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
                    <button onClick={updateImplementation} className="px-3 py-2 bg-blue-600 rounded-lg text-sm">حفظ تحديث التنفيذ</button>
                  </div>
                )}

                {selectedSuggestion.implementation_status && (
                  <div className="border-t border-slate-800 pt-4 text-sm text-slate-300 space-y-2">
                    <p><strong>حالة التنفيذ:</strong> {implementationLabels[selectedSuggestion.implementation_status] || selectedSuggestion.implementation_status}</p>
                    <div className="w-full bg-slate-800 rounded-full h-2">
                      <div className="bg-emerald-500 h-2 rounded-full" style={{ width: `${selectedSuggestion.implementation_progress_percent || 0}%` }} />
                    </div>
                    <p>{selectedSuggestion.implementation_progress_percent || 0}%</p>
                    {selectedSuggestion.implementation_note && <p className="text-slate-500">{selectedSuggestion.implementation_note}</p>}
                  </div>
                )}

                {selectedSuggestion.rejection_reason && (
                  <div className="border-t border-slate-800 pt-4">
                    <h3 className="font-bold text-red-300 mb-2">سبب الرفض</h3>
                    <p className="text-sm text-slate-400">{selectedSuggestion.rejection_reason}</p>
                  </div>
                )}
              </div>
            )}
          </section>
        </div>
      )}
    </div>
  );
}
