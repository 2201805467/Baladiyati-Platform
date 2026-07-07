import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department, Role, StaffUser } from "../types";

const roleLabels: Record<string, string> = {
  admin: "أدمن",
  reception: "موظف استقبال",
  department: "موظف قسم",
  citizen: "مواطن",
};

const userName = (user: StaffUser) => user.full_name || user.name || "-";
const roleName = (user: StaffUser) => {
  const role = typeof user.role === "object" ? user.role.role_name : user.role || "-";
  return roleLabels[role] || role;
};
const rawRoleName = (user: StaffUser) => typeof user.role === "object" ? user.role.role_name : user.role || "";
const departmentName = (user: StaffUser) => user.department?.dept_name || user.department?.name || "-";
const isActive = (user: StaffUser) => Boolean(user.is_active ?? user.isActive);
const canDeleteUser = (user: StaffUser) => rawRoleName(user) !== "admin";
const canEditUser = (user: StaffUser) => rawRoleName(user) !== "citizen";

export default function UsersPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [staff, setStaff] = useState<StaffUser[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [statusFilter, setStatusFilter] = useState<"citizens" | "staff" | "active" | "inactive">("staff");
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [deactivateTarget, setDeactivateTarget] = useState<StaffUser | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<StaffUser | null>(null);
  const [deleteConfirmation, setDeleteConfirmation] = useState("");

  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [employeeNumber, setEmployeeNumber] = useState("");
  const [password, setPassword] = useState("");
  const [roleId, setRoleId] = useState("");
  const [departmentId, setDepartmentId] = useState("");

  const [editName, setEditName] = useState("");
  const [editEmail, setEditEmail] = useState("");
  const [editPhone, setEditPhone] = useState("");
  const [editEmployeeNumber, setEditEmployeeNumber] = useState("");
  const [editPassword, setEditPassword] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadStaff();
    loadRoles();
    loadDepartments();
  }, []);

  const selectedRole = roles.find((role) => String(role.id) === String(roleId));

  const filteredStaff = useMemo(() => {
    return staff.filter((staffUser) => {
      const role = rawRoleName(staffUser);
      if (statusFilter === "citizens") return role === "citizen";
      if (statusFilter === "staff") return role !== "citizen";
      if (statusFilter === "active") return isActive(staffUser);
      if (statusFilter === "inactive") return !isActive(staffUser);
      return true;
    });
  }, [staff, statusFilter]);

  const loadStaff = async () => {
    try {
      const response = await api.get<any>("/admin/users?per_page=100");
      setStaff(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadStaff", error);
    }
  };

  const loadRoles = async () => {
    try {
      const response = await api.get<{ roles: Role[] }>("/admin/roles");
      const staffRoles = response.roles.filter((role) => role.role_name !== "citizen");
      setRoles(staffRoles);
      setRoleId((current) => current || staffRoles.find((role) => role.role_name === "reception")?.id || staffRoles[0]?.id || "");
    } catch (error) {
      console.error("loadRoles", error);
    }
  };

  const loadDepartments = async () => {
    try {
      const response = await api.get<any>("/admin/departments?per_page=100");
      setDepartments(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadDepartments", error);
    }
  };

  const resetCreateForm = () => {
    setName("");
    setEmail("");
    setPhone("");
    setEmployeeNumber("");
    setPassword("");
    setDepartmentId("");
  };

  const handleCreate = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      await api.post("/admin/users", {
        full_name: name,
        email,
        phone,
        employee_number: employeeNumber,
        ...(password ? { password } : {}),
        role_id: roleId,
        dept_id: selectedRole?.role_name === "department" ? departmentId : null,
      });
      resetCreateForm();
      setShowForm(false);
      loadStaff();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const startEdit = (staffUser: StaffUser) => {
    setEditingId(staffUser.id);
    setEditName(userName(staffUser));
    setEditEmail(staffUser.email);
    setEditPhone(staffUser.phone || "");
    setEditEmployeeNumber(staffUser.employee_number || "");
    setEditPassword("");
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditEmail("");
    setEditPhone("");
    setEditEmployeeNumber("");
    setEditPassword("");
  };

  const handleUpdate = async (id: string) => {
    try {
      const response = await api.put<{ credentials_sent?: boolean; message?: string }>(`/admin/users/${id}`, {
        full_name: editName,
        email: editEmail,
        phone: editPhone,
        employee_number: editEmployeeNumber,
        ...(editPassword ? { password: editPassword } : {}),
      });
      cancelEdit();
      loadStaff();
      if (response.credentials_sent) {
        alert("تم تحديث بيانات الموظف وإرسالها إلى بريده الإلكتروني.");
      }
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleDeactivate = async () => {
    if (!deactivateTarget) return;

    try {
      await api.patch(`/admin/users/${deactivateTarget.id}/deactivate`);
      setDeactivateTarget(null);
      loadStaff();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget || deleteConfirmation !== "DELETE") return;
    try {
      const response = await api.delete<{
        deleted_open_reports?: number;
        preserved_closed_reports?: number;
      }>(`/admin/users/${deleteTarget.id}`, { confirm: true });
      setDeleteTarget(null);
      setDeleteConfirmation("");
      loadStaff();
      if (response.preserved_closed_reports || response.deleted_open_reports) {
        alert(
          `تم حذف الحساب. تم حذف ${response.deleted_open_reports || 0} بلاغ غير مغلق، وتم حفظ ${response.preserved_closed_reports || 0} بلاغ مغلق لأغراض الأداء.`
        );
      }
    } catch (error: any) {
      alert(error.message);
    }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">المستخدمون</h1>
          <p className="text-sm text-slate-500 mt-1">إدارة حسابات موظفي الاستقبال والأقسام والأدمن.</p>
        </div>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
          {showForm ? "إلغاء" : "إضافة موظف"}
        </button>
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as any)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
          <option value="citizens">المواطنون</option>
          <option value="staff">جميع الموظفين</option>
          <option value="active">النشطون</option>
          <option value="inactive">الموقوفون</option>
        </select>
        <span className="text-sm text-slate-500">المعروض: {filteredStaff.length}</span>
      </div>

      {showForm && (
        <form onSubmit={handleCreate} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="الاسم" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="البريد الإلكتروني" type="email" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="الهاتف" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={employeeNumber} onChange={(event) => setEmployeeNumber(event.target.value)} placeholder="الرقم الوظيفي" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={password} onChange={(event) => setPassword(event.target.value)} placeholder="كلمة المرور، اتركها فارغة للتوليد التلقائي" type="password" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <select value={roleId} onChange={(event) => { setRoleId(event.target.value); setDepartmentId(""); }} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
              {roles.map((role) => <option key={role.id} value={role.id}>{roleLabels[role.role_name] || role.role_name}</option>)}
            </select>
            {selectedRole?.role_name === "department" && (
              <select value={departmentId} onChange={(event) => setDepartmentId(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                <option value="">اختر القسم</option>
                {departments.map((department) => <option key={department.id} value={department.id}>{department.dept_name || department.name}</option>)}
              </select>
            )}
          </div>
          <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء حساب</button>
        </form>
      )}

      <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-800 text-sm text-slate-500">
                <th className="text-right p-3">الموظف</th>
                <th className="text-right p-3">الرقم الوظيفي</th>
                <th className="text-right p-3">الدور</th>
                <th className="text-right p-3">القسم</th>
                <th className="text-right p-3">الهاتف</th>
                <th className="text-right p-3">الحالة</th>
                <th className="text-right p-3">إجراء</th>
              </tr>
            </thead>
            <tbody>
              {filteredStaff.map((staffUser) => {
                const rawRole = rawRoleName(staffUser);
                return (
                  <tr key={staffUser.id} className="border-b border-slate-800/50 text-sm">
                    {editingId === staffUser.id ? (
                      <>
                        <td className="p-3">
                          <div className="space-y-2">
                            <input value={editName} onChange={(event) => setEditName(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" />
                            <input value={editEmail} onChange={(event) => setEditEmail(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" />
                          </div>
                        </td>
                        <td className="p-3"><input value={editEmployeeNumber} onChange={(event) => setEditEmployeeNumber(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                        <td className="p-3 text-slate-400">{roleName(staffUser)}</td>
                        <td className="p-3 text-slate-400">{departmentName(staffUser)}</td>
                        <td className="p-3"><input value={editPhone} onChange={(event) => setEditPhone(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                        <td className="p-3">
                          <input value={editPassword} onChange={(event) => setEditPassword(event.target.value)} placeholder="كلمة مرور جديدة" type="password" className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" />
                        </td>
                        <td className="p-3">
                          <div className="flex gap-1">
                            <button onClick={() => handleUpdate(staffUser.id)} className="px-2 py-1 bg-emerald-600 rounded text-xs">حفظ</button>
                            <button onClick={cancelEdit} className="px-2 py-1 bg-slate-700 rounded text-xs">إلغاء</button>
                          </div>
                        </td>
                      </>
                    ) : (
                      <>
                        <td className="p-3">
                          <div className="font-medium">{userName(staffUser)}</div>
                          <div className="text-xs text-slate-500">{staffUser.email}</div>
                        </td>
                        <td className="p-3">
                          <span className="px-2 py-1 bg-slate-800 rounded text-xs text-slate-300">{staffUser.employee_number || "-"}</span>
                        </td>
                        <td className="p-3">
                          <span className={`px-2 py-1 rounded text-xs ${rawRole === "admin" ? "bg-purple-500/20 text-purple-300" : rawRole === "department" ? "bg-blue-500/20 text-blue-300" : "bg-emerald-500/20 text-emerald-300"}`}>
                            {roleName(staffUser)}
                          </span>
                        </td>
                        <td className="p-3 text-slate-400">{departmentName(staffUser)}</td>
                        <td className="p-3 text-slate-400">{staffUser.phone || "-"}</td>
                        <td className="p-3">
                          <span className={`px-2 py-0.5 rounded text-xs ${isActive(staffUser) ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>
                            {isActive(staffUser) ? "نشط" : "موقوف"}
                          </span>
                        </td>
                        <td className="p-3">
                          <div className="flex flex-wrap gap-1">
                            {canEditUser(staffUser) ? (
                              <button onClick={() => startEdit(staffUser)} className="px-2 py-1 bg-amber-600/20 text-amber-400 rounded text-xs">تعديل</button>
                            ) : (
                              <span className="px-2 py-1 bg-slate-800 text-slate-500 rounded text-xs">لا يمكن تعديل المواطن</span>
                            )}
                            {isActive(staffUser) && (
                              <button onClick={() => setDeactivateTarget(staffUser)} className="px-2 py-1 bg-red-600/20 text-red-400 rounded text-xs">إيقاف</button>
                            )}
                            {canDeleteUser(staffUser) ? (
                              <button onClick={() => { setDeleteTarget(staffUser); setDeleteConfirmation(""); }} className="px-2 py-1 bg-red-700/30 text-red-300 rounded text-xs">حذف نهائي</button>
                            ) : (
                              <span className="px-2 py-1 bg-slate-800 text-slate-500 rounded text-xs">لا يمكن حذف الأدمن</span>
                            )}
                          </div>
                        </td>
                      </>
                    )}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {deactivateTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <h2 className="text-lg font-bold text-amber-300">تأكيد إيقاف الحساب</h2>
            <p className="text-sm text-slate-300">
              سيتم إيقاف حساب <strong>{userName(deactivateTarget)}</strong>. لن يستطيع هذا المستخدم تسجيل الدخول، وسيتم إنهاء جلساته الحالية.
            </p>
            <div className="rounded-lg bg-amber-500/10 border border-amber-500/20 p-3 text-xs text-amber-200">
              هذا الإجراء لا يحذف بيانات المستخدم، ويمكنك لاحقاً إعادة تفعيل الحساب من قاعدة البيانات أو بإضافة واجهة تفعيل.
            </div>
            <div className="flex justify-end gap-2">
              <button onClick={() => setDeactivateTarget(null)} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">إلغاء</button>
              <button onClick={handleDeactivate} className="px-3 py-2 bg-amber-600 hover:bg-amber-500 rounded-lg text-sm">تأكيد الإيقاف</button>
            </div>
          </div>
        </div>
      )}

      {deleteTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="w-full max-w-md bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <h2 className="text-lg font-bold text-red-300">حذف الحساب نهائياً</h2>
            <p className="text-sm text-slate-300">
              سيتم حذف حساب <strong>{userName(deleteTarget)}</strong> نهائياً. هذا الإجراء لا يمكن التراجع عنه.
            </p>
            <p className="text-xs text-slate-500">اكتب DELETE لتأكيد الحذف.</p>
            <input value={deleteConfirmation} onChange={(event) => setDeleteConfirmation(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" dir="ltr" />
            <div className="flex justify-end gap-2">
              <button onClick={() => setDeleteTarget(null)} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">إلغاء</button>
              <button onClick={handleDelete} disabled={deleteConfirmation !== "DELETE"} className="px-3 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-50 rounded-lg text-sm">حذف نهائي</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
