import { useState, useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import { Icon, DivIcon, LatLngExpression } from "leaflet";
import { useAuth } from "../lib/auth";
import { api } from "../lib/api-client";
import { useNavigate } from "react-router-dom";
import type { Report, Facility } from "../types";
import "leaflet/dist/leaflet.css";

const reportColors: Record<string, string> = { NEW: "#3b82f6", ASSIGNED: "#f59e0b", IN_PROGRESS: "#a855f7", RESOLVED: "#10b981", REJECTED: "#ef4444" };

function makeReportIcon(color: string) {
  return new DivIcon({
    className: "",
    html: `<div style="width:24px;height:24px;background:${color};border:3px solid white;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,0.4)"></div>`,
    iconSize: [24, 24],
    iconAnchor: [12, 12],
  });
}

const facilityIcon = new DivIcon({
  className: "",
  html: `<div style="width:20px;height:20px;background:#f97316;clip-path:polygon(50% 0%, 0% 100%, 100% 100%);transform:rotate(0deg);box-shadow:0 2px 6px rgba(0,0,0,0.4)"></div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
});

export default function ReportsMapPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [reports, setReports] = useState<Report[]>([]);
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [center] = useState<LatLngExpression>([32.8872, 13.1913]);

  useEffect(() => { if (!isLoading && !user) navigate("/login"); }, [user, isLoading, navigate]);
  useEffect(() => {
    const reportsPath = user?.role === "department" ? "/department/reports?per_page=200" : user?.role === "reception" ? "/reception/reports?per_page=200" : null;
    if (reportsPath) {
      api.get<any>(reportsPath).then(r => setReports(Array.isArray(r) ? r : (r.data || []))).catch(e => console.error("loadReports", e));
    }
    api.get<any>("/admin/facilities").then(r => setFacilities(Array.isArray(r) ? r : (r.data || []))).catch(e => console.error("loadFacilities", e));
  }, [user?.role]);

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-emerald-400">خريطة البلاغات</h1>
      <div className="bg-slate-900 rounded-xl overflow-hidden border border-slate-800" style={{ height: "calc(100vh - 200px)" }}>
        <MapContainer center={center} zoom={13} className="w-full h-full" scrollWheelZoom={true}>
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {reports.filter(r => r.location?.lat && r.location?.lng).map(r => (
            <Marker key={r.id} position={[r.location!.lat, r.location!.lng]} icon={makeReportIcon(reportColors[r.status] || "#6b7280")}>
              <Popup>
                <div className="text-sm">
                  <strong className="text-lg">{r.title}</strong>
                  <p className="text-slate-600 mt-1">{r.description.substring(0, 100)}</p>
                  <p className="mt-1"><span style={{ color: reportColors[r.status] }}>●</span> {r.status} | {r.priority}</p>
                  <p className="text-slate-500 text-xs mt-1">{r.citizen?.name} | {r.location?.address || ""}</p>
                  {r.department && <p className="text-xs text-slate-500">القسم: {r.department.name}</p>}
                </div>
              </Popup>
            </Marker>
          ))}
          {facilities.filter(f => f.lat && f.lng).map(f => (
            <Marker key={`facility-${f.id}`} position={[f.lat, f.lng]} icon={facilityIcon}>
              <Popup>
                <div className="text-sm">
                  <strong>{f.name}</strong>
                  <p className="text-slate-500">{f.type} | {f.address}</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
      <div className="flex gap-4 text-sm text-slate-400">
        <span>🔵 <span className="text-blue-400">جديد</span></span>
        <span>🟡 <span className="text-amber-400">مسند</span></span>
        <span>🟣 <span className="text-purple-400">قيد المعالجة</span></span>
        <span>🟢 <span className="text-emerald-400">محلول</span></span>
        <span>🔴 <span className="text-red-400">مرفوض</span></span>
      </div>
    </div>
  );
}
