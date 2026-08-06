import { useEffect, useMemo, useState } from "react";
import { useLocation } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

interface Department {
  id: string | number;
  dept_name?: string;
  name?: string;
}

interface ChatMessage {
  id: number;
  sender_role: string;
  sender_label: string;
  message_text?: string | null;
  image_url?: string | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  is_system?: boolean;
  is_mine?: boolean;
  created_at?: string | null;
}

interface ChatThread {
  id: number;
  status: string;
  status_label?: string;
  unread_count?: number;
  reception_unread_count?: number;
  department_unread_count?: number;
  latest_message?: string | null;
  last_message_at?: string | null;
  auto_delete_at?: string | null;
  staff_online?: boolean;
  citizen?: { full_name?: string; email?: string; phone?: string } | null;
  assigned_department?: { id: number | string; dept_name?: string } | null;
  messages?: ChatMessage[];
}

const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  const apiOrigin = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");
  return `${apiOrigin}${url.startsWith("/") ? url : `/${url}`}`;
};

const statusClass: Record<string, string> = {
  new: "bg-amber-500/15 text-amber-300 border-amber-500/30",
  active: "bg-emerald-500/15 text-emerald-300 border-emerald-500/30",
  closed: "bg-slate-500/15 text-slate-300 border-slate-500/30",
};

