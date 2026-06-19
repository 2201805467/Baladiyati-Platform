import { useState, useEffect } from "react";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";
import { useNavigate } from "react-router-dom";
import type { Notification, PaginatedResponse } from "../types";

export default function NotificationsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  useEffect(() => { if (!isLoading && !user) navigate("/login"); }, [user, isLoading, navigate]);
  useEffect(() => { loadNotifications(); }, [page]);

  const loadNotifications = async () => {
    try {
      const r = await api.get<any>(`/api/notifications?page=${page}&limit=20`);
      setNotifications(r.data);
      setUnreadCount(r.unreadCount || 0);
      setTotalPages(r.pagination?.totalPages || 1);
    } catch (e) { console.error("loadNotifications", e); }
  };

  const handleMarkAsRead = async (id: string) => {
    try { await api.patch(`/api/notifications/${id}/read`); loadNotifications(); } catch (e) { console.error("markAsRead", e); }
  };

  const handleMarkAllAsRead = async () => {
    try { await api.patch("/api/notifications/read-all"); loadNotifications(); } catch (e) { console.error("markAllAsRead", e); }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">الإشعارات</h1>
        {unreadCount > 0 && (
          <button onClick={handleMarkAllAsRead} className="px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm text-slate-300">تحديد الكل كمقروء ({unreadCount})</button>
        )}
      </div>
      {notifications.length === 0 ? (
        <div className="bg-slate-900 rounded-xl p-8 text-center text-slate-500">
          <div className="text-4xl mb-2">🔔</div>
          <p>لا توجد إشعارات</p>
        </div>
      ) : (
        <div className="space-y-2">
          {notifications.map(n => (
            <div key={n.id} className={`bg-slate-900 rounded-xl p-4 border transition-colors cursor-pointer ${n.isRead ? "border-slate-800" : "border-emerald-600/30 bg-emerald-600/5"}`} onClick={() => !n.isRead && handleMarkAsRead(n.id)}>
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <div className="flex items-center gap-2">
                    <span className="font-medium text-sm">{n.title}</span>
                    {!n.isRead && <span className="w-2 h-2 rounded-full bg-emerald-400" />}
                  </div>
                  <p className="text-sm text-slate-400 mt-1">{n.body}</p>
                  <div className="flex gap-3 mt-2 text-xs text-slate-600">
                    <span>{new Date(n.createdAt).toLocaleString("ar")}</span>
                    {n.report && <span>بلاغ: {n.report.title}</span>}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
      {totalPages > 1 && (
        <div className="flex gap-2 justify-center">
          <button disabled={page <= 1} onClick={() => setPage(p => p - 1)} className="px-3 py-1 bg-slate-800 rounded text-sm disabled:opacity-50">السابق</button>
          <span className="text-sm text-slate-400 py-1">صفحة {page} من {totalPages}</span>
          <button disabled={page >= totalPages} onClick={() => setPage(p => p + 1)} className="px-3 py-1 bg-slate-800 rounded text-sm disabled:opacity-50">التالي</button>
        </div>
      )}
    </div>
  );
}
