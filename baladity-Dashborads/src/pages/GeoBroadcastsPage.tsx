import { useEffect, useMemo, useState } from "react";
import { DivIcon, LatLngExpression } from "leaflet";
import { Circle, MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import "leaflet/dist/leaflet.css";

type BroadcastStatus = "active" | "cancelled";

interface GeoBroadcast {
  id: number;
  title: string;
  body: string;
  broadcast_type: string;
  latitude: string | number;
  longitude: string | number;
  radius_meters: number;
  starts_at: string;
  ends_at: string;
  status: BroadcastStatus;
  cancel_reason?: string | null;
  recipients_count: number;
  is_currently_active: boolean;
  creator?: { full_name?: string; email?: string } | null;
}

interface Recipient {
  id: number;
  matched_by: string;
  citizen?: {
    full_name?: string;
    email?: string;
    phone?: string;
  } | null;
}

const TRIPOLI_CENTER: LatLngExpression = [32.8872, 13.1913];

const markerIcon = new DivIcon({
  className: "",
  html: `<div style="width:24px;height:24px;background:#ef4444;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,.45)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const statusLabels: Record<string, string> = {
  active: "نشط",
  cancelled: "ملغى",
};

const typeLabels: Record<string, string> = {
  critical: "طارئ",
  service: "خدمي",
  works: "أعمال ميدانية",
  weather: "طقس",
  info: "معلومة عامة",
};

const matchedByLabels: Record<string, string> = {
  home: "موقع السكن",
  live: "الموقع الحالي",
  home_and_live: "السكن والموقع الحالي",
};

function LocationPicker({
  latitude,
  longitude,
  radius,
  onChange,
}: {
  latitude: string;
  longitude: string;
  radius: number;
  onChange: (latitude: string, longitude: string) => void;
}) {
  const lat = Number(latitude);
  const lng = Number(longitude);
  const hasPosition = latitude.trim() !== "" && longitude.trim() !== "" && Number.isFinite(lat) && Number.isFinite(lng);
  const position = (hasPosition ? [lat, lng] : TRIPOLI_CENTER) as LatLngExpression;

  function ClickHandler() {
    useMapEvents({
      click(event) {
        onChange(event.latlng.lat.toFixed(6), event.latlng.lng.toFixed(6));
      },
    });

    return null;
  }

  return (
    <div className="space-y-2">
      <p className="text-xs text-slate-400">الخريطة تبدأ من مدينة طرابلس. اضغط على مركز المنطقة ثم عدل النطاق.</p>
      <div className="h-72 overflow-hidden rounded-lg border border-slate-700">
        <MapContainer center={position} zoom={13} className="h-full w-full" scrollWheelZoom>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <ClickHandler />
          {hasPosition && <Marker position={position} icon={markerIcon} />}
          {hasPosition && <Circle center={position} radius={radius} pathOptions={{ color: "#ef4444", fillColor: "#ef4444", fillOpacity: 0.14 }} />}
        </MapContainer>
      </div>
    </div>
  );
}

export default function GeoBroadcastsPage() {
  const { user } = useAuth();
  const contentBasePath = user?.role === "reception" ? "/reception/content" : "/admin";
  const userPermissions = new Set(user?.roleData?.permissions?.map((permission) => permission.permission_name) || []);
  const canManage = user?.role === "admin" || userPermissions.has("manage_geo_broadcasts");

  const [broadcasts, setBroadcasts] = useState<GeoBroadcast[]>([]);
  const [selected, setSelected] = useState<GeoBroadcast | null>(null);
  const [recipients, setRecipients] = useState<Recipient[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [previewCount, setPreviewCount] = useState<number | null>(null);

  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [broadcastType, setBroadcastType] = useState("critical");
  const [startsAt, setStartsAt] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [latitude, setLatitude] = useState("");
  const [longitude, setLongitude] = useState("");
  const [radiusMeters, setRadiusMeters] = useState(500);

  const canSubmit = useMemo(
    () => title.trim() && body.trim() && startsAt && endsAt && latitude && longitude,
    [title, body, startsAt, endsAt, latitude, longitude],
  );

  const loadBroadcasts = async () => {
    if (!canManage) {
      setBroadcasts([]);
      return;
    }

    const query = new URLSearchParams({ per_page: "100" });
    if (statusFilter) query.set("status", statusFilter);
    const response = await api.get<any>(`${contentBasePath}/geo-broadcasts?${query.toString()}`);
    setBroadcasts(Array.isArray(response) ? response : response.data || []);
  };

  useEffect(() => {
    loadBroadcasts().catch(console.error);
  }, [statusFilter, user?.role, user?.roleData?.permissions]);

  const resetForm = () => {
    setTitle("");
    setBody("");
    setBroadcastType("critical");
    setStartsAt("");
    setEndsAt("");
    setLatitude("");
    setLongitude("");
    setRadiusMeters(500);
    setPreviewCount(null);
  };

  const previewTargets = async () => {
    if (!latitude || !longitude) return;
    try {
      const response = await api.post<{ targeted_count: number }>(`${contentBasePath}/geo-broadcasts/preview`, {
        latitude,
        longitude,
        radius_meters: radiusMeters,
      });
      setPreviewCount(response.targeted_count);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const createBroadcast = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;

    try {
      await api.post(`${contentBasePath}/geo-broadcasts`, {
        title,
        body,
        broadcast_type: broadcastType,
        starts_at: startsAt,
        ends_at: endsAt,
        latitude,
        longitude,
        radius_meters: radiusMeters,
      });
      resetForm();
      setShowForm(false);
      await loadBroadcasts();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const openDetails = async (broadcast: GeoBroadcast) => {
    try {
      const response = await api.get<{ broadcast: GeoBroadcast; recipients: Recipient[] }>(`${contentBasePath}/geo-broadcasts/${broadcast.id}`);
      setSelected(response.broadcast);
      setRecipients(response.recipients || []);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const cancelBroadcast = async () => {
    if (!selected) return;
    const reason = window.prompt("اكتب سبب إلغاء التنبيه الجغرافي");
    if (!reason?.trim()) return;

    try {
      await api.patch(`${contentBasePath}/geo-broadcasts/${selected.id}/cancel`, { cancel_reason: reason });
      setSelected(null);
      await loadBroadcasts();
    } catch (error: any) {
      alert(error.message);
    }
  };

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-red-300">التنبيهات الجغرافية وبث الطوارئ</h1>
          <p className="text-sm text-slate-400">إرسال تنبيه داخلي للمواطنين حسب موقع السكن أو موقعهم الحالي داخل نطاق محدد.</p>
        </div>
        <div className="flex gap-2">
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm">
            <option value="">كل الحالات</option>
            {Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
          <button onClick={() => setShowForm(!showForm)} className={`${canManage ? "" : "hidden"} rounded-lg bg-red-600 px-4 py-2 text-sm`}>
            {showForm ? "إلغاء" : "إنشاء تنبيه جديد"}
          </button>
        </div>
      </div>

      {!canManage && (
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-6 text-center text-slate-400">
          لا توجد لديك صلاحية لإدارة التنبيهات الجغرافية.
        </div>
      )}

      {canManage && showForm && (
        <form onSubmit={createBroadcast} className="space-y-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2">
            <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="عنوان التنبيه" className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm" required />
            <select value={broadcastType} onChange={(event) => setBroadcastType(event.target.value)} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm">
              {Object.entries(typeLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
            <input type="datetime-local" value={startsAt} onChange={(event) => setStartsAt(event.target.value)} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm" required />
            <input type="datetime-local" value={endsAt} onChange={(event) => setEndsAt(event.target.value)} className="rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm" required />
          </div>
          <textarea value={body} onChange={(event) => setBody(event.target.value)} placeholder="نص التنبيه الذي سيظهر في سجل إشعارات المواطن" className="h-24 w-full rounded-lg border border-slate-700 bg-slate-800 px-3 py-2 text-sm" required />
          <div className="space-y-2">
            <div className="flex items-center gap-3 text-sm">
              <span className="text-slate-300">نطاق التنبيه: {radiusMeters} متر</span>
              <input type="range" min="50" max="5000" value={radiusMeters} onChange={(event) => { setRadiusMeters(Number(event.target.value)); setPreviewCount(null); }} className="flex-1" />
            </div>
            <LocationPicker latitude={latitude} longitude={longitude} radius={radiusMeters} onChange={(lat, lng) => { setLatitude(lat); setLongitude(lng); setPreviewCount(null); }} />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" onClick={previewTargets} disabled={!latitude || !longitude} className="rounded-lg bg-slate-700 px-4 py-2 text-sm disabled:opacity-50">معاينة عدد المستهدفين</button>
            {previewCount !== null && <span className="text-sm text-slate-300">عدد المواطنين المتوقع وصول التنبيه لهم: {previewCount}</span>}
            <button type="submit" disabled={!canSubmit} className="rounded-lg bg-red-600 px-4 py-2 text-sm disabled:opacity-50">إرسال التنبيه</button>
          </div>
        </form>
      )}

      {canManage && (
        <div className="grid grid-cols-1 gap-4 xl:grid-cols-2">
          {broadcasts.map((broadcast) => (
            <button key={broadcast.id} onClick={() => openDetails(broadcast)} className="rounded-xl border border-slate-800 bg-slate-900 p-4 text-right transition hover:border-red-500/60">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="font-bold text-white">{broadcast.title}</h3>
                  <p className="text-xs text-slate-400">{typeLabels[broadcast.broadcast_type] || broadcast.broadcast_type}</p>
                </div>
                <span className={`rounded px-2 py-1 text-xs ${broadcast.status === "cancelled" ? "bg-red-950 text-red-300" : "bg-slate-800 text-emerald-300"}`}>
                  {statusLabels[broadcast.status] || broadcast.status}
                </span>
              </div>
              <p className="mt-3 line-clamp-2 text-sm text-slate-400">{broadcast.body}</p>
              <div className="mt-3 flex flex-wrap gap-2 text-xs text-slate-500">
                <span>المستلمون: {broadcast.recipients_count}</span>
                <span>النطاق: {broadcast.radius_meters} م</span>
                <span dir="ltr">{new Date(broadcast.starts_at).toLocaleString()} - {new Date(broadcast.ends_at).toLocaleString()}</span>
              </div>
            </button>
          ))}
        </div>
      )}

      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 p-4">
          <div className="max-h-[90vh] w-full max-w-4xl space-y-4 overflow-auto rounded-xl border border-slate-800 bg-slate-900 p-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold text-red-300">{selected.title}</h2>
                <p className="text-sm text-slate-400">{statusLabels[selected.status]} · {typeLabels[selected.broadcast_type]}</p>
              </div>
              <button onClick={() => setSelected(null)} className="text-slate-400 hover:text-white">×</button>
            </div>
            <p className="text-sm text-slate-300">{selected.body}</p>
            {selected.cancel_reason && <p className="text-sm text-red-300">سبب الإلغاء: {selected.cancel_reason}</p>}
            <div className="grid grid-cols-1 gap-3 text-sm md:grid-cols-3">
              <div className="rounded-lg bg-slate-800 p-3">المستلمون: {selected.recipients_count}</div>
              <div className="rounded-lg bg-slate-800 p-3">النطاق: {selected.radius_meters} متر</div>
              <div className="rounded-lg bg-slate-800 p-3">نشط الآن: {selected.is_currently_active ? "نعم" : "لا"}</div>
            </div>
            {selected.status === "active" && (
              <button onClick={cancelBroadcast} className="rounded-lg bg-red-700 px-3 py-2 text-sm">إلغاء التنبيه</button>
            )}
            <div>
              <h3 className="mb-2 font-semibold">المواطنون المستهدفون</h3>
              <div className="space-y-2">
                {recipients.length === 0 && <p className="text-sm text-slate-500">لا يوجد مستلمون لهذا التنبيه.</p>}
                {recipients.map((recipient) => (
                  <div key={recipient.id} className="rounded-lg border border-slate-700/60 bg-slate-800 p-3 text-sm">
                    <div className="font-medium">{recipient.citizen?.full_name || "مواطن"}</div>
                    <div className="text-xs text-slate-400">{recipient.citizen?.email || "-"} · {recipient.citizen?.phone || "-"}</div>
                    <div className="mt-1 text-xs text-red-200">سبب الاستهداف: {matchedByLabels[recipient.matched_by] || recipient.matched_by}</div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
