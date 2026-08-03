import { useEffect, useMemo, useState } from "react";
import { DivIcon, LatLngExpression } from "leaflet";
import { Circle, MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import "leaflet/dist/leaflet.css";

interface PollOption {
  id: number;
  option_text: string;
  votes_count: number;
  percentage: number;
}

interface Poll {
  id: number;
  question: string;
  poll_type: string;
  starts_at: string;
  ends_at: string;
  status: string;
  is_geo_targeted: boolean;
  latitude?: string | number | null;
  longitude?: string | number | null;
  radius_meters?: number | null;
  cancel_reason?: string | null;
  recipients_count: number;
  votes_count: number;
  participation_rate: number;
  is_open: boolean;
  options?: PollOption[];
  creator?: { full_name?: string; email?: string } | null;
}

const TRIPOLI_CENTER: LatLngExpression = [32.8872, 13.1913];

const markerIcon = new DivIcon({
  className: "",
  html: `<div style="width:24px;height:24px;background:#14b8a6;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,.45)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const typeLabels: Record<string, string> = {
  satisfaction: "استبيان رضا",
  budgeting: "تصويت مشاريع",
  quick: "استطلاع سريع",
};

const statusLabels: Record<string, string> = {
  active: "نشط",
  closed: "منتهي",
  cancelled: "ملغى",
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
      <p className="text-xs text-slate-400">اختياري: اضغط على الخريطة لتحديد نطاق ظهور الاستطلاع.</p>
      <div className="h-72 overflow-hidden rounded-lg border border-slate-700">
        <MapContainer center={position} zoom={13} className="h-full w-full" scrollWheelZoom>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <ClickHandler />
          {hasPosition && <Marker position={position} icon={markerIcon} />}
          {hasPosition && <Circle center={position} radius={radius} pathOptions={{ color: "#14b8a6", fillColor: "#14b8a6", fillOpacity: 0.14 }} />}
        </MapContainer>
      </div>
    </div>
  );
}

export default function PollsPage() {
  const { user } = useAuth();
  const contentBasePath = user?.role === "reception" ? "/reception/content" : "/admin";
  const userPermissions = new Set(user?.roleData?.permissions?.map((permission) => permission.permission_name) || []);
  const canManage = user?.role === "admin" || userPermissions.has("manage_polls");

  const [polls, setPolls] = useState<Poll[]>([]);
  const [selected, setSelected] = useState<Poll | null>(null);
  const [statusFilter, setStatusFilter] = useState("");
  const [showForm, setShowForm] = useState(false);

  const [question, setQuestion] = useState("");
  const [pollType, setPollType] = useState("quick");
  const [options, setOptions] = useState(["", ""]);
  const [endsAt, setEndsAt] = useState("");
  const [isGeoTargeted, setIsGeoTargeted] = useState(false);
  const [latitude, setLatitude] = useState("");
  const [longitude, setLongitude] = useState("");
  const [radiusMeters, setRadiusMeters] = useState(500);

  const cleanOptions = useMemo(() => options.map((item) => item.trim()).filter(Boolean), [options]);
  const canSubmit = question.trim() && cleanOptions.length >= 2 && cleanOptions.length <= 4 && endsAt && (!isGeoTargeted || (latitude && longitude));

  const loadPolls = async () => {
    if (!canManage) {
      setPolls([]);
      return;
    }
    const query = new URLSearchParams({ per_page: "100" });
    if (statusFilter) query.set("status", statusFilter);
    const response = await api.get<any>(`${contentBasePath}/polls?${query.toString()}`);
    setPolls(Array.isArray(response) ? response : response.data || []);
  };

  useEffect(() => {
    loadPolls().catch(console.error);
  }, [statusFilter, user?.role, user?.roleData?.permissions]);

  const resetForm = () => {
    setQuestion("");
    setPollType("quick");
    setOptions(["", ""]);
    setEndsAt("");
    setIsGeoTargeted(false);
    setLatitude("");
    setLongitude("");
    setRadiusMeters(500);
  };

  const createPoll = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canSubmit) return;

    try {
      await api.post(`${contentBasePath}/polls`, {
        question,
        poll_type: pollType,
        options: cleanOptions,
        ends_at: endsAt,
        is_geo_targeted: isGeoTargeted,
        ...(isGeoTargeted ? { latitude, longitude, radius_meters: radiusMeters } : {}),
      });
      resetForm();
      setShowForm(false);
      await loadPolls();
    } catch (error: any) {
      alert(error.message || "تعذر إنشاء الاستطلاع.");
    }
  };

  const openDetails = async (poll: Poll) => {
    try {
      const response = await api.get<{ poll: Poll }>(`${contentBasePath}/polls/${poll.id}`);
      setSelected(response.poll);
    } catch (error: any) {
      alert(error.message || "تعذر فتح التفاصيل.");
    }
  };

  const cancelPoll = async (poll: Poll) => {
    const reason = window.prompt("اكتب سبب إلغاء الاستطلاع");
    if (!reason?.trim()) return;
    try {
      await api.patch(`${contentBasePath}/polls/${poll.id}/cancel`, { cancel_reason: reason });
      setSelected(null);
      await loadPolls();
    } catch (error: any) {
      alert(error.message || "تعذر إلغاء الاستطلاع.");
    }
  };

  const deletePoll = async (poll: Poll) => {
    const confirmed = window.confirm("هل أنت متأكد من حذف هذا الاستطلاع المنتهي؟ لا يمكن التراجع عن هذا الإجراء.");
    if (!confirmed) return;

    try {
      await api.delete(`${contentBasePath}/polls/${poll.id}`);
      setSelected(null);
      await loadPolls();
    } catch (error: any) {
      alert(error.message || "تعذر حذف الاستطلاع.");
    }
  };

  const updateOption = (index: number, value: string) => {
    setOptions((current) => current.map((item, itemIndex) => itemIndex === index ? value : item));
  };

  return (
    <div className="p-6 space-y-6" dir="rtl">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">استطلاعات الرأي</h1>
          <p className="text-sm text-slate-400 mt-1">إنشاء استطلاعات استشارية وعرض نسب المشاركة والنتائج.</p>
        </div>
        <button onClick={() => setShowForm(true)} disabled={!canManage} className="px-3 py-2 rounded-lg bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-sm">إنشاء استطلاع</button>
      </div>

      <div className="flex gap-3">
        <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)} className="bg-slate-900 border border-slate-800 rounded-lg px-3 py-2 text-sm">
          <option value="">كل الحالات</option>
          <option value="active">نشط</option>
          <option value="closed">منتهي</option>
          <option value="cancelled">ملغى</option>
        </select>
        <button onClick={loadPolls} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">تحديث</button>
      </div>

      <div className="bg-slate-900 border border-slate-800 rounded-xl overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-slate-800 text-slate-300">
            <tr>
              <th className="p-3 text-right">السؤال</th>
              <th className="p-3">النوع</th>
              <th className="p-3">الحالة</th>
              <th className="p-3">الأصوات</th>
              <th className="p-3">المشاركة</th>
              <th className="p-3">إجراء</th>
            </tr>
          </thead>
          <tbody>
            {polls.map((poll) => (
              <tr key={poll.id} className="border-t border-slate-800 hover:bg-slate-800/50">
                <td className="p-3">
                  <div className="font-semibold">{poll.question}</div>
                  <div className="text-xs text-slate-500">ينتهي: {formatDate(poll.ends_at)}</div>
                </td>
                <td className="p-3 text-center">{typeLabels[poll.poll_type] || poll.poll_type}</td>
                <td className="p-3 text-center">{statusLabels[poll.status] || poll.status}</td>
                <td className="p-3 text-center">{poll.votes_count}</td>
                <td className="p-3 text-center">{poll.participation_rate}%</td>
                <td className="p-3 text-center">
                  <button onClick={() => openDetails(poll)} className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-xs">تفاصيل</button>
                </td>
              </tr>
            ))}
            {polls.length === 0 && <tr><td colSpan={6} className="p-10 text-center text-slate-500">لا توجد استطلاعات حالياً</td></tr>}
          </tbody>
        </table>
      </div>

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <form onSubmit={createPoll} className="w-full max-w-3xl max-h-[90vh] overflow-y-auto bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <div className="flex justify-between">
              <h2 className="text-lg font-bold text-emerald-400">إنشاء استطلاع جديد</h2>
              <button type="button" onClick={() => setShowForm(false)} className="text-slate-400 hover:text-white">×</button>
            </div>
            <input value={question} onChange={(event) => setQuestion(event.target.value)} placeholder="نص السؤال" className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-sm" required />
            <select value={pollType} onChange={(event) => setPollType(event.target.value)} className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-sm">
              <option value="quick">استطلاع سريع</option>
              <option value="satisfaction">استبيان رضا</option>
              <option value="budgeting">تصويت مشاريع</option>
            </select>
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="text-sm text-slate-300">الخيارات من 2 إلى 4</span>
                {options.length < 4 && <button type="button" onClick={() => setOptions([...options, ""])} className="text-xs text-emerald-400">إضافة خيار</button>}
              </div>
              {options.map((option, index) => (
                <div key={index} className="flex gap-2">
                  <input value={option} onChange={(event) => updateOption(index, event.target.value)} placeholder={`الخيار ${index + 1}`} className="flex-1 px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-sm" required={index < 2} />
                  {options.length > 2 && <button type="button" onClick={() => setOptions(options.filter((_, itemIndex) => itemIndex !== index))} className="px-3 rounded-lg bg-red-600/20 text-red-300">حذف</button>}
                </div>
              ))}
            </div>
            <label className="space-y-1">
              <span className="text-sm text-slate-300">تاريخ ووقت نهاية الاستطلاع</span>
              <input type="datetime-local" value={endsAt} onChange={(event) => setEndsAt(event.target.value)} className="w-full px-3 py-2 rounded-lg bg-slate-800 border border-slate-700 text-sm" required />
            </label>
            <label className="flex items-center gap-2 text-sm">
              <input type="checkbox" checked={isGeoTargeted} onChange={(event) => setIsGeoTargeted(event.target.checked)} />
              نطاق جغرافي محدد
            </label>
            {isGeoTargeted && (
              <div className="space-y-3">
                <LocationPicker latitude={latitude} longitude={longitude} radius={radiusMeters} onChange={(lat, lng) => { setLatitude(lat); setLongitude(lng); }} />
                <label className="text-sm text-slate-300">النطاق: {radiusMeters} متر</label>
                <input type="range" min={50} max={20000} step={50} value={radiusMeters} onChange={(event) => setRadiusMeters(Number(event.target.value))} className="w-full" />
              </div>
            )}
            <div className="flex justify-end gap-2">
              <button type="button" onClick={() => setShowForm(false)} className="px-3 py-2 bg-slate-800 hover:bg-slate-700 rounded-lg text-sm">إلغاء</button>
              <button type="submit" disabled={!canSubmit} className="px-3 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-lg text-sm">نشر الاستطلاع</button>
            </div>
          </form>
        </div>
      )}

      {selected && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="w-full max-w-2xl bg-slate-900 border border-slate-800 rounded-xl p-5 space-y-4">
            <div className="flex justify-between">
              <h2 className="text-lg font-bold text-emerald-400">{selected.question}</h2>
              <button onClick={() => setSelected(null)} className="text-slate-400 hover:text-white">×</button>
            </div>
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="bg-slate-800 rounded-lg p-3">الأصوات: {selected.votes_count}</div>
              <div className="bg-slate-800 rounded-lg p-3">المستهدفون: {selected.recipients_count}</div>
            </div>
            <div className="space-y-3">
              {(selected.options || []).map((option) => (
                <div key={option.id}>
                  <div className="flex justify-between text-sm mb-1">
                    <span>{option.option_text}</span>
                    <span>{option.votes_count} صوت - {option.percentage}%</span>
                  </div>
                  <div className="h-2 bg-slate-800 rounded-full overflow-hidden">
                    <div className="h-full bg-emerald-500" style={{ width: `${option.percentage}%` }} />
                  </div>
                </div>
              ))}
            </div>
            <div className="flex justify-end gap-2">
              {selected.status === "closed" && (
                <button onClick={() => deletePoll(selected)} className="px-3 py-2 bg-red-600 hover:bg-red-500 rounded-lg text-sm">حذف الاستطلاع</button>
              )}
              {selected.status === "active" && (
                <button onClick={() => cancelPoll(selected)} className="px-3 py-2 bg-red-600 hover:bg-red-500 rounded-lg text-sm">إلغاء الاستطلاع</button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function formatDate(value: string) {
  return value?.replace("T", " ").slice(0, 16);
}
