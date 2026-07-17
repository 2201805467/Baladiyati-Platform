import { useEffect, useMemo, useState } from "react";
import { DivIcon, LatLngExpression } from "leaflet";
import { MapContainer, Marker, Popup, TileLayer } from "react-leaflet";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import "leaflet/dist/leaflet.css";

interface ReportImage {
  id: string;
  image_url: string;
  image_type?: string;
}

interface ReportLog {
  id: string;
  action: string;
  new_status?: string | null;
  note?: string | null;
}

interface Report {
  id: string;
  report_number?: string;
  title?: string;
  description?: string | null;
  latitude?: string | number | null;
  longitude?: string | number | null;
  status: string;
  sla_status?: string | null;
  category?: { category_name?: string } | null;
  department?: { dept_name?: string; name?: string } | null;
  citizen?: { full_name?: string; name?: string; phone?: string } | null;
  images?: ReportImage[];
  logs?: ReportLog[];
}

interface Facility {
  id: string;
  name: string;
  facility_type?: string;
  type?: string;
  latitude?: string | number | null;
  longitude?: string | number | null;
  services?: string | null;
}

const statusColors: Record<string, string> = {
  new: "#3b82f6",
  under_review: "#f59e0b",
  transferred: "#8b5cf6",
  in_progress: "#06b6d4",
  pending: "#f97316",
  closed: "#10b981",
  rejected: "#ef4444",
};

const statusLabels: Record<string, string> = {
  new: "جديد",
  under_review: "قيد المراجعة",
  transferred: "محول",
  in_progress: "قيد التنفيذ",
  pending: "معلق",
  closed: "مغلق",
  rejected: "مرفوض",
};

