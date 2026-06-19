import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department, Role, StaffUser } from "../types";

const userName = (user: StaffUser) => user.full_name || user.name || "-";
const roleName = (user: StaffUser) => typeof user.role === "object" ? user.role.role_name : user.role || "-";
const departmentName = (user: StaffUser) => user.department?.dept_name || user.department?.name || "-";
const isActive = (user: StaffUser) => Boolean(user.is_active ?? user.isActive);

export default function UsersPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [staff, setStaff] = useState<StaffUser[]>([]);
  const [roles, setRoles] = useState<Role[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "inactive">("all");
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

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
  const [editPassword, setEditPassword] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadStaff();
    loadRoles();
    loadDepartments();
  }, []);

  const loadStaff = async () => {
    try {
      const response = await api.get<any>("/admin/users");
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
      const response = await api.get<any>("/admin/departments");
      setDepartments(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadDepartments", error);
    }
  };

  const selectedRole = roles.find((role) => String(role.id) === String(roleId));

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
    setEditPassword("");
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditEmail("");
    setEditPhone("");
    setEditPassword("");
  };

  const handleUpdate = async (id: string) => {
    try {
      await api.put(`/admin/users/${id}`, {
        full_name: editName,
        email: editEmail,
        phone: editPhone,
        ...(editPassword ? { password: editPassword } : {}),
      });
      cancelEdit();
      loadStaff();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleDeactivate = async (id: string) => {
    try {
      await api.patch(`/admin/users/${id}/deactivate`);
      loadStaff();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const filteredStaff = staff.filter((staffUser) => {
    if (statusFilter === "active") return isActive(staffUser);
    if (statusFilter === "inactive") return !isActive(staffUser);
    return true;
  });

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">المستخدمون</h1>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
          {showForm ? "إلغاء" : "إضافة موظف"}
        </button>
      </div>

      <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value as any)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm text-white">
        <option value="all">جميع الموظفين</option>
        <option value="active">النشطون</option>
        <option value="inactive">الموقوفون</option>
      </select>

      {showForm && (
        <form onSubmit={handleCreate} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <input value={name} onChange={(event) => setName(event.target.value)} placeholder="الاسم" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="البريد الإلكتروني" type="email" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={phone} onChange={(event) => setPhone(event.target.value)} placeholder="الهاتف" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={employeeNumber} onChange={(event) => setEmployeeNumber(event.target.value)} placeholder="الرقم الوظيفي" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input value={password} onChange={(event) => setPassword(event.target.value)} placeholder="كلمة المرور، اتركها فارغة للتوليد التلقائي" type="password" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <select value={roleId} onChange={(event) => setRoleId(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
              {roles.map((role) => <option key={role.id} value={role.id}>{role.role_name}</option>)}
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
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-800 text-sm text-slate-500">
              <th className="text-right p-3">الاسم</th>
              <th className="text-right p-3">البريد</th>
              <th className="text-right p-3">الهاتف</th>
              <th className="text-right p-3">الدور</th>
              <th className="text-right p-3">القسم</th>
              <th className="text-right p-3">الحالة</th>
              <th className="text-right p-3">إجراء</th>
            </tr>
          </thead>
          <tbody>
            {filteredStaff.map((staffUser) => (
              <tr key={staffUser.id} className="border-b border-slate-800/50 text-sm">
                {editingId === staffUser.id ? (
                  <>
                    <td className="p-3"><input value={editName} onChange={(event) => setEditName(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3"><input value={editEmail} onChange={(event) => setEditEmail(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3"><input value={editPhone} onChange={(event) => setEditPhone(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3 text-slate-400">{roleName(staffUser)}</td>
                    <td className="p-3 text-slate-400">{departmentName(staffUser)}</td>
                    <td className="p-3">
                      <input value={editPassword} onChange={(event) => setEditPassword(event.target.value)} placeholder="كلمة مرور جديدة" type="password" className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" />
                    </td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => handleUpdate(staffUser.id)} className="px-2 py-1 bg-emerald-600 rounded text-xs">حفظ</button>
                      <button onClick={cancelEdit} className="px-2 py-1 bg-slate-700 rounded text-xs">إلغاء</button>
                    </td>
                  </>
                ) : (
                  <>
                    <td className="p-3">{userName(staffUser)}</td>
                    <td className="p-3 text-slate-400">{staffUser.email}</td>
                    <td className="p-3 text-slate-400">{staffUser.phone || "-"}</td>
                    <td className="p-3">{roleName(staffUser)}</td>
                    <td className="p-3 text-slate-400">{departmentName(staffUser)}</td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded text-xs ${isActive(staffUser) ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>
                        {isActive(staffUser) ? "نشط" : "موقوف"}
                      </span>
                    </td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => startEdit(staffUser)} className="px-2 py-1 bg-amber-600/20 text-amber-400 rounded text-xs">تعديل</button>
                      {isActive(staffUser) && (
                        <button onClick={() => handleDeactivate(staffUser.id)} className="px-2 py-1 bg-red-600/20 text-red-400 rounded text-xs">إيقاف</button>
                      )}
                    </td>
                  </>
                )}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
