import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department, StaffUser } from "../types";

const departmentName = (department: Department) =>
  department.dept_name || department.name || "-";
const accountName = (account: StaffUser) =>
  account.full_name || account.name || account.email || "-";
const normalize = (value: string) => value.trim().toLowerCase();

export default function DepartmentsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [departments, setDepartments] = useState<Department[]>([]);
  const [availableAccounts, setAvailableAccounts] = useState<StaffUser[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Department | null>(null);
  const [deleteConfirmation, setDeleteConfirmation] = useState("");

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editAccountId, setEditAccountId] = useState("");
  const [accountId, setAccountId] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadDepartments();
    loadAvailableAccounts();
  }, []);

  const loadDepartments = async () => {
    try {
      const response = await api.get<any>("/admin/departments?per_page=100");
      setDepartments(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadDepartments", error);
    }
  };

  const loadAvailableAccounts = async () => {
    try {
      const response = await api.get<{ accounts: StaffUser[] }>("/admin/departments/available-accounts");
      setAvailableAccounts(response.accounts || []);
    } catch (error) {
      console.error("loadAvailableAccounts", error);
    }
  };

  const handleCreate = async (event: React.FormEvent) => {
    event.preventDefault();
    if (departments.some((department) => normalize(departmentName(department)) === normalize(name))) {
      alert("اسم القسم مستخدم مسبقاً، يرجى اختيار اسم آخر.");
      return;
    }

    try {
      await api.post("/admin/departments", {
        dept_name: name,
        description,
        account_id: accountId || null,
      });
      setName("");
      setDescription("");
      setAccountId("");
      setShowForm(false);
      loadDepartments();
      loadAvailableAccounts();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const startEdit = (department: Department) => {
    setEditingId(department.id);
    setEditName(departmentName(department));
    setEditDescription(department.description || "");
    setEditAccountId(department.account?.id || "");
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditDescription("");
    setEditAccountId("");
  };

  const handleUpdate = async (id: string) => {
    if (
      departments.some(
        (department) =>
          String(department.id) !== String(id) &&
          normalize(departmentName(department)) === normalize(editName)
      )
    ) {
      alert("اسم القسم مستخدم مسبقاً، يرجى اختيار اسم آخر.");
      return;
    }

    try {
      await api.put(`/admin/departments/${id}`, {
        dept_name: editName,
        description: editDescription,
        account_id: editAccountId || null,
      });
      cancelEdit();
      loadDepartments();
      loadAvailableAccounts();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleToggle = async (department: Department) => {
    try {
      await api.put(`/admin/departments/${department.id}`, {
        is_active: department.is_active === false,
      });
      loadDepartments();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget || deleteConfirmation !== "DELETE") return;

    try {
      await api.delete(`/admin/departments/${deleteTarget.id}`, { confirm: true });
      alert("تم حذف القسم الفني وإزالته من النظام بنجاح.");
      setDeleteTarget(null);
      setDeleteConfirmation("");
      loadDepartments();
    } catch (error: any) {
      alert(error.message);
    }
  };

  if (isLoading) {
    return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;
  }

  return (
    <div className="space-y-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">الأقسام</h1>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-4 py-2 bg-emerald-600 rounded-lg text-sm"
        >
          {showForm ? "إلغاء" : "إضافة قسم"}
        </button>
      </div>

      {showForm && (
        <form
          onSubmit={handleCreate}
          className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3"
        >
          <input
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder="اسم القسم"
            className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
            required
          />
          <select
            value={accountId}
            onChange={(event) => setAccountId(event.target.value)}
            className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
          >
            <option value="">بدون حساب مرتبط</option>
            {availableAccounts.map((account) => (
              <option key={account.id} value={account.id}>
                {accountName(account)} - {account.email}
              </option>
            ))}
          </select>
          <textarea
            value={description}
            onChange={(event) => setDescription(event.target.value)}
            placeholder="الوصف"
            className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20"
          />
          <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
            إنشاء
          </button>
        </form>
      )}

      <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-800 text-sm text-slate-500">
                <th className="text-right p-3">الاسم</th>
                <th className="text-right p-3">الوصف</th>
                <th className="text-right p-3">الموظف المرتبط</th>
                <th className="text-right p-3">التصنيفات</th>
                <th className="text-right p-3">البلاغات</th>
                <th className="text-right p-3">الحالة</th>
                <th className="text-right p-3">إجراء</th>
              </tr>
            </thead>
            <tbody>
              {departments.map((department) => (
                <tr key={department.id} className="border-b border-slate-800/50 text-sm">
                  {editingId === department.id ? (
                    <>
                      <td className="p-3">
                        <input
                          value={editName}
                          onChange={(event) => setEditName(event.target.value)}
                          className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs"
                        />
                      </td>
                      <td className="p-3">
                        <input
                          value={editDescription}
                          onChange={(event) => setEditDescription(event.target.value)}
                          className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs"
                        />
                      </td>
                      <td className="p-3">
                        <select
                          value={editAccountId}
                          onChange={(event) => setEditAccountId(event.target.value)}
                          className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs"
                        >
                          <option value="">بدون حساب</option>
                          {department.account && (
                            <option value={department.account.id}>
                              {department.account.full_name || department.account.name || "-"}
                            </option>
                          )}
                          {availableAccounts.map((account) => (
                            <option key={account.id} value={account.id}>
                              {accountName(account)} - {account.email}
                            </option>
                          ))}
                        </select>
                      </td>
                      <td className="p-3 text-slate-500">{department.categories_count || 0}</td>
                      <td className="p-3 text-slate-500">{department.reports_count || 0}</td>
                      <td className="p-3 text-slate-500">
                        {department.is_active !== false ? "نشط" : "موقوف"}
                      </td>
                      <td className="p-3">
                        <div className="flex gap-1">
                          <button
                            onClick={() => handleUpdate(department.id)}
                            className="px-2 py-1 bg-emerald-600 rounded text-xs"
                          >
                            حفظ
                          </button>
                          <button
                            onClick={cancelEdit}
                            className="px-2 py-1 bg-slate-700 rounded text-xs"
                          >
                            إلغاء
                          </button>
                        </div>
                      </td>
                    </>
                  ) : (
                    <>
                      <td className="p-3 font-medium">{departmentName(department)}</td>
                      <td className="p-3 text-slate-400">{department.description || "-"}</td>
                      <td className="p-3 text-slate-400">
                        {department.account?.full_name || department.account?.name || "-"}
                      </td>
                      <td className="p-3">{department.categories_count || 0}</td>
                      <td className="p-3">{department.reports_count || 0}</td>
                      <td className="p-3">
                        <span
                          className={`px-2 py-0.5 rounded text-xs ${
                            department.is_active !== false
                              ? "bg-emerald-500/20 text-emerald-400"
                              : "bg-red-500/20 text-red-400"
                          }`}
                        >
                          {department.is_active !== false ? "نشط" : "موقوف"}
                        </span>
                      </td>
                      <td className="p-3">
                        <div className="flex flex-wrap gap-1">
                          <button
                            onClick={() => startEdit(department)}
                            className="px-2 py-1 bg-amber-600/20 text-amber-400 rounded text-xs"
                          >
                            تعديل
                          </button>
                          <button
                            onClick={() => handleToggle(department)}
                            className="px-2 py-1 bg-slate-700 rounded text-xs"
                          >
                            {department.is_active !== false ? "إيقاف" : "تفعيل"}
                          </button>
                          <button
                            onClick={() => {
                              setDeleteTarget(department);
                              setDeleteConfirmation("");
                            }}
                            className="px-2 py-1 bg-red-700/30 text-red-300 rounded text-xs"
                          >
                            حذف نهائي
                          </button>
                        </div>
                      </td>
                    </>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {deleteTarget && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4">
          <div className="w-full max-w-lg bg-slate-900 border border-red-900/60 rounded-xl p-5 space-y-4">
            <h2 className="text-lg font-bold text-red-300">تنبيه حرج جداً: حذف قسم فني</h2>
            <p className="text-sm text-slate-300 leading-7">
              هل أنت متأكد من رغبتك في حذف قسم{" "}
              <strong>{departmentName(deleteTarget)}</strong> نهائياً من النظام؟ هذا الإجراء
              سيمسح سجل القسم تماماً ولا يمكن التراجع عنه.
            </p>
            <div className="rounded-lg bg-red-500/10 border border-red-500/20 p-3 text-xs text-red-200 leading-6">
              إذا كان القسم مرتبطاً بموظفين أو تصنيفات بلاغات أو بلاغات محفوظة، سيمنع
              النظام الحذف لحماية ترابط البيانات.
            </div>
            <p className="text-xs text-slate-500">اكتب DELETE لتأكيد الحذف النهائي للقسم.</p>
            <input
              value={deleteConfirmation}
              onChange={(event) => setDeleteConfirmation(event.target.value)}
              className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm"
              dir="ltr"
            />
            <div className="flex justify-end gap-2">
              <button
                onClick={() => setDeleteTarget(null)}
                className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm"
              >
                إلغاء الأمر
              </button>
              <button
                onClick={handleDelete}
                disabled={deleteConfirmation !== "DELETE"}
                className="px-3 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-50 rounded-lg text-sm"
              >
                نعم، تأكيد الحذف النهائي للقسم
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