const makeReportIcon = (color: string) => new DivIcon({
  className: "",
  html: `<div style="width:24px;height:24px;background:${color};border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,0.45)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const facilityIcon = new DivIcon({
  className: "",
  html: `<div style="width:18px;height:18px;background:#f97316;border:2px solid white;transform:rotate(45deg);box-shadow:0 2px 6px rgba(0,0,0,0.35)"></div>`,
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

const numberValue = (value?: string | number | null) => {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const personName = (person?: { full_name?: string; name?: string } | null) => person?.full_name || person?.name || "-";
const departmentName = (department?: { dept_name?: string; name?: string } | null) => department?.dept_name || department?.name || "-";
const assetUrl = (url?: string | null) => {
  if (!url) return "";
  if (url.startsWith("http")) return url;
  const apiOrigin = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");
  return `${apiOrigin}${url.startsWith("/") ? url : `/${url}`}`;
};

export default function ReportsMapPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<Report[]>([]);
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [selected, setSelected] = useState<Report | null>(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [search, setSearch] = useState("");
  const [loadingDetails, setLoadingDetails] = useState(false);

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    if (user?.role) loadReports();
  }, [user?.role, statusFilter]);

  useEffect(() => {
    if (user?.role === "admin") loadFacilities();
  }, [user?.role]);

  const reportsEndpoint = () => {
    if (user?.role === "admin") return "/admin/reports-map";
    if (user?.role === "department") return "/department/reports";
    if (user?.role === "reception") return "/reception/reports";
    return null;
  };

  const reportDetailsEndpoint = (id: string) => {
    if (user?.role === "admin") return `/admin/reports-map/${id}`;
    if (user?.role === "department") return `/department/reports/${id}`;
    if (user?.role === "reception") return `/reception/reports/${id}`;
    return null;
  };

  const loadReports = async () => {
    const endpoint = reportsEndpoint();
    if (!endpoint) return;

    try {
      const params = new URLSearchParams();
      params.set("per_page", "200");
      params.set("status", statusFilter || "open");
      if (search) params.set("search", search);
      const response = await api.get<any>(`${endpoint}?${params.toString()}`);
      setReports(response.data || []);
    } catch (error) {
      console.error("loadReports", error);
    }
  };

  const loadFacilities = async () => {
    try {
      const response = await api.get<any>("/admin/facilities?per_page=200&is_active=1");
      setFacilities(response.data || []);
    } catch (error) {
      console.error("loadFacilities", error);
    }
  };

  const openReport = async (id: string) => {
    const endpoint = reportDetailsEndpoint(id);
    if (!endpoint) return;
    setLoadingDetails(true);
    try {
      const response = await api.get<{ report: Report }>(endpoint);
      setSelected(response.report);
      if (user?.role === "reception") loadReports();
    } catch (error: any) {
      alert(error.message);
    } finally {
      setLoadingDetails(false);
    }
  };

  const reportPoints = useMemo(() => reports
    .map((report) => ({ report, lat: numberValue(report.latitude), lng: numberValue(report.longitude) }))
    .filter((item): item is { report: Report; lat: number; lng: number } => item.lat !== null && item.lng !== null), [reports]);

  const facilityPoints = useMemo(() => facilities
    .map((facility) => ({ facility, lat: numberValue(facility.latitude), lng: numberValue(facility.longitude) }))
    .filter((item): item is { facility: Facility; lat: number; lng: number } => item.lat !== null && item.lng !== null), [facilities]);

  const center: LatLngExpression = reportPoints[0]
    ? [reportPoints[0].lat, reportPoints[0].lng]
    : [32.8872, 13.1913];

  const firstImage = selected?.images?.[0];

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">خريطة البلاغات</h1>
          <p className="text-sm text-slate-500 mt-1">البلاغات الظاهرة حسب صلاحية الحساب الحالي</p>
        </div>
        <button onClick={loadReports} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="flex flex-wrap gap-2">
        <input value={search} onChange={(event) => setSearch(event.target.value)} onKeyDown={(event) => event.key === "Enter" && loadReports()} placeholder="بحث برقم البلاغ أو العنوان" className="flex-1 min-w-56 px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
          <option value="">كل الحالات المتاحة</option>
          <option value="new">جديد</option>
          <option value="under_review">قيد المراجعة</option>
          <option value="transferred">محول</option>
          <option value="in_progress">قيد التنفيذ</option>
          <option value="pending">معلق</option>
        </select>
        <button onClick={loadReports} className="px-3 py-2 bg-emerald-600 rounded-lg text-sm">بحث</button>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-12 gap-6">
        <section className="xl:col-span-8 bg-slate-900 rounded-xl overflow-hidden border border-slate-800" style={{ height: "calc(100vh - 245px)", minHeight: 520 }}>
          <MapContainer key={`${center[0]}-${center[1]}`} center={center} zoom={13} className="w-full h-full" scrollWheelZoom>
            <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />

            {reportPoints.map(({ report, lat, lng }) => {
              const color = statusColors[report.status] || "#64748b";
              return (
                <Marker key={report.id} position={[lat, lng]} icon={makeReportIcon(color)}>
                  <Popup>
                    <div dir="rtl" style={{ minWidth: 220 }}>
                      <strong>{report.report_number || `#${report.id}`}</strong>
                      <p style={{ margin: "6px 0", color: "#475569" }}>{report.title || report.description || "بلاغ بدون عنوان"}</p>
                      <p style={{ margin: "4px 0" }}><span style={{ color }}>●</span> {statusLabels[report.status] || report.status}</p>
                      <p style={{ margin: "4px 0", color: "#64748b" }}>النوع: {report.category?.category_name || "-"}</p>
                      <button onClick={() => openReport(report.id)} style={{ marginTop: 8, width: "100%", padding: "7px 10px", background: "#059669", color: "white", border: 0, borderRadius: 8, cursor: "pointer" }}>
                        عرض التفاصيل
                      </button>
                    </div>
                  </Popup>
                </Marker>
              );
            })}

            {facilityPoints.map(({ facility, lat, lng }) => (
              <Marker key={`facility-${facility.id}`} position={[lat, lng]} icon={facilityIcon}>
                <Popup>
                  <div dir="rtl">
                    <strong>{facility.name}</strong>
                    <p style={{ margin: "4px 0", color: "#64748b" }}>{facility.facility_type || facility.type || "مرفق عام"}</p>
                    {facility.services && <p style={{ margin: "4px 0", color: "#64748b" }}>{facility.services}</p>}
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>
        </section>

        <aside className="xl:col-span-4 bg-slate-900 rounded-xl border border-slate-800 p-4">
          {!selected ? (
            <div className="h-full flex items-center justify-center text-center text-slate-500 text-sm">
              اختر علامة من الخريطة ثم اضغط عرض التفاصيل
            </div>
          ) : (
            <div className="space-y-4">
              {loadingDetails && <p className="text-xs text-emerald-400">جاري تحديث التفاصيل...</p>}
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-bold">{selected.report_number || `#${selected.id}`}</h2>
                  <p className="text-sm text-slate-400">{selected.title || "بلاغ بدون عنوان"}</p>
                </div>
                <span className="text-xs px-2 py-1 rounded" style={{ backgroundColor: `${statusColors[selected.status] || "#64748b"}33`, color: statusColors[selected.status] || "#cbd5e1" }}>
                  {statusLabels[selected.status] || selected.status}
                </span>
              </div>

              {firstImage && <img src={assetUrl(firstImage.image_url)} alt="صورة البلاغ" className="w-full h-52 object-cover rounded-lg border border-slate-800" />}

              <div className="text-sm text-slate-300 space-y-1">
                <p><strong>المواطن:</strong> {personName(selected.citizen)} {selected.citizen?.phone ? `- ${selected.citizen.phone}` : ""}</p>
                <p><strong>التصنيف:</strong> {selected.category?.category_name || "-"}</p>
                <p><strong>القسم:</strong> {departmentName(selected.department)}</p>
                <p><strong>الموقع:</strong> {selected.latitude || "-"}, {selected.longitude || "-"}</p>
                {selected.sla_status && <p><strong>SLA:</strong> {selected.sla_status}</p>}
              </div>

              <p className="text-sm leading-7 text-slate-200">{selected.description || "-"}</p>

              <div className="border-t border-slate-800 pt-4">
                <h3 className="font-bold mb-2">آخر الإجراءات</h3>
                <div className="space-y-2 max-h-44 overflow-y-auto">
                  {(selected.logs || []).slice(0, 8).map((log) => (
                    <div key={log.id} className="text-xs bg-slate-800/60 rounded-lg p-2">
                      <div className="text-slate-300">{log.action} {log.new_status ? `- ${log.new_status}` : ""}</div>
                      {log.note && <div className="text-slate-500 mt-1">{log.note}</div>}
                    </div>
                  ))}
                  {(!selected.logs || selected.logs.length === 0) && <p className="text-xs text-slate-500">لا يوجد سجل بعد</p>}
                </div>
              </div>
            </div>
          )}
        </aside>
      </div>

      <div className="flex flex-wrap gap-4 text-sm text-slate-400">
        {Object.entries(statusLabels).filter(([status]) => status !== "rejected").map(([status, label]) => (
          <span key={status} className="flex items-center gap-1.5">
            <span className="w-3 h-3 rounded-full" style={{ backgroundColor: statusColors[status] }} />
            {label}
          </span>
        ))}
        {user?.role === "admin" && <span className="flex items-center gap-1.5"><span className="w-3 h-3 bg-orange-500 rotate-45" /> المرافق العامة</span>}
      </div>
    </div>
  );
}
