import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import type { Department } from "../types";

interface Category {
  id: string;
  category_name: string;
  description?: string | null;
  dept_id: string;
  is_active?: boolean;
  reports_count?: number;
  department?: Department | null;
}

export default function CategoriesPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [categories, setCategories] = useState<Category[]>([]);
  const [departments, setDepartments] = useState<Department[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [departmentId, setDepartmentId] = useState("");
  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editDepartmentId, setEditDepartmentId] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    loadCategories();
    loadDepartments();
  }, []);

  const loadCategories = async () => {
    try {
      const response = await api.get<any>("/admin/categories");
      setCategories(Array.isArray(response) ? response : response.data || []);
    } catch (error) {
      console.error("loadCategories", error);
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

  const handleCreate = async (event: React.FormEvent) => {
    event.preventDefault();
    try {
      await api.post("/admin/categories", {
        category_name: name,
        description,
        dept_id: departmentId,
      });
      setName("");
      setDescription("");
      setDepartmentId("");
      setShowForm(false);
      loadCategories();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const startEdit = (category: Category) => {
    setEditingId(category.id);
    setEditName(category.category_name);
    setEditDescription(category.description || "");
    setEditDepartmentId(String(category.dept_id || category.department?.id || ""));
  };

  const cancelEdit = () => {
    setEditingId(null);
    setEditName("");
    setEditDescription("");
    setEditDepartmentId("");
  };

  const handleUpdate = async (id: string) => {
    try {
      await api.put(`/admin/categories/${id}`, {
        category_name: editName,
        description: editDescription,
        dept_id: editDepartmentId,
      });
      cancelEdit();
      loadCategories();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleToggle = async (category: Category) => {
    try {
      await api.put(`/admin/categories/${category.id}`, { is_active: !category.is_active });
      loadCategories();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleDelete = async (category: Category) => {
    if (!confirm(`هل تريد حذف التصنيف "${category.category_name}" نهائياً؟`)) return;

    try {
      await api.delete(`/admin/categories/${category.id}`, { confirm: true });
      loadCategories();
    } catch (error: any) {
      alert(error.message);
    }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">التصنيفات</h1>
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
          {showForm ? "إلغاء" : "إضافة تصنيف"}
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleCreate} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
          <input value={name} onChange={(event) => setName(event.target.value)} placeholder="اسم التصنيف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
          <textarea value={description} onChange={(event) => setDescription(event.target.value)} placeholder="الوصف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
          <select value={departmentId} onChange={(event) => setDepartmentId(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
            <option value="">اختر القسم المسؤول</option>
            {departments.map((department) => <option key={department.id} value={department.id}>{department.dept_name || department.name}</option>)}
          </select>
          <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء</button>
        </form>
      )}

      <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-800 text-sm text-slate-500">
              <th className="text-right p-3">الاسم</th>
              <th className="text-right p-3">القسم</th>
              <th className="text-right p-3">البلاغات</th>
              <th className="text-right p-3">الحالة</th>
              <th className="text-right p-3">إجراء</th>
            </tr>
          </thead>
          <tbody>
            {categories.map((category) => (
              <tr key={category.id} className="border-b border-slate-800/50 text-sm">
                {editingId === category.id ? (
                  <>
                    <td className="p-3"><input value={editName} onChange={(event) => setEditName(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3">
                      <select value={editDepartmentId} onChange={(event) => setEditDepartmentId(event.target.value)} className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs">
                        {departments.map((department) => <option key={department.id} value={department.id}>{department.dept_name || department.name}</option>)}
                      </select>
                    </td>
                    <td className="p-3" colSpan={2}><input value={editDescription} onChange={(event) => setEditDescription(event.target.value)} placeholder="الوصف" className="w-full px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs" /></td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => handleUpdate(category.id)} className="px-2 py-1 bg-emerald-600 rounded text-xs">حفظ</button>
                      <button onClick={cancelEdit} className="px-2 py-1 bg-slate-700 rounded text-xs">إلغاء</button>
                    </td>
                  </>
                ) : (
                  <>
                    <td className="p-3 font-medium">{category.category_name}</td>
                    <td className="p-3 text-slate-400">{category.department?.dept_name || category.department?.name || "-"}</td>
                    <td className="p-3">{category.reports_count || 0}</td>
                    <td className="p-3"><span className={`px-2 py-0.5 rounded text-xs ${category.is_active !== false ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>{category.is_active !== false ? "نشط" : "موقوف"}</span></td>
                    <td className="p-3 flex gap-1">
                      <button onClick={() => startEdit(category)} className="px-2 py-1 bg-amber-600/20 text-amber-400 rounded text-xs">تعديل</button>
                      <button onClick={() => handleToggle(category)} className="px-2 py-1 bg-slate-700 rounded text-xs">{category.is_active !== false ? "إيقاف" : "تفعيل"}</button>
                      <button onClick={() => handleDelete(category)} disabled={(category.reports_count || 0) > 0} className="px-2 py-1 bg-red-700/30 text-red-300 disabled:opacity-40 rounded text-xs">حذف</button>
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
