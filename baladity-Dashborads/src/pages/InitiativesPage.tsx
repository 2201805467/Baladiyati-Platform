import { useEffect, useMemo, useState } from "react";
import { DivIcon, LatLngExpression } from "leaflet";
import { Circle, MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import "leaflet/dist/leaflet.css";

type InitiativeStatus = "published" | "registration_closed" | "completed" | "cancelled";

interface Initiative {
  id: number;
  title: string;
  description: string;
  goal?: string | null;
  initiative_type: string;
  cover_image_url?: string | null;
  completion_image_url?: string | null;
  starts_at: string;
  ends_at: string;
  latitude: string | number;
  longitude: string | number;
  radius_meters: number;
  max_capacity?: number | null;
  target_audience?: string | null;
  requirements?: string | null;
  status: InitiativeStatus;
  cancel_reason?: string | null;
  registered_count: number;
  attendees_count: number;
  is_full: boolean;
}

interface Registration {
  id: number;
  status: string;
  attended_at?: string | null;
  citizen?: {
    full_name: string;
    email?: string;
    phone?: string;
  } | null;
}

interface BlockedCitizen {
  id: number;
  full_name: string;
  email?: string | null;
  phone?: string | null;
  blocked_at?: string | null;
  block_reason?: string | null;
  missed_completed_initiatives_count: number;
  attended_completed_initiatives_count: number;
}

const statusLabels: Record<string, string> = {
  published: "متاحة للتسجيل",
  registration_closed: "مغلقة التسجيل",
  completed: "منتهية",
  cancelled: "ملغاة",
};

const initiativeTypeLabels: Record<string, string> = {
  tree_planting: "تشجير",
  cleaning: "نظافة",
  painting: "طلاء",
  awareness: "توعية",
  other: "أخرى",
};

const API_ORIGIN = (import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:8000/api").replace(/\/api\/?$/, "");

const assetUrl = (url?: string | null) => {
  if (!url) return null;
  if (url.startsWith("http")) return url;
  return `${API_ORIGIN}${url}`;
};

const markerIcon = new DivIcon({
  className: "",
  html: `<div style="width:24px;height:24px;background:#10b981;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,.45)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const TRIPOLI_CENTER: LatLngExpression = [32.8872, 13.1913];

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
      <p className="text-xs text-slate-400">الخريطة تبدأ من مدينة طرابلس. اضغط على موقع التجمع لتحديده.</p>
      <div className="h-72 overflow-hidden rounded-lg border border-slate-700">
        <MapContainer center={position} zoom={13} className="w-full h-full" scrollWheelZoom>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <ClickHandler />
          {hasPosition && <Marker position={position} icon={markerIcon} />}
          {hasPosition && <Circle center={position} radius={radius} pathOptions={{ color: "#10b981", fillColor: "#10b981", fillOpacity: 0.15 }} />}
        </MapContainer>
      </div>
    </div>
  );
}

export default function InitiativesPage() {
  const { user } = useAuth();
  const contentBasePath = user?.role === "reception" ? "/reception/content" : "/admin";
  const userPermissions = new Set(user?.roleData?.permissions?.map((permission) => permission.permission_name) || []);
  const canManageInitiatives = user?.role === "admin" || userPermissions.has("manage_initiatives");
  const [initiatives, setInitiatives] = useState<Initiative[]>([]);
  const [statusFilter, setStatusFilter] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [showBlockedCitizens, setShowBlockedCitizens] = useState(false);
  const [selected, setSelected] = useState<Initiative | null>(null);
  const [registrations, setRegistrations] = useState<Registration[]>([]);
  const [blockedCitizens, setBlockedCitizens] = useState<BlockedCitizen[]>([]);
  const [isLoadingBlockedCitizens, setIsLoadingBlockedCitizens] = useState(false);

  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [goal, setGoal] = useState("");
  const [initiativeType, setInitiativeType] = useState("tree_planting");
  const [coverImage, setCoverImage] = useState<File | null>(null);
  const [startsAt, setStartsAt] = useState("");
  const [endsAt, setEndsAt] = useState("");
  const [latitude, setLatitude] = useState("");
  const [longitude, setLongitude] = useState("");
  const [radiusMeters, setRadiusMeters] = useState(100);
  const [maxCapacity, setMaxCapacity] = useState("");
  const [targetAudience, setTargetAudience] = useState("للجميع");
  const [requirements, setRequirements] = useState("");
  const [completionImage, setCompletionImage] = useState<File | null>(null);

  const canSubmit = useMemo(
    () => title.trim() && description.trim() && startsAt && endsAt && latitude && longitude,
    [title, description, startsAt, endsAt, latitude, longitude],
  );
  const missedAttendanceCount = useMemo(
    () => selected?.status === "completed" ? registrations.filter((item) => !item.attended_at).length : 0,
    [registrations, selected?.status],
  );

  const loadInitiatives = async () => {
    if (!canManageInitiatives) {
      setInitiatives([]);
      return;
    }

    const query = new URLSearchParams({ per_page: "100" });
    if (statusFilter) query.set("status", statusFilter);
    const response = await api.get<any>(`${contentBasePath}/initiatives?${query.toString()}`);
    setInitiatives(Array.isArray(response) ? response : response.data || []);
  };

  useEffect(() => {
    loadInitiatives().catch(console.error);
  }, [statusFilter, user?.role, user?.roleData?.permissions]);

  const resetForm = () => {
    setTitle("");
    setDescription("");
    setGoal("");
    setInitiativeType("tree_planting");
    setCoverImage(null);
    setStartsAt("");
    setEndsAt("");
    setLatitude("");
    setLongitude("");
    setRadiusMeters(100);
    setMaxCapacity("");
    setTargetAudience("للجميع");
    setRequirements("");
  };

  const createInitiative = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;

    const form = new FormData();
    form.append("title", title);
    form.append("description", description);
    if (goal) form.append("goal", goal);
    form.append("initiative_type", initiativeType);
    if (coverImage) form.append("cover_image", coverImage);
    form.append("starts_at", startsAt);
    form.append("ends_at", endsAt);
    form.append("latitude", latitude);
    form.append("longitude", longitude);
    form.append("radius_meters", String(radiusMeters));
    if (maxCapacity) form.append("max_capacity", maxCapacity);
    if (targetAudience) form.append("target_audience", targetAudience);
    if (requirements) form.append("requirements", requirements);
    form.append("status", "published");

    try {
      await api.post(`${contentBasePath}/initiatives`, form);
      resetForm();
      setShowForm(false);
      await loadInitiatives();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const openDetails = async (initiative: Initiative) => {
    try {
      const response = await api.get<{ initiative: Initiative; registrations: Registration[] }>(`${contentBasePath}/initiatives/${initiative.id}`);
      setSelected(response.initiative);
      setRegistrations(response.registrations || []);
      setCompletionImage(null);
    } catch (error: any) {
      alert(error.message);
    }
  };

  const loadBlockedCitizens = async () => {
    setIsLoadingBlockedCitizens(true);
    try {
      const response = await api.get<any>(`${contentBasePath}/initiatives/blocked-citizens?per_page=100`);
      setBlockedCitizens(Array.isArray(response) ? response : response.data || []);
    } catch (error: any) {
      alert(error.message);
    } finally {
      setIsLoadingBlockedCitizens(false);
    }
  };

  const openBlockedCitizens = async () => {
    setShowBlockedCitizens(true);
    await loadBlockedCitizens();
  };

  const unblockCitizen = async (citizen: BlockedCitizen) => {
    if (!window.confirm(`هل تريد إلغاء حظر ${citizen.full_name} من التسجيل في المبادرات؟`)) return;

    try {
      await api.patch(`${contentBasePath}/initiatives/blocked-citizens/${citizen.id}/unblock`);
      await loadBlockedCitizens();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const cancelInitiative = async () => {
    if (!selected) return;
    const reason = window.prompt("اكتب سبب إلغاء المبادرة");
    if (!reason?.trim()) return;
    try {
      await api.patch(`${contentBasePath}/initiatives/${selected.id}/cancel`, { cancel_reason: reason });
      setSelected(null);
      await loadInitiatives();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const completeInitiative = async () => {
    if (!selected) return;
    const form = new FormData();
    if (completionImage) form.append("completion_image", completionImage);
    try {
      await api.post(`${contentBasePath}/initiatives/${selected.id}/complete`, form);
      setSelected(null);
      await loadInitiatives();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const deleteInitiative = async () => {
    if (!selected) return;
    if (!["completed", "cancelled"].includes(selected.status)) return;

    if (!window.confirm(`هل تريد حذف مبادرة "${selected.title}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.`)) return;

    try {
      await api.delete(`${contentBasePath}/initiatives/${selected.id}`);
      setSelected(null);
      await loadInitiatives();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const toggleRegistration = async () => {
    if (!selected) return;
    const path = selected.status === "registration_closed" ? "publish" : "close-registration";
    try {
      await api.patch(`${contentBasePath}/initiatives/${selected.id}/${path}`);
      await openDetails(selected);
      await loadInitiatives();
    } catch (error: any) {
      alert(error.message);
    }
  };

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-bold text-emerald-400">إدارة المبادرات والحملات</h1>
        <div className="flex gap-2">
          <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
            <option value="">كل الحالات</option>
            {Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select>
          <button onClick={openBlockedCitizens} className={`${canManageInitiatives ? "" : "hidden"} px-4 py-2 bg-red-700 rounded-lg text-sm`}>
            المحظورون من التسجيل
          </button>
          <button onClick={() => setShowForm(!showForm)} className={`${canManageInitiatives ? "" : "hidden"} px-4 py-2 bg-emerald-600 rounded-lg text-sm`}>
            {showForm ? "إلغاء" : "إنشاء حملة جديدة"}
          </button>
        </div>
      </div>

      {!canManageInitiatives && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 text-center text-slate-400">
          لا توجد لديك صلاحية لإدارة المبادرات حالياً.
        </div>
      )}

      {canManageInitiatives && showForm && (
        <form onSubmit={createInitiative} className="bg-slate-900 border border-slate-800 rounded-xl p-4 space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="عنوان الحملة" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <select value={initiativeType} onChange={(event) => setInitiativeType(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
              {Object.entries(initiativeTypeLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
            <input type="datetime-local" value={startsAt} onChange={(event) => setStartsAt(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input type="datetime-local" value={endsAt} onChange={(event) => setEndsAt(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
            <input type="number" min="1" value={maxCapacity} onChange={(event) => setMaxCapacity(event.target.value)} placeholder="السعة القصوى، اتركها فارغة إذا كانت مفتوحة" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
            <input value={targetAudience} onChange={(event) => setTargetAudience(event.target.value)} placeholder="الفئة المستهدفة" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
          </div>
          <textarea value={description} onChange={(event) => setDescription(event.target.value)} placeholder="الوصف التفصيلي" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-24" required />
          <textarea value={goal} onChange={(event) => setGoal(event.target.value)} placeholder="هدف المبادرة" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
          <textarea value={requirements} onChange={(event) => setRequirements(event.target.value)} placeholder="متطلبات خاصة" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
          <label className="block space-y-2 rounded-lg border border-slate-700 bg-slate-800/70 p-3">
            <span className="block text-sm font-medium text-slate-200">صورة الغلاف</span>
            <input
              type="file"
              accept="image/*"
              onChange={(event) => setCoverImage(event.target.files?.[0] || null)}
              className="block w-full text-sm text-slate-300 file:ml-3 file:rounded-md file:border-0 file:bg-emerald-600 file:px-3 file:py-2 file:text-sm file:text-white hover:file:bg-emerald-700"
            />
            <span className="block text-xs text-slate-400">
              {coverImage ? `تم اختيار: ${coverImage.name}` : "اختياري - تظهر هذه الصورة في بطاقة المبادرة وتفاصيلها داخل تطبيق المواطن"}
            </span>
          </label>
          <div className="space-y-2">
            <div className="flex items-center gap-3 text-sm">
              <span className="text-slate-300">نطاق الحضور: {radiusMeters} متر</span>
              <input type="range" min="20" max="1000" value={radiusMeters} onChange={(event) => setRadiusMeters(Number(event.target.value))} className="flex-1" />
            </div>
            <LocationPicker latitude={latitude} longitude={longitude} radius={radiusMeters} onChange={(lat, lng) => { setLatitude(lat); setLongitude(lng); }} />
          </div>
          <button type="submit" disabled={!canSubmit} className="px-4 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">نشر المبادرة</button>
        </form>
      )}

      {canManageInitiatives && <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
        {initiatives.map((initiative) => {
          const cover = assetUrl(initiative.cover_image_url);
          const progress = initiative.max_capacity ? Math.min(100, Math.round((initiative.registered_count / initiative.max_capacity) * 100)) : 0;
          return (
            <button key={initiative.id} onClick={() => openDetails(initiative)} className="text-right bg-slate-900 border border-slate-800 rounded-xl overflow-hidden hover:border-emerald-700 transition">
              {cover && <img src={cover} alt={initiative.title} className="w-full h-44 object-cover" />}
              <div className="p-4 space-y-3">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <h3 className="font-bold text-white">{initiative.title}</h3>
                    <p className="text-xs text-slate-400">{initiativeTypeLabels[initiative.initiative_type] || initiative.initiative_type}</p>
                  </div>
                  <span className="px-2 py-1 bg-slate-800 rounded text-xs text-emerald-300">{statusLabels[initiative.status]}</span>
                </div>
                <p className="text-sm text-slate-400 line-clamp-2">{initiative.description}</p>
                <div className="text-xs text-slate-500" dir="ltr">{new Date(initiative.starts_at).toLocaleString()} - {new Date(initiative.ends_at).toLocaleString()}</div>
                <div>
                  <div className="flex justify-between text-xs text-slate-400 mb-1">
                    <span>{initiative.max_capacity ? `${initiative.registered_count}/${initiative.max_capacity}` : `${initiative.registered_count} مسجل`}</span>
                    <span>{initiative.attendees_count} حضور</span>
                  </div>
                  {initiative.max_capacity && <div className="h-2 bg-slate-800 rounded-full"><div className="h-2 bg-emerald-500 rounded-full" style={{ width: `${progress}%` }} /></div>}
                </div>
              </div>
            </button>
          );
        })}
      </div>}

      {showBlockedCitizens && (
        <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4">
          <div className="w-full max-w-3xl max-h-[85vh] overflow-auto bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold text-red-300">المحظورون من التسجيل في المبادرات</h2>
                <p className="text-sm text-slate-400">يتم الحظر عند تجاوز 3 مبادرات مكتملة دون تأكيد أي حضور.</p>
              </div>
              <button onClick={() => setShowBlockedCitizens(false)} className="text-slate-400 hover:text-white">×</button>
            </div>

            {isLoadingBlockedCitizens ? (
              <div className="rounded-lg bg-slate-800 p-4 text-center text-sm text-slate-400">جاري تحميل القائمة...</div>
            ) : blockedCitizens.length === 0 ? (
              <div className="rounded-lg bg-slate-800 p-4 text-center text-sm text-slate-400">لا يوجد مواطنون محظورون حالياً.</div>
            ) : (
              <div className="space-y-2">
                {blockedCitizens.map((citizen) => (
                  <div key={citizen.id} className="rounded-lg border border-red-500/30 bg-red-950/20 p-3 text-sm">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <div className="font-semibold text-red-100">{citizen.full_name}</div>
                        <div className="text-xs text-slate-400">{citizen.email || "-"} · {citizen.phone || "-"}</div>
                        <div className="mt-1 text-xs text-red-200">{citizen.block_reason || "محظور من التسجيل في المبادرات"}</div>
                        <div className="mt-1 text-xs text-slate-400">
                          لم يحضر: {citizen.missed_completed_initiatives_count} · حضر: {citizen.attended_completed_initiatives_count}
                        </div>
                        {citizen.blocked_at && (
                          <div className="mt-1 text-xs text-slate-500">تاريخ الحظر: {new Date(citizen.blocked_at).toLocaleString()}</div>
                        )}
                      </div>
                      <button onClick={() => unblockCitizen(citizen)} className="rounded-lg bg-emerald-700 px-3 py-2 text-xs text-white hover:bg-emerald-600">
                        إلغاء الحظر
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {selected && (
        <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4">
          <div className="w-full max-w-4xl max-h-[90vh] overflow-auto bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-5">
            <div className="flex items-start justify-between gap-3">
              <div>
                <h2 className="text-xl font-bold text-emerald-400">{selected.title}</h2>
                <p className="text-sm text-slate-400">{statusLabels[selected.status]} · {initiativeTypeLabels[selected.initiative_type]}</p>
              </div>
              <button onClick={() => setSelected(null)} className="text-slate-400 hover:text-white">×</button>
            </div>

            <p className="text-sm text-slate-300">{selected.description}</p>
            {selected.goal && <p className="text-sm text-slate-400">الهدف: {selected.goal}</p>}
            {selected.requirements && <p className="text-sm text-slate-400">المتطلبات: {selected.requirements}</p>}
            {selected.cancel_reason && <p className="text-sm text-red-300">سبب الإلغاء: {selected.cancel_reason}</p>}

            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-sm">
              <div className="bg-slate-800 rounded-lg p-3">المسجلون: {selected.registered_count}{selected.max_capacity ? `/${selected.max_capacity}` : ""}</div>
              <div className="bg-slate-800 rounded-lg p-3">الحضور: {selected.attendees_count}</div>
              <div className="bg-slate-800 rounded-lg p-3">نطاق الحضور: {selected.radius_meters} متر</div>
            </div>

            <div className="flex flex-wrap gap-2">
              {["published", "registration_closed"].includes(selected.status) && (
                <button onClick={toggleRegistration} className="px-3 py-2 bg-slate-700 rounded-lg text-sm">
                  {selected.status === "registration_closed" ? "إعادة فتح التسجيل" : "إغلاق التسجيل"}
                </button>
              )}
              {selected.status !== "completed" && selected.status !== "cancelled" && (
                <button onClick={cancelInitiative} className="px-3 py-2 bg-red-700 rounded-lg text-sm">إلغاء المبادرة</button>
              )}
              {selected.status !== "completed" && selected.status !== "cancelled" && (
                <div className="flex flex-wrap gap-2 items-center">
                  <input type="file" accept="image/*" onChange={(event) => setCompletionImage(event.target.files?.[0] || null)} className="text-sm text-slate-300" />
                  <button onClick={completeInitiative} className="px-3 py-2 bg-emerald-700 rounded-lg text-sm">إنهاء المبادرة</button>
                </div>
              )}
              {["completed", "cancelled"].includes(selected.status) && (
                <button onClick={deleteInitiative} className="px-3 py-2 bg-red-800 rounded-lg text-sm">
                  حذف المبادرة نهائياً
                </button>
              )}
            </div>

            <div>
              <div>
                <div className="mb-2 flex items-center justify-between gap-2">
                  <h3 className="font-semibold">المواطنون المسجلون</h3>
                  {selected.status === "completed" && missedAttendanceCount > 0 && (
                    <span className="rounded-full bg-red-500/15 px-2 py-1 text-xs text-red-300">
                      لم يحضروا: {missedAttendanceCount}
                    </span>
                  )}
                </div>
                <div className="space-y-2">
                  {registrations.length === 0 && <p className="text-sm text-slate-500">لا يوجد مسجلون حالياً.</p>}
                  {registrations.map((item) => {
                    const missedAttendance = selected.status === "completed" && !item.attended_at;
                    return (
                      <div
                        key={item.id}
                        className={`rounded-lg border p-3 text-sm ${
                          missedAttendance ? "border-red-500/50 bg-red-950/30" : "border-slate-700/60 bg-slate-800"
                        }`}
                      >
                        <div className="flex items-start justify-between gap-2">
                          <div>
                            <div className={`font-medium ${missedAttendance ? "text-red-200" : ""}`}>
                              {item.citizen?.full_name || "مواطن محذوف"}
                            </div>
                            <div className="text-xs text-slate-400">{item.citizen?.email || "-"} · {item.citizen?.phone || "-"}</div>
                          </div>
                          {missedAttendance ? (
                            <span className="shrink-0 rounded-full bg-red-500/20 px-2 py-1 text-xs text-red-200">لم يحضر</span>
                          ) : item.attended_at ? (
                            <span className="shrink-0 rounded-full bg-emerald-500/15 px-2 py-1 text-xs text-emerald-300">حضر</span>
                          ) : null}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
