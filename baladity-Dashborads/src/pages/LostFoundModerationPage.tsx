import { useEffect, useMemo, useState } from "react";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

type ItemStatus = "active" | "resolved" | "expired" | "removed";

interface LostFoundItem {
  id: number;
  item_type: "lost" | "found";
  category: string;
  title: string;
  description: string;
  image_url?: string | null;
  area_name?: string | null;
  incident_date?: string | null;
  status: ItemStatus;
  created_at?: string;
  publisher?: { full_name?: string; email?: string; phone?: string } | null;
  comments_count?: number;
  chat_threads_count?: number;
  comments?: { id: number; comment_text: string; user?: { full_name?: string; email?: string } | null }[];
}

interface AbuseReport {
  id: number;
  reason: string;
  status: string;
  reportable_type: string;
  reportable_id: number;
  created_at?: string;
  reporter?: { full_name?: string; email?: string } | null;
}

const categoryLabels: Record<string, string> = {
  keys: "مفاتيح",
  documents: "وثائق/هوية",
  pet: "حيوان أليف",
  electronics: "إلكترونيات",
  wallet_money: "محفظة/أموال",
  other: "أخرى",
};

const typeLabels: Record<string, string> = {
  lost: "مفقود",
  found: "موجود",
};

const statusLabels: Record<string, string> = {
  active: "نشط",
  resolved: "تم الحل",
  expired: "منتهي الصلاحية",
  removed: "محذوف رقابياً",
};

const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  const apiBase = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");
  return `${apiBase}${url.startsWith("/") ? url : `/${url}`}`;
};