const formatDateTime = (value?: string | null) => {
  if (!value) return "";
  return new Intl.DateTimeFormat("ar-LY", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

const departmentName = (department?: Department | null) => department?.dept_name || department?.name || "-";

export default function MunicipalityChatsPage() {
  const { user } = useAuth();
  const location = useLocation();
  const isReception = user?.role === "reception";
  const basePath = isReception ? "/reception/chats" : "/department/chats";
  const [threads, setThreads] = useState<ChatThread[]>([]);
  const [selected, setSelected] = useState<ChatThread | null>(null);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [replyText, setReplyText] = useState("");
  const [image, setImage] = useState<File | null>(null);
  const [transferDeptId, setTransferDeptId] = useState("");
  const [transferNote, setTransferNote] = useState("");
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    loadThreads();
  }, [statusFilter, basePath]);

  useEffect(() => {
    const interval = window.setInterval(() => {
      loadThreads({ silent: true });
      if (selected?.id) {
        openThread(selected.id, { resetInput: false, silent: true });
      }
    }, 3000);

    return () => window.clearInterval(interval);
  }, [selected?.id, statusFilter, basePath]);

  useEffect(() => {
    const threadId = new URLSearchParams(location.search).get("threadId");
    if (!threadId) return;
    openThread(Number(threadId));
  }, [location.search, basePath]);

  useEffect(() => {
    if (!isReception) return;
    api.get<{ data?: Department[]; departments?: Department[] }>("/reception/departments")
      .then((response) => setDepartments(response.departments || response.data || []))
      .catch((error) => console.error("loadDepartments", error));
  }, [isReception]);

  const canReply = useMemo(() => {
    if (!selected || selected.status === "closed") return false;
    if (isReception) return !selected.assigned_department;
    return Boolean(selected.assigned_department);
  }, [selected, isReception]);

  const loadThreads = async (options: { silent?: boolean } = {}) => {
    if (!options.silent) setLoading(true);
    try {
      const params = new URLSearchParams({ per_page: "50" });
      if (statusFilter) params.set("status", statusFilter);
      const response = await api.get<{ data: ChatThread[] }>(`${basePath}?${params.toString()}`);
      setThreads(response.data || []);
    } catch (error) {
      console.error("loadThreads", error);
    } finally {
      if (!options.silent) setLoading(false);
    }
  };

  const openThread = async (threadId: number, options: { resetInput?: boolean; silent?: boolean } = {}) => {
    try {
      const response = await api.get<{ thread: ChatThread }>(`${basePath}/${threadId}`);
      setSelected(response.thread);
      if (options.resetInput !== false) {
        setReplyText("");
        setImage(null);
      }
      if (!options.silent) await loadThreads();
    } catch (error: any) {
      if (options.silent) {
        console.error("openThread", error);
        return;
      }
      alert(error.message || "تعذر فتح المحادثة.");
    }
  };

  const sendReply = async () => {
    if (!selected || (!replyText.trim() && !image)) return;
    const form = new FormData();
    if (replyText.trim()) form.append("message_text", replyText.trim());
    if (image) form.append("image", image);

    setBusy(true);
    try {
      const response = await api.post<{ thread: ChatThread }>(`${basePath}/${selected.id}/reply`, form);
      setSelected(response.thread);
      setReplyText("");
      setImage(null);
      await loadThreads();
    } catch (error: any) {
      alert(error.message || "تعذر إرسال الرد.");
    } finally {
      setBusy(false);
    }
  };

  const transferThread = async () => {
    if (!selected || !transferDeptId) return;
    setBusy(true);
    try {
      const response = await api.patch<{ thread: ChatThread }>(`${basePath}/${selected.id}/transfer`, {
        dept_id: transferDeptId,
        note: transferNote,
      });
      setSelected(response.thread);
      setTransferDeptId("");
      setTransferNote("");
      await loadThreads();
    } catch (error: any) {
      alert(error.message || "تعذر تحويل المحادثة.");
    } finally {
      setBusy(false);
    }
  };

  const closeThread = async () => {
    if (!selected || !confirm("هل تريد إغلاق هذه المحادثة؟")) return;
    setBusy(true);
    try {
      const response = await api.patch<{ message?: string; thread: ChatThread }>(`${basePath}/${selected.id}/close`, {});
      setSelected(response.thread);
      alert(response.message || "تم إغلاق المحادثة. سيتم حذفها تلقائياً بعد ساعتين إذا لم يرسل المواطن رسالة جديدة.");
      await loadThreads();
    } catch (error: any) {
      alert(error.message || "تعذر إغلاق المحادثة.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="p-6 space-y-5" dir="rtl">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">المحادثات</h1>
          <p className="text-sm text-slate-500 mt-1">تواصل سريع بين المواطنين والبلدية للاستفسارات العامة.</p>
        </div>
        <div className="flex gap-2">
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm">
            <option value="">كل الحالات</option>
            <option value="new">بانتظار الرد</option>
            <option value="active">جارية</option>
            <option value="closed">مغلقة</option>
          </select>
          <button onClick={() => loadThreads()} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
        </div>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_1fr] gap-4 min-h-[680px]">
        <section className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
          <div className="p-3 border-b border-slate-800 text-sm text-slate-400">
            {loading ? "جاري التحميل..." : `${threads.length} محادثة`}
          </div>
          <div className="divide-y divide-slate-800 max-h-[630px] overflow-y-auto">
            {threads.length === 0 && (
              <div className="p-8 text-center text-slate-500">لا توجد محادثات حالياً.</div>
            )}
            {threads.map((thread) => (
              <button
                key={thread.id}
                onClick={() => openThread(thread.id)}
                className={`w-full text-right p-4 hover:bg-slate-800 transition-colors ${selected?.id === thread.id ? "bg-slate-800" : ""}`}
              >
                <div className="flex items-center gap-2">
                  <span className="font-semibold text-slate-100 flex-1">{thread.citizen?.full_name || "مواطن"}</span>
                  {(thread.unread_count || 0) > 0 && (
                    <span className="bg-red-500 text-white text-xs rounded-full px-2 py-0.5">{thread.unread_count}</span>
                  )}
                </div>
                <div className="mt-1 text-xs text-slate-500">{thread.citizen?.email}</div>
                <div className="mt-2 text-sm text-slate-400 line-clamp-2">{thread.latest_message || "لا توجد رسائل"}</div>
                <div className="mt-3 flex items-center justify-between gap-2">
                  <span className={`text-xs border rounded-full px-2 py-0.5 ${statusClass[thread.status] || "border-slate-700 text-slate-400"}`}>
                    {thread.status_label || thread.status}
                  </span>
                  <span className="text-xs text-slate-500">{formatDateTime(thread.last_message_at)}</span>
                </div>
              </button>
            ))}
          </div>
        </section>

        <section className="bg-slate-900 border border-slate-800 rounded-xl min-h-[680px] flex flex-col">
          {!selected ? (
            <div className="flex-1 grid place-items-center text-slate-500">اختر محادثة لعرض التفاصيل.</div>
          ) : (
            <>
              <div className="p-4 border-b border-slate-800 flex flex-wrap items-center justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold">{selected.citizen?.full_name || "مواطن"}</h2>
                    <span className={`text-xs border rounded-full px-2 py-0.5 ${statusClass[selected.status] || "border-slate-700 text-slate-400"}`}>
                      {selected.status_label || selected.status}
                    </span>
                    {selected.staff_online && <span className="text-xs text-emerald-300">● متصل</span>}
                  </div>
                  <p className="text-sm text-slate-500 mt-1">
                    {selected.assigned_department ? `محولة إلى: ${selected.assigned_department.dept_name}` : "تحت متابعة موظف الاستقبال"}
                  </p>
                </div>
                <button disabled={busy || selected.status === "closed"} onClick={closeThread} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 disabled:opacity-50 rounded-lg text-sm">
                  إغلاق المحادثة
                </button>
              </div>

              <div className="flex-1 overflow-y-auto p-4 space-y-3 bg-slate-950/50">
                {(selected.messages || []).map((message) => (
                  <div
                    key={message.id}
                    className={`max-w-[78%] rounded-xl p-3 border ${
                      message.is_system
                        ? "mx-auto bg-slate-800/80 border-slate-700 text-slate-300 text-center"
                        : message.is_mine
                          ? "mr-auto bg-emerald-600/20 border-emerald-500/30"
                          : "ml-auto bg-slate-800 border-slate-700"
                    }`}
                  >
                    <div className="text-xs text-slate-400 mb-1">{message.sender_label} · {formatDateTime(message.created_at)}</div>
                    {message.message_text && <p className="whitespace-pre-wrap text-sm leading-6">{message.message_text}</p>}
                    {message.image_url && (
                      <a href={assetUrl(message.image_url)} target="_blank" rel="noreferrer">
                        <img src={assetUrl(message.image_url)} alt="attachment" className="mt-2 rounded-lg max-h-56 object-cover" />
                      </a>
                    )}
                    {message.latitude && message.longitude && (
                      <a
                        href={`https://www.google.com/maps/search/?api=1&query=${message.latitude},${message.longitude}`}
                        target="_blank"
                        rel="noreferrer"
                        className="inline-block mt-2 text-xs text-cyan-300 hover:text-cyan-200"
                      >
                        عرض الموقع على الخريطة
                      </a>
                    )}
                  </div>
                ))}
              </div>

              {isReception && !selected.assigned_department && selected.status !== "closed" && (
                <div className="p-4 border-t border-slate-800 bg-slate-900/70">
                  <div className="grid grid-cols-1 md:grid-cols-[220px_1fr_auto] gap-2">
                    <select value={transferDeptId} onChange={(event) => setTransferDeptId(event.target.value)} className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm">
                      <option value="">اختر القسم للتحويل</option>
                      {departments.map((department) => (
                        <option key={department.id} value={department.id}>{departmentName(department)}</option>
                      ))}
                    </select>
                    <input value={transferNote} onChange={(event) => setTransferNote(event.target.value)} placeholder="ملاحظة التحويل اختياري" className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm" />
                    <button disabled={busy || !transferDeptId} onClick={transferThread} className="px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:opacity-50 rounded-lg text-sm">تحويل</button>
                  </div>
                </div>
              )}

              <div className="p-4 border-t border-slate-800 space-y-3">
                {!canReply && (
                  <div className="text-sm text-amber-300 bg-amber-500/10 border border-amber-500/20 rounded-lg p-3">
                    {selected.status === "closed"
                      ? `هذه المحادثة مغلقة، وسيتم حذفها تلقائياً بعد ساعتين إذا لم يرسل المواطن رسالة جديدة${selected.auto_delete_at ? ` (${formatDateTime(selected.auto_delete_at)})` : ""}.`
                      : "تم تحويل المحادثة إلى القسم المختص، والرد متاح لموظف القسم فقط."}
                  </div>
                )}
                <textarea
                  value={replyText}
                  onChange={(event) => setReplyText(event.target.value)}
                  disabled={!canReply}
                  rows={3}
                  placeholder="اكتب الرد هنا..."
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-sm disabled:opacity-60"
                />
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <input disabled={!canReply} type="file" accept="image/*" onChange={(event) => setImage(event.target.files?.[0] || null)} className="text-sm text-slate-400" />
                  <button disabled={!canReply || busy || (!replyText.trim() && !image)} onClick={sendReply} className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-lg text-sm">
                    إرسال الرد
                  </button>
                </div>
              </div>
            </>
          )}
        </section>
      </div>
    </div>
  );
}
