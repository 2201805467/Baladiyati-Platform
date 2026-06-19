import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

interface ReportsAnalytics {
  total_reports: number;
  open_reports: number;
  closed_reports: number;
  average_rating: number;
  by_status: { status: string; total: number }[];
  by_category: { category_name: string; total: number }[];
}

interface DepartmentAnalytics {
  id: string;
  dept_name: string;
  reports_count: number;
  closed_reports_count: number;
  open_reports_count: number;
  completion_rate: number;
}

export default function AnalyticsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<ReportsAnalytics | null>(null);
  const [departments, setDepartments] = useState<DepartmentAnalytics[]>([]);

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    api.get<ReportsAnalytics>("/admin/analytics/reports").then(setReports).catch((error) => console.error("reports analytics", error));
    api.get<{ departments: DepartmentAnalytics[] }>("/admin/analytics/departments").then((response) => setDepartments(response.departments || [])).catch((error) => console.error("department analytics", error));
  }, []);

  if (isLoading || !reports) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  const statusTotal = reports.by_status.reduce((sum, item) => sum + item.total, 0);

  return (
    <div className="space-y-6" dir="rtl">
      <h1 className="text-2xl font-bold text-emerald-400">الإحصائيات والتقارير</h1>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="text-3xl font-bold text-emerald-400">{reports.total_reports}</div>
          <div className="text-sm text-slate-500">إجمالي البلاغات</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="text-3xl font-bold text-blue-400">{reports.open_reports}</div>
          <div className="text-sm text-slate-500">بلاغات مفتوحة</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="text-3xl font-bold text-emerald-400">{reports.closed_reports}</div>
          <div className="text-sm text-slate-500">بلاغات مغلقة</div>
        </div>
        <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
          <div className="text-3xl font-bold text-amber-400">{reports.average_rating.toFixed(1)}</div>
          <div className="text-sm text-slate-500">متوسط التقييم</div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-slate-900 rounded-xl p-6 border border-slate-800">
          <h2 className="font-bold mb-4">البلاغات حسب الحالة</h2>
          <div className="space-y-3">
            {reports.by_status.map((item) => (
              <div key={item.status}>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-slate-400">{item.status}</span>
                  <span>{item.total}</span>
                </div>
                <div className="w-full bg-slate-800 rounded-full h-2.5">
                  <div className="h-2.5 rounded-full bg-emerald-500" style={{ width: `${statusTotal > 0 ? (item.total / statusTotal) * 100 : 0}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-slate-900 rounded-xl p-6 border border-slate-800">
          <h2 className="font-bold mb-4">أفضل الأقسام حسب الإنجاز</h2>
          <div className="space-y-3">
            {departments.map((department) => (
              <div key={department.id}>
                <div className="flex justify-between text-sm mb-1">
                  <span className="text-slate-400">{department.dept_name}</span>
                  <span>{department.completion_rate}%</span>
                </div>
                <div className="w-full bg-slate-800 rounded-full h-2.5">
                  <div className="h-2.5 rounded-full bg-blue-500" style={{ width: `${department.completion_rate}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