export default function LostFoundModerationPage() {
  const { user } = useAuth();
  const basePath = user?.role === "reception" ? "/reception/content/lost-found" : "/admin/lost-found";

  const [items, setItems] = useState<LostFoundItem[]>([]);
  const [abuseReports, setAbuseReports] = useState<AbuseReport[]>([]);
  const [selected, setSelected] = useState<LostFoundItem | null>(null);
  const [status, setStatus] = useState("");
  const [itemType, setItemType] = useState("");
  const [category, setCategory] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const query = useMemo(() => {
    const params = new URLSearchParams({ per_page: "100" });
    if (status) params.set("status", status);
    if (itemType) params.set("item_type", itemType);
    if (category) params.set("category", category);
    return params.toString();
  }, [status, itemType, category]);

  const loadItems = async () => {
    setLoading(true);
    setError("");
    try {
      const response = await api.get<any>(`${basePath}?${query}`);
      setItems(Array.isArray(response) ? response : response.data || []);
    } catch (err: any) {
      setError(err.message || "تعذر تحميل المفقودات والموجودات.");
    } finally {
      setLoading(false);
    }
  };

  const loadAbuseReports = async () => {
    try {
      const response = await api.get<any>(`${basePath}/abuse-reports?status=pending`);
      setAbuseReports(Array.isArray(response) ? response : response.data || []);
    } catch (err) {
      console.error("loadAbuseReports", err);
    }
  };

  useEffect(() => {
    loadItems();
    loadAbuseReports();
  }, [query, basePath]);

  const openDetails = async (item: LostFoundItem) => {
    try {
      const response = await api.get<{ item: LostFoundItem }>(`${basePath}/${item.id}`);
      setSelected(response.item);
    } catch (err: any) {
      alert(err.message || "تعذر فتح التفاصيل.");
    }
  };

  const removeItem = async (item: LostFoundItem) => {
    const reason = window.prompt("اكتب سبب حذف المنشور أو إزالته رقابياً");
    if (!reason?.trim()) return;

    try {
      await api.patch(`${basePath}/${item.id}/remove`, { removal_reason: reason });
      setSelected(null);
      await loadItems();
    } catch (err: any) {
      alert(err.message || "تعذر حذف المنشور.");
    }
  };

  const updateAbuseReport = async (report: AbuseReport, nextStatus: "reviewed" | "dismissed") => {
    try {
      await api.patch(`${basePath}/abuse-reports/${report.id}`, { status: nextStatus });
      await loadAbuseReports();
    } catch (err: any) {
      alert(err.message || "تعذر تحديث بلاغ الإساءة.");
    }
  };

  return (
    <div className="p-6 space-y-6" dir="rtl">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">رقابة المفقودات والموجودات</h1>
          <p className="text-sm text-slate-400 mt-1">مراجعة منشورات المواطنين وحذف المحتوى المخالف أو المسيء.</p>
        </div>
        <button onClick={() => { loadItems(); loadAbuseReports(); }} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
        <select value={itemType} onChange={(e) => setItemType(e.target.value)} className="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-sm">
          <option value="">كل الأنواع</option>
          <option value="found">موجودات</option>
          <option value="lost">مفقودات</option>
        </select>
        <select value={category} onChange={(e) => setCategory(e.target.value)} className="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-sm">
          <option value="">كل التصنيفات</option>
          {Object.entries(categoryLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}
        </select>
        <select value={status} onChange={(e) => setStatus(e.target.value)} className="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-sm">
          <option value="">كل الحالات</option>
          {Object.entries(statusLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}
        </select>
        <div className="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-sm text-slate-300">
          بلاغات إساءة معلقة: <span className="text-red-400 font-bold">{abuseReports.length}</span>
        </div>
      </div>

      {error && <div className="rounded-lg border border-red-500/40 bg-red-500/10 p-3 text-sm text-red-300">{error}</div>}

      <div className="grid grid-cols-1 xl:grid-cols-[1fr_360px] gap-5">
        <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
          <table className="w-full text-sm">
            <thead className="bg-slate-800 text-slate-300">
              <tr>
                <th className="p-3 text-right">المنشور</th>
                <th className="p-3">النوع</th>
                <th className="p-3">التصنيف</th>
                <th className="p-3">الحالة</th>
                <th className="p-3">التفاعل</th>
                <th className="p-3">إجراء</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr key={item.id} className="border-t border-slate-800 hover:bg-slate-800/50">
                  <td className="p-3">
                    <div className="font-semibold">{item.title}</div>
                    <div className="text-xs text-slate-500">{item.area_name || "موقع تقريبي غير محدد"}</div>
                  </td>
                  <td className="p-3 text-center">{typeLabels[item.item_type] || item.item_type}</td>
                  <td className="p-3 text-center">{categoryLabels[item.category] || item.category}</td>
                  <td className="p-3 text-center">{statusLabels[item.status] || item.status}</td>
                  <td className="p-3 text-center text-slate-400">{item.comments_count || 0} تعليق / {item.chat_threads_count || 0} دردشة</td>
                  <td className="p-3 text-center">
                    <button onClick={() => openDetails(item)} className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-xs">تفاصيل</button>
                  </td>
                </tr>
              ))}
              {!loading && items.length === 0 && (
                <tr><td colSpan={6} className="p-10 text-center text-slate-500">لا توجد منشورات مطابقة</td></tr>
              )}
              {loading && <tr><td colSpan={6} className="p-10 text-center text-slate-500">جاري التحميل...</td></tr>}
            </tbody>
          </table>
        </div>

        <div className="bg-slate-900 border border-slate-800 rounded-xl p-4 space-y-3">
          <h2 className="font-bold text-emerald-400">بلاغات الإساءة</h2>
          {abuseReports.length === 0 && <p className="text-sm text-slate-500">لا توجد بلاغات إساءة معلقة.</p>}
          {abuseReports.map((report) => (
            <div key={report.id} className="rounded-lg border border-slate-800 p-3 space-y-2">
              <div className="text-xs text-slate-500">{report.reportable_type.includes("Message") ? "رسالة دردشة" : "منشور"} #{report.reportable_id}</div>
              <p className="text-sm">{report.reason}</p>
              <div className="flex gap-2">
                <button onClick={() => updateAbuseReport(report, "reviewed")} className="px-2 py-1 rounded bg-emerald-600 hover:bg-emerald-500 text-xs">تمت المراجعة</button>
                <button onClick={() => updateAbuseReport(report, "dismissed")} className="px-2 py-1 rounded bg-slate-700 hover:bg-slate-600 text-xs">رفض البلاغ</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {selected && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="w-full max-w-4xl max-h-[90vh] overflow-y-auto bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <div className="flex justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold text-emerald-400">{selected.title}</h2>
                <p className="text-sm text-slate-400">{typeLabels[selected.item_type]} - {categoryLabels[selected.category] || selected.category}</p>
              </div>
              <button onClick={() => setSelected(null)} className="text-slate-400 hover:text-white">×</button>
            </div>

            {selected.image_url && <img src={assetUrl(selected.image_url)} alt="صورة المنشور" className="w-full max-h-80 object-cover rounded-lg border border-slate-800" />}
            <p className="text-slate-200 leading-7">{selected.description}</p>

            <div className="grid md:grid-cols-3 gap-3 text-sm">
              <div className="bg-slate-800 rounded-lg p-3">الناشر: {selected.publisher?.full_name || selected.publisher?.email || "غير معروف"}</div>
              <div className="bg-slate-800 rounded-lg p-3">الموقع التقريبي: {selected.area_name || "غير محدد"}</div>
              <div className="bg-slate-800 rounded-lg p-3">تاريخ الفقد/العثور: {selected.incident_date || "-"}</div>
            </div>

            <div className="grid md:grid-cols-[1fr_280px] gap-4">
              <section className="space-y-2">
                <h3 className="font-bold">التعليقات العامة</h3>
                {(selected.comments || []).length === 0 && <p className="text-sm text-slate-500">لا توجد تعليقات.</p>}
                {(selected.comments || []).map((comment) => (
                  <div key={comment.id} className="bg-slate-800 rounded-lg p-3 text-sm">
                    <div className="text-xs text-slate-500 mb-1">{comment.user?.full_name || comment.user?.email || "مواطن"}</div>
                    {comment.comment_text}
                  </div>
                ))}
              </section>

              <aside className="rounded-lg border border-slate-800 bg-slate-800/60 p-4 text-sm text-slate-300">
                <h3 className="font-bold text-slate-100 mb-2">خصوصية الدردشة</h3>
                <p className="leading-6">لا تعرض لوحة الرقابة محتوى الدردشات الخاصة بين المواطنين أو أسماء أطرافها.</p>
                <div className="mt-3 rounded-lg bg-slate-900 p-3">
                  عدد غرف الدردشة: <span className="font-bold text-emerald-400">{selected.chat_threads_count || 0}</span>
                </div>
              </aside>
            </div>

            <div className="flex justify-end gap-2">
              {selected.status !== "removed" && (
                <button onClick={() => removeItem(selected)} className="px-3 py-2 bg-red-600 hover:bg-red-500 rounded-lg text-sm">حذف/إزالة رقابية</button>
              )}
              <button onClick={() => setSelected(null)} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">إغلاق</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
