import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

interface Permission {
  id: number | string;
  permission_name: string;
  description?: string | null;
}

interface Role {
  id: number | string;
  role_name: string;
  description?: string | null;
  permissions: Permission[];
}

interface SecurityLog {
  id: number | string;
  user_id?: number | string | null;
  action: string;
  ip_address?: string | null;
  status: string;
  created_at?: string | null;
  user?: {
    full_name?: string | null;
    email?: string | null;
    employee_number?: string | null;
  } | null;
}

const roleLabels: Record<string, string> = {
  admin: "الأدمن",
  reception: "موظف الاستقبال",
  department: "موظف القسم",
  citizen: "المواطن",
};

const statusClasses: Record<string, string> = {
  allowed: "bg-emerald-500/20 text-emerald-400",
  denied: "bg-red-500/20 text-red-400",
  success: "bg-emerald-500/20 text-emerald-400",
  failed: "bg-red-500/20 text-red-400",
};

export default function PermissionsSecurityPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState<"permissions" | "logs">("permissions");
  const [roles, setRoles] = useState<Role[]>([]);
  const [permissions, setPermissions] = useState<Permission[]>([]);
  const [selectedRoleId, setSelectedRoleId] = useState<string>("");
  const [selectedPermissionIds, setSelectedPermissionIds] = useState<Set<string>>(new Set());
  const [saving, setSaving] = useState(false);

  const [logs, setLogs] = useState<SecurityLog[]>([]);
  const [logStatus, setLogStatus] = useState("");
  const [logAction, setLogAction] = useState("");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadRolesAndPermissions();
    loadLogs();
  }, []);

  useEffect(() => {
    const selectedRole = roles.find((role) => String(role.id) === selectedRoleId);
    setSelectedPermissionIds(new Set((selectedRole?.permissions || []).map((permission) => String(permission.id))));
  }, [selectedRoleId, roles]);

  const selectedRole = useMemo(() => roles.find((role) => String(role.id) === selectedRoleId) || null, [roles, selectedRoleId]);

  const loadRolesAndPermissions = async () => {
    try {
      const [rolesResponse, permissionsResponse] = await Promise.all([
        api.get<{ roles: Role[] }>("/admin/roles"),
        api.get<{ permissions: Permission[] }>("/admin/permissions"),
      ]);
      setRoles(rolesResponse.roles || []);
      setPermissions(permissionsResponse.permissions || []);
      setSelectedRoleId((current) => current || String(rolesResponse.roles?.[0]?.id || ""));
    } catch (error) {
      console.error("loadRolesAndPermissions", error);
    }
  };

  const loadLogs = async () => {
    try {
      const params = new URLSearchParams();
      params.set("per_page", "50");
      if (logStatus) params.set("status", logStatus);
      if (logAction) params.set("action", logAction);
      if (dateFrom) params.set("date_from", dateFrom);
      if (dateTo) params.set("date_to", dateTo);
      const response = await api.get<any>(`/admin/security-logs?${params.toString()}`);
      setLogs(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadLogs", error);
    }
  };

  const togglePermission = (permissionId: string) => {
    setSelectedPermissionIds((current) => {
      const next = new Set(current);
      if (next.has(permissionId)) next.delete(permissionId);
      else next.add(permissionId);
      return next;
    });
  };

  const savePermissions = async () => {
    if (!selectedRole) return;
    setSaving(true);
    try {
      const response = await api.put<{ role: Role }>(`/admin/roles/${selectedRole.id}/permissions`, {
        permission_ids: Array.from(selectedPermissionIds).map((id) => Number(id)),
      });
      setRoles((current) => current.map((role) => String(role.id) === String(response.role.id) ? response.role : role));
    } catch (error: any) {
      alert(error.message);
    } finally {
      setSaving(false);
    }
  };

  const permissionsByGroup = useMemo(() => {
    return permissions.reduce<Record<string, Permission[]>>((groups, permission) => {
      const group = permission.permission_name.split("_").slice(-1)[0] || "general";
      if (!groups[group]) groups[group] = [];
      groups[group].push(permission);
      return groups;
    }, {});
  }, [permissions]);

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">الصلاحيات والسجلات الأمنية</h1>
          <p className="text-sm text-slate-500 mt-1">إدارة صلاحيات الأدوار ومراقبة محاولات الوصول.</p>
        </div>
        <button onClick={tab === "permissions" ? loadRolesAndPermissions : loadLogs} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="flex gap-2">
        <button onClick={() => setTab("permissions")} className={`px-4 py-2 rounded-lg text-sm ${tab === "permissions" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>الصلاحيات</button>
        <button onClick={() => setTab("logs")} className={`px-4 py-2 rounded-lg text-sm ${tab === "logs" ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>السجلات الأمنية</button>
      </div>

      {tab === "permissions" ? (
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
          <section className="xl:col-span-3 bg-slate-900 border border-slate-800 rounded-xl p-4">
            <h2 className="font-bold mb-3">الأدوار</h2>
            <div className="space-y-2">
              {roles.map((role) => (
                <button key={role.id} onClick={() => setSelectedRoleId(String(role.id))} className={`w-full text-right p-3 rounded-lg border ${String(role.id) === selectedRoleId ? "bg-emerald-600/10 border-emerald-500" : "bg-slate-800/50 border-slate-800 hover:border-slate-700"}`}>
                  <div className="font-medium">{roleLabels[role.role_name] || role.role_name}</div>
                  <div className="text-xs text-slate-500 mt-1">{role.permissions?.length || 0} صلاحية</div>
                </button>
              ))}
            </div>
          </section>

          <section className="xl:col-span-9 bg-slate-900 border border-slate-800 rounded-xl p-4">
            <div className="flex items-center justify-between mb-4">
              <div>
                <h2 className="font-bold">{selectedRole ? roleLabels[selectedRole.role_name] || selectedRole.role_name : "اختر دوراً"}</h2>
                <p className="text-xs text-slate-500 mt-1">أي تعديل هنا يطبق مباشرة على كل حسابات هذا الدور بعد الحفظ.</p>
              </div>
              <button onClick={savePermissions} disabled={!selectedRole || saving} className="px-4 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">
                {saving ? "جاري الحفظ..." : "حفظ الصلاحيات"}
              </button>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 max-h-[650px] overflow-y-auto pr-1">
              {Object.entries(permissionsByGroup).map(([group, groupPermissions]) => (
                <div key={group} className="bg-slate-950/40 border border-slate-800 rounded-xl p-3">
                  <h3 className="font-bold text-sm text-slate-300 mb-3">{group}</h3>
                  <div className="space-y-2">
                    {groupPermissions.map((permission) => {
                      const id = String(permission.id);
                      const checked = selectedPermissionIds.has(id);
                      return (
                        <label key={permission.id} className="flex items-start gap-3 p-2 rounded-lg hover:bg-slate-800/60 cursor-pointer">
                          <input type="checkbox" checked={checked} onChange={() => togglePermission(id)} className="mt-1 accent-emerald-500" />
                          <span>
                            <span className="block text-sm text-slate-200">{permission.permission_name}</span>
                            {permission.description && <span className="block text-xs text-slate-500 mt-0.5">{permission.description}</span>}
                          </span>
                        </label>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>
          </section>
        </div>
      ) : (
        <section className="bg-slate-900 border border-slate-800 rounded-xl p-4">
          <div className="flex flex-wrap gap-2 mb-4">
            <input value={logAction} onChange={(event) => setLogAction(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadLogs()} placeholder="بحث بالإجراء" className="flex-1 min-w-52 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <select value={logStatus} onChange={(event) => setLogStatus(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
              <option value="">كل الحالات</option>
              <option value="allowed">allowed</option>
              <option value="denied">denied</option>
              <option value="success">success</option>
              <option value="failed">failed</option>
            </select>
            <input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <button onClick={loadLogs} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-800 text-sm text-slate-500">
                  <th className="text-right p-3">المستخدم</th>
                  <th className="text-right p-3">الإجراء</th>
                  <th className="text-right p-3">IP</th>
                  <th className="text-right p-3">الحالة</th>
                  <th className="text-right p-3">التاريخ</th>
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id} className="border-b border-slate-800/50 text-sm">
                    <td className="p-3">
                      <div>{log.user?.full_name || "غير معروف"}</div>
                      <div className="text-xs text-slate-500">{log.user?.email || "-"}</div>
                    </td>
                    <td className="p-3 text-slate-300">{log.action}</td>
                    <td className="p-3 text-slate-400" dir="ltr">{log.ip_address || "-"}</td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded text-xs ${statusClasses[log.status] || "bg-slate-500/20 text-slate-400"}`}>{log.status}</span>
                    </td>
                    <td className="p-3 text-slate-400">{log.created_at ? new Date(log.created_at).toLocaleString("ar") : "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {logs.length === 0 && <p className="text-slate-500 text-sm text-center py-10">لا توجد سجلات مطابقة</p>}
        </section>
      )}
    </div>
  );
}
