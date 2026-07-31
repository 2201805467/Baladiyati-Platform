import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Notification } from "../types";

interface NotificationsResponse {
  data: Notification[];
  unread_count?: number;
  unreadCount?: number;
  current_page?: number;
  last_page?: number;
}

const isUnread = (notification: Notification) => notification.is_read === false || notification.isRead === false;
const createdAt = (notification: Notification) => notification.created_at || notification.createdAt || "";
const isClosedReportComment = (notification: Notification) => notification.type === "closed_report_citizen_comment";
const isSlaOverdue = (notification: Notification) => notification.type === "report_sla_overdue" || notification.type === "report_sla_overdue_department";
const isSlaWarning = (notification: Notification) => notification.type === "report_sla_warning";

const formatDateTime = (value: string) => {
  if (!value) return "";
  return new Intl.DateTimeFormat("ar-LY", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(new Date(value));
};

const notificationLabel = (type: string) => {
  const labels: Record<string, string> = {
    closed_report_citizen_comment: "اعتراض بعد الإغلاق",
    citizen_report_comment: "تعليق مواطن",
    report_comment: "رد على بلاغ",
    report_status: "حالة بلاغ",
    report_rejected: "رفض بلاغ",
    department_report_assigned: "بلاغ محول",
    report_sla_warning: "تحذير SLA",
    report_sla_overdue: "تجاوز SLA",
    report_sla_overdue_department: "تجاوز SLA",
    new_report_submitted: "بلاغ جديد",
    new_suggestion_submitted: "مقترح جديد",
    citizen_report_comment_reception: "تعليق مواطن",
    suggestion_status: "حالة مقترح",
    suggestion_implementation: "تنفيذ مقترح",
    initiative_capacity_full: "اكتمال عدد المتطوعين",
    initiative_cancelled: "إلغاء مبادرة",
    initiative_completed: "إنهاء مبادرة",
    initiative_published: "مبادرة جديدة",
  };

  return labels[type] || type;
};

const relatedPath = (notification: Notification, role?: string | null) => {
  const relatedType = notification.related_type || "";
  const relatedId = notification.related_id ? String(notification.related_id) : "";

  if (relatedType.includes("Report")) {
    const query = relatedId ? `?reportId=${encodeURIComponent(relatedId)}` : "";
    if (role === "department") return `/admin/technical${query}`;
    if (role === "reception") return `/admin/reception${query}`;
    return "/admin/notifications";
  }

  if (relatedType.includes("Suggestion")) {
    return role === "reception" ? "/admin/reception" : "/admin/notifications";
  }

  if (relatedType.includes("CommunityInitiative")) {
    return "/admin/initiatives";
  }

  return "/admin/notifications";
};

export default function NotificationsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadNotifications();
  }, [page]);

  const urgentCount = useMemo(
    () => notifications.filter((notification) => (isClosedReportComment(notification) || isSlaOverdue(notification)) && isUnread(notification)).length,
    [notifications]
  );

  const loadNotifications = async () => {
    setLoading(true);
    try {
      const response = await api.get<NotificationsResponse>(`/notifications?page=${page}&per_page=20`);
      setNotifications(response.data || []);
      setUnreadCount(response.unread_count ?? response.unreadCount ?? 0);
      setTotalPages(response.last_page || 1);
    } catch (error) {
      console.error("loadNotifications", error);
    } finally {
      setLoading(false);
    }
  };

  const handleMarkAsRead = async (notification: Notification) => {
    try {
      if (isUnread(notification)) {
        await api.patch(`/notifications/${notification.id}/read`);
        setNotifications((current) => current.map((item) => (
          item.id === notification.id ? { ...item, is_read: true, isRead: true } : item
        )));
        setUnreadCount((current) => Math.max(0, current - 1));
      }
      navigate(relatedPath(notification, user?.role));
    } catch (error) {
      console.error("markAsRead", error);
    }
  };

  const handleMarkAllAsRead = async () => {
    try {
      await api.patch("/notifications/read-all");
      setNotifications((current) => current.map((item) => ({ ...item, is_read: true, isRead: true })));
      setUnreadCount(0);
    } catch (error) {
      console.error("markAllAsRead", error);
    }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">الإشعارات</h1>
          <p className="text-sm text-slate-500 mt-1">متابعة التحديثات والتنبيهات الخاصة بحسابك.</p>
        </div>
        <div className="flex items-center gap-2">
          {unreadCount > 0 && (
            <span className="px-3 py-1.5 rounded-lg bg-red-500/10 text-red-300 text-sm border border-red-500/20">
              غير مقروءة: {unreadCount}
            </span>
          )}
          {unreadCount > 0 && (
            <button onClick={handleMarkAllAsRead} className="px-4 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm text-slate-300">
              تحديد الكل كمقروء
            </button>
          )}
        </div>
      </div>

      {urgentCount > 0 && (
        <div className="rounded-lg border border-rose-500/40 bg-rose-500/10 p-4 text-rose-100">
          <div className="font-bold">توجد إشعارات حرجة تحتاج متابعة</div>
          <p className="text-sm text-rose-200 mt-1">راجع التنبيهات المميزة أدناه، مثل اعتراض مواطن على بلاغ مغلق أو تجاوز SLA.</p>
        </div>
      )}

      {loading ? (
        <div className="bg-slate-900 rounded-lg p-8 text-center text-slate-500 border border-slate-800">
          جاري تحميل الإشعارات...
        </div>
      ) : notifications.length === 0 ? (
        <div className="bg-slate-900 rounded-lg p-8 text-center text-slate-500 border border-slate-800">
          <div className="text-4xl mb-2">🔔</div>
          <p>لا توجد إشعارات</p>
        </div>
      ) : (
        <div className="space-y-2">
          {notifications.map((notification) => {
            const unread = isUnread(notification);
            const urgent = isClosedReportComment(notification) || isSlaOverdue(notification);
            const warning = isSlaWarning(notification);

            return (
              <button
                key={notification.id}
                onClick={() => handleMarkAsRead(notification)}
                className={`w-full text-right rounded-lg p-4 border transition-colors ${
                  urgent
                    ? "bg-rose-500/10 border-rose-500/40 hover:bg-rose-500/15"
                    : warning
                      ? "bg-amber-500/10 border-amber-500/40 hover:bg-amber-500/15"
                    : unread
                      ? "bg-emerald-600/5 border-emerald-600/30 hover:bg-emerald-600/10"
                      : "bg-slate-900 border-slate-800 hover:border-slate-700"
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-medium text-sm text-slate-100">{notification.title}</span>
                      <span className={`px-2 py-0.5 rounded text-xs ${
                        urgent
                          ? "bg-rose-500/20 text-rose-200"
                          : warning
                            ? "bg-amber-500/20 text-amber-200"
                            : "bg-slate-800 text-slate-300"
                      }`}>
                        {notificationLabel(notification.type)}
                      </span>
                      {unread && <span className="w-2 h-2 rounded-full bg-emerald-400" />}
                    </div>
                    <p className="text-sm text-slate-400 mt-2 leading-6">{notification.body}</p>
                    <div className="flex flex-wrap gap-3 mt-3 text-xs text-slate-500">
                      {createdAt(notification) && <span>{formatDateTime(createdAt(notification))}</span>}
                      {notification.related_id && <span>مرجع: #{notification.related_id}</span>}
                    </div>
                  </div>
                </div>
              </button>
            );
          })}
        </div>
      )}

      {totalPages > 1 && (
        <div className="flex gap-2 justify-center">
          <button disabled={page <= 1} onClick={() => setPage((current) => current - 1)} className="px-3 py-1.5 bg-slate-800 rounded text-sm disabled:opacity-50">
            السابق
          </button>
          <span className="text-sm text-slate-400 py-1.5">صفحة {page} من {totalPages}</span>
          <button disabled={page >= totalPages} onClick={() => setPage((current) => current + 1)} className="px-3 py-1.5 bg-slate-800 rounded text-sm disabled:opacity-50">
            التالي
          </button>
        </div>
      )}
    </div>
  );
}
