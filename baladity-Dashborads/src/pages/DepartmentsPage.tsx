import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department } from "../types";

export default function DepartmentsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [departments, setDepartments] = useState<Department[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadDepartments();
  }, []);

  const loadDepartments = async () => {
    try {
      const response = await api.get<any>("/admin/departments");
      setDepartments(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadDepartments", error);
    }
  };

  const handleCreate = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      await api.post("/admin/departments", {
        dept_name: name,
        description,
      });
      setName("");
      setDescription("");
      setShowForm(false);
      loadDepartments();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const startEdit = (department: Department) => {
    setEditingId(department.id);
    setEditName(department.dept_name || department.name || "");
    setEditDescription(department.description || "");
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditDescription("");
  };

  const handleUpdate = async (id: string) => {
    try {
      await api.put(`/admin/departments/${id}`, {
        dept_name: editName,
        description: editDescription,
      });
      cancelEdit();
      loadDepartments();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleToggle = async (department: Department) => {
    try {
      await api.put(`/admin/departments/${department.id}`, { is_active: !department.is_active });
      loadDepartments();
    } catch (error: any) {
      alert(error.message);
    }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">الأقسام</h1>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
          {showForm ? "إلغاء" : "إضافة قسم"}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleCreate} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
          <input value={name} onChange={(event) => setName(event.target.value)} placeholder="اسم القسم" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
          <textarea value={description} onChange={(event) => setDescription(event.target.value)} placeholder="الوصف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
          <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء</button>
        </form>
      )}

      <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
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
                    <td className="p-3"><input value={editName} onChange={(event) => setEditName(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3" colSpan={5}><input value={editDescription} onChange={(event) => setEditDescription(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => handleUpdate(department.id)} className="px-2 py-1 bg-emerald-600 rounded text-xs">حفظ</button>
                      <button onClick={cancelEdit} className="px-2 py-1 bg-slate-700 rounded text-xs">إلغاء</button>
                    </td>
                  </>
                ) : (
                  <>
                    <td className="p-3 font-medium">{department.dept_name || department.name}</td>
                    <td className="p-3 text-slate-400">{department.description || "-"}</td>
                    <td className="p-3 text-slate-400">{department.account?.full_name || department.account?.name || "-"}</td>
                    <td className="p-3">{department.categories_count || 0}</td>
                    <td className="p-3">{department.reports_count || 0}</td>
                    <td className="p-3"><span className={`px-2 py-0.5 rounded text-xs ${department.is_active !== false ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>{department.is_active !== false ? "نشط" : "موقوف"}</span></td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => startEdit(department)} className="px-2 py-1 bg-amber-600/20 text-amber-400 rounded text-xs">تعديل</button>
                      <button onClick={() => handleToggle(department)} className="px-2 py-1 bg-slate-700 rounded text-xs">{department.is_active !== false ? "إيقاف" : "تفعيل"}</button>
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
