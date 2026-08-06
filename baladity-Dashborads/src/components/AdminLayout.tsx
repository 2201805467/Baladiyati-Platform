import { useEffect, useRef, useState } from "react";
import { Outlet, useLocation, useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

const navItems = [
  { path: "/admin/reception", label: "لوحة الاستقبال", icon: "📋", roles: ["reception"] },
  { path: "/admin/technical", label: "لوحة القسم", icon: "🔧", roles: ["department"] },
  { path: "/admin/analytics", label: "الإحصائيات", icon: "📊", roles: ["admin"] },
  { path: "/admin/users", label: "المستخدمون", icon: "👥", roles: ["admin"] },
  { path: "/admin/departments", label: "الأقسام", icon: "🏛️", roles: ["admin"] },
  { path: "/admin/categories", label: "التصنيفات", icon: "📋", roles: ["admin"] },
  { path: "/admin/security", label: "الصلاحيات والسجلات", icon: "🔐", roles: ["admin"] },
  { path: "/admin/notifications", label: "الإشعارات", icon: "🔔", roles: ["reception", "department"] },
  { path: "/admin/chats", label: "المحادثات", icon: "💬", roles: ["reception", "department"] },
  { path: "/admin/map", label: "الخريطة", icon: "🗺️", roles: ["reception", "department", "admin"] },
  { path: "/admin/content", label: "المحتوى", icon: "📦", roles: ["admin", "reception"] },
  { path: "/admin/initiatives", label: "المبادرات", icon: "✦", roles: ["admin", "reception"] },
  { path: "/admin/geo-broadcasts", label: "التنبيهات الجغرافية", icon: "!", roles: ["admin", "reception"] },
  { path: "/admin/lost-found", label: "رقابة المفقودات", icon: "?", roles: ["admin", "reception"] },
  { path: "/admin/polls", label: "استطلاعات الرأي", icon: "%", roles: ["admin", "reception"] },
];

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(true);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showPasswordModal, setShowPasswordModal] = useState(false);
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [passwordMessage, setPasswordMessage] = useState("");
  const [passwordError, setPasswordError] = useState("");
  const [passwordLoading, setPasswordLoading] = useState(false);
  const unreadRef = useRef(0);

  useEffect(() => {
    if (user?.role === "admin") {
      unreadRef.current = 0;
      setUnreadCount(0);
      return;
    }

    const fetchCount = async () => {
      try {
        const response = await api.get<{ data: any[]; unreadCount?: number; unread_count?: number }>("/notifications?limit=1");
        const count = response.unreadCount ?? response.unread_count ?? 0;
        if (count !== unreadRef.current) {
          unreadRef.current = count;
          setUnreadCount(count);
        }
      } catch (error) {
        console.error("pollUnread", error);
      }
    };

    fetchCount();
    const interval = setInterval(fetchCount, 30000);
    return () => clearInterval(interval);
  }, [user?.role]);

  const allowed = navItems.filter((item) => user?.role && item.roles.includes(user.role));
  const canChangePassword = user?.role === "reception" || user?.role === "department";

  const resetPasswordForm = () => {
    setCurrentPassword("");
    setNewPassword("");
    setConfirmPassword("");
    setPasswordMessage("");
    setPasswordError("");
  };

  const changePassword = async (event: React.FormEvent) => {
    event.preventDefault();
    setPasswordMessage("");
    setPasswordError("");

    if (newPassword !== confirmPassword) {
      setPasswordError("تأكيد كلمة المرور غير مطابق.");
      return;
    }

    setPasswordLoading(true);
    try {
      await api.put<{ message: string }>("/auth/change-password", {
        current_password: currentPassword,
        password: newPassword,
        password_confirmation: confirmPassword,
      });
      resetPasswordForm();
      setShowPasswordModal(false);
    } catch (error: any) {
      setPasswordError(error.message || "تعذر تغيير كلمة المرور.");
    } finally {
      setPasswordLoading(false);
    }
  };

  return (
    <div className="flex h-screen bg-slate-950 text-white" dir="rtl">
      <aside className={`${open ? "w-64" : "w-16"} transition-all duration-300 bg-slate-900 border-l border-slate-800 flex flex-col`}>
        <div className="p-4 border-b border-slate-800 flex items-center gap-2">
          <button onClick={() => setOpen(!open)} className="text-xl" aria-label="تبديل القائمة">☰</button>
          {open && <span className="font-bold text-emerald-400">بلديتي</span>}
        </div>

        <nav className="flex-1 p-2 space-y-1 overflow-y-auto">
          {allowed.map((item) => (
            <button
              key={item.path}
              onClick={() => navigate(item.path)}
              className={`w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ${
                location.pathname === item.path ? "bg-emerald-600/20 text-emerald-400" : "text-slate-400 hover:text-white hover:bg-slate-800"
              }`}
            >
              <span>{item.icon}</span>
              {open && <span className="flex-1 text-right">{item.label}</span>}
              {open && item.path === "/admin/notifications" && unreadCount > 0 && (
                <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[18px] text-center">
                  {unreadCount > 99 ? "99+" : unreadCount}
                </span>
              )}
            </button>
          ))}
        </nav>

        <div className="p-4 border-t border-slate-800">
          {open && (
            <div className="text-sm mb-2">
              <div className="text-slate-300">{user?.name || "User"}</div>
              <div className="text-slate-500 text-xs">{user?.role}</div>
            </div>
          )}
          {canChangePassword && (
            <button
              onClick={() => { resetPasswordForm(); setShowPasswordModal(true); }}
              className="text-xs text-slate-300 hover:text-white w-full text-right mb-2"
            >
              {open ? "تغيير كلمة المرور" : "🔑"}
            </button>
          )}
          <button onClick={logout} className="text-xs text-red-400 hover:text-red-300 w-full text-right">
            {open ? "تسجيل الخروج" : "⎋"}
          </button>
        </div>
      </aside>

      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>

      {showPasswordModal && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <form onSubmit={changePassword} className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="font-bold text-lg text-emerald-400">تغيير كلمة المرور</h2>
              <button type="button" onClick={() => setShowPasswordModal(false)} className="text-slate-400 hover:text-white">×</button>
            </div>

            <input
              value={currentPassword}
              onChange={(event) => setCurrentPassword(event.target.value)}
              type="password"
              placeholder="كلمة المرور الحالية"
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
              required
            />
            <input
              value={newPassword}
              onChange={(event) => setNewPassword(event.target.value)}
              type="password"
              placeholder="كلمة المرور الجديدة"
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
              minLength={6}
              required
            />
            <input
              value={confirmPassword}
              onChange={(event) => setConfirmPassword(event.target.value)}
              type="password"
              placeholder="تأكيد كلمة المرور الجديدة"
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
              minLength={6}
              required
            />

            {passwordMessage && <p className="text-sm text-emerald-400">{passwordMessage}</p>}
            {passwordError && <p className="text-sm text-red-400 whitespace-pre-line">{passwordError}</p>}

            <div className="flex justify-end gap-2">
              <button type="button" onClick={() => setShowPasswordModal(false)} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">إلغاء</button>
              <button type="submit" disabled={passwordLoading} className="px-3 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-lg text-sm">
                {passwordLoading ? "جاري الحفظ..." : "حفظ"}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
