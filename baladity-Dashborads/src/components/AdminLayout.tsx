import { useState, useEffect, useRef } from "react";
import { Outlet, useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";

const navItems = [
  { path: "/admin/reception", label: "لوحة الاستقبال", icon: "📋", roles: ["reception", "admin"] },
  { path: "/admin/technical", label: "لوحة الصيانة", icon: "🔧", roles: ["department", "admin"] },
  { path: "/admin/analytics", label: "الإحصائيات", icon: "📊", roles: ["admin"] },
  { path: "/admin/users", label: "المستخدمين", icon: "👥", roles: ["admin"] },
  { path: "/admin/departments", label: "الأقسام", icon: "🏛️", roles: ["admin"] },
  { path: "/admin/categories", label: "التصنيفات", icon: "📋", roles: ["admin"] },
  { path: "/admin/notifications", label: "الإشعارات", icon: "🔔", roles: ["reception", "department", "admin"] },
  { path: "/admin/map", label: "الخريطة", icon: "🗺️", roles: ["reception", "department", "admin"] },
  { path: "/admin/content", label: "المحتوى", icon: "📦", roles: ["admin"] },
];

export default function AdminLayout() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(true);
  const [unreadCount, setUnreadCount] = useState(0);

  const unreadRef = useRef(0);
  useEffect(() => {
    const fetchCount = async () => {
      try { const r = await api.get<{ data: any[]; unreadCount: number }>("/api/notifications?limit=1"); if (r.unreadCount !== unreadRef.current) { unreadRef.current = r.unreadCount; setUnreadCount(r.unreadCount); } } catch (e) { console.error("pollUnread", e); }
    };
    fetchCount();
    const interval = setInterval(fetchCount, 30000);
    return () => clearInterval(interval);
  }, []);

  const allowed = navItems.filter((item) => user?.role && item.roles.includes(user.role));

  return (
    <div className="flex h-screen bg-slate-950 text-white" dir="rtl">
      <aside className={`${open ? "w-64" : "w-16"} transition-all duration-300 bg-slate-900 border-l border-slate-800 flex flex-col`}>
        <div className="p-4 border-b border-slate-800 flex items-center gap-2">
          <button onClick={() => setOpen(!open)} className="text-xl">☰</button>
          {open && <span className="font-bold text-emerald-400">بلديتي</span>}
        </div>
        <nav className="flex-1 p-2 space-y-1">
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
                <span className="bg-red-500 text-white text-xs rounded-full px-1.5 py-0.5 min-w-[18px] text-center">{unreadCount > 99 ? "99+" : unreadCount}</span>
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
          <button onClick={logout} className="text-xs text-red-400 hover:text-red-300 w-full text-right">
            {open ? "تسجيل الخروج" : "🚪"}
          </button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">
        <Outlet />
      </main>
    </div>
  );
}
