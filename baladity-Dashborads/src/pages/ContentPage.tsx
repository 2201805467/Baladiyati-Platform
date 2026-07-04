import { useEffect, useState } from "react";
import { DivIcon, LatLngExpression } from "leaflet";
import { MapContainer, Marker, TileLayer, useMapEvents } from "react-leaflet";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";
import "leaflet/dist/leaflet.css";

type Tab = "projects" | "facilities" | "contacts";

interface Project {
  id: string;
  name: string;
  description?: string | null;
  contractor?: string | null;
  progress_percent: number;
  start_date?: string | null;
  end_date?: string | null;
  status: string;
}

interface Facility {
  id: string;
  name: string;
  facility_type: string;
  latitude: string | number;
  longitude: string | number;
  working_hours?: string | null;
  services?: string | null;
  is_active?: boolean;
}

interface EmergencyContact {
  id: string;
  name: string;
  phone: string;
  alt_phone?: string | null;
  category: string;
  description?: string | null;
  is_active?: boolean;
}

const projectStatusLabels: Record<string, string> = {
  planned: "مخطط",
  in_progress: "قيد التنفيذ",
  completed: "مكتمل",
  paused: "متوقف مؤقتاً",
  cancelled: "ملغي",
};

const facilityTypes = ["park", "clinic", "mosque", "market", "parking", "restroom", "office", "other"];
const contactCategories = ["ambulance", "fire", "police", "electricity", "water", "municipality", "maintenance", "other"];

const selectedFacilityIcon = new DivIcon({
  className: "",
  html: `<div style="width:24px;height:24px;background:#10b981;border:3px solid white;border-radius:50%;box-shadow:0 2px 8px rgba(0,0,0,0.45)"></div>`,
  iconSize: [24, 24],
  iconAnchor: [12, 12],
});

const numberValue = (value: string) => {
  if (!value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

function FacilityLocationPicker({
  latitude,
  longitude,
  onChange,
}: {
  latitude: string;
  longitude: string;
  onChange: (latitude: string, longitude: string) => void;
}) {
  const selectedLat = numberValue(latitude);
  const selectedLng = numberValue(longitude);
  const selectedPosition = selectedLat !== null && selectedLng !== null
    ? [selectedLat, selectedLng] as LatLngExpression
    : null;
  const center: LatLngExpression = selectedPosition || [32.8872, 13.1913];

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
      <div className="h-64 overflow-hidden rounded-lg border border-slate-700">
        <MapContainer center={center} zoom={13} className="w-full h-full" scrollWheelZoom>
          <TileLayer attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>' url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
          <ClickHandler />
          {selectedPosition && <Marker position={selectedPosition} icon={selectedFacilityIcon} />}
        </MapContainer>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs">
        <div className="rounded-lg border border-slate-800 bg-slate-800/60 px-3 py-2 text-slate-300">
          خط العرض: <span dir="ltr">{latitude || "-"}</span>
        </div>
        <div className="rounded-lg border border-slate-800 bg-slate-800/60 px-3 py-2 text-slate-300">
          خط الطول: <span dir="ltr">{longitude || "-"}</span>
        </div>
      </div>
    </div>
  );
}

export default function ContentPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState<Tab>("projects");
  const [showForm, setShowForm] = useState(false);
  const [projects, setProjects] = useState<Project[]>([]);
  const [facilities, setFacilities] = useState<Facility[]>([]);
  const [contacts, setContacts] = useState<EmergencyContact[]>([]);

  const [projectName, setProjectName] = useState("");
  const [projectDescription, setProjectDescription] = useState("");
  const [projectContractor, setProjectContractor] = useState("");
  const [projectProgress, setProjectProgress] = useState(0);
  const [projectStatus, setProjectStatus] = useState("planned");
  const [projectStartDate, setProjectStartDate] = useState("");
  const [projectEndDate, setProjectEndDate] = useState("");

  const [facilityName, setFacilityName] = useState("");
  const [facilityType, setFacilityType] = useState("park");
  const [facilityLat, setFacilityLat] = useState("");
  const [facilityLng, setFacilityLng] = useState("");
  const [facilityHours, setFacilityHours] = useState("");
  const [facilityServices, setFacilityServices] = useState("");

  const [contactName, setContactName] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [contactAltPhone, setContactAltPhone] = useState("");
  const [contactCategory, setContactCategory] = useState("municipality");
  const [contactDescription, setContactDescription] = useState("");

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  const contentBasePath = user?.role === "reception" ? "/reception/content" : "/admin";
  const userPermissions = new Set(user?.roleData?.permissions?.map((permission) => permission.permission_name) || []);
  const canManageProjects = user?.role === "admin" || userPermissions.has("manage_projects");
  const canManagePublicContent = user?.role === "admin" || userPermissions.has("manage_public_facilities");
  const tabs = [
    canManageProjects ? { key: "projects" as const, label: `المشاريع (${projects.length})` } : null,
    canManagePublicContent ? { key: "facilities" as const, label: `المرافق (${facilities.length})` } : null,
    canManagePublicContent ? { key: "contacts" as const, label: `أرقام الطوارئ (${contacts.length})` } : null,
  ].filter(Boolean) as { key: Tab; label: string }[];

  useEffect(() => {
    loadAll();
  }, [user?.role, user?.roleData?.permissions]);

  useEffect(() => {
    if (tabs.length > 0 && !tabs.some((item) => item.key === tab)) {
      setTab(tabs[0].key);
      setShowForm(false);
    }
  }, [tabs, tab]);

  const pagedData = <T,>(response: any): T[] => Array.isArray(response) ? response : response.data || [];

  const loadAll = async () => {
    if (canManageProjects) {
      try {
        const response = await api.get<any>(`${contentBasePath}/projects?per_page=100`);
        setProjects(pagedData<Project>(response));
      } catch (error) {
        console.error("loadProjects", error);
      }
    } else {
      setProjects([]);
    }
    if (canManagePublicContent) {
      try {
        const response = await api.get<any>(`${contentBasePath}/facilities?per_page=100`);
        setFacilities(pagedData<Facility>(response));
      } catch (error) {
        console.error("loadFacilities", error);
      }
      try {
        const response = await api.get<any>(`${contentBasePath}/emergency-contacts?per_page=100`);
        setContacts(pagedData<EmergencyContact>(response));
      } catch (error) {
        console.error("loadContacts", error);
      }
    } else {
      setFacilities([]);
      setContacts([]);
    }
  };

  const resetForms = () => {
    setProjectName("");
    setProjectDescription("");
    setProjectContractor("");
    setProjectProgress(0);
    setProjectStatus("planned");
    setProjectStartDate("");
    setProjectEndDate("");
    setFacilityName("");
    setFacilityType("park");
    setFacilityLat("");
    setFacilityLng("");
    setFacilityHours("");
    setFacilityServices("");
    setContactName("");
    setContactPhone("");
    setContactAltPhone("");
    setContactCategory("municipality");
    setContactDescription("");
  };

  const handleCreateProject = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canManageProjects) return;
    try {
      await api.post(`${contentBasePath}/projects`, {
        name: projectName,
        description: projectDescription || null,
        contractor: projectContractor || null,
        progress_percent: projectProgress,
        status: projectStatus,
        start_date: projectStartDate || null,
        end_date: projectEndDate || null,
      });
      resetForms();
      setShowForm(false);
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleCreateFacility = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canManagePublicContent) return;
    if (!facilityLat || !facilityLng) {
      alert("يرجى تحديد موقع المرفق على الخريطة.");
      return;
    }

    try {
      await api.post(`${contentBasePath}/facilities`, {
        name: facilityName,
        facility_type: facilityType,
        latitude: Number(facilityLat),
        longitude: Number(facilityLng),
        working_hours: facilityHours || null,
        services: facilityServices || null,
      });
      resetForms();
      setShowForm(false);
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const handleCreateContact = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!canManagePublicContent) return;
    try {
      await api.post(`${contentBasePath}/emergency-contacts`, {
        name: contactName,
        phone: contactPhone,
        alt_phone: contactAltPhone || null,
        category: contactCategory,
        description: contactDescription || null,
      });
      resetForms();
      setShowForm(false);
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const updateProject = async (project: Project, changes: Partial<Project>) => {
    if (!canManageProjects) return;
    try {
      await api.put(`${contentBasePath}/projects/${project.id}`, changes);
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const toggleFacility = async (facility: Facility) => {
    if (!canManagePublicContent) return;
    try {
      await api.put(`${contentBasePath}/facilities/${facility.id}`, { is_active: !facility.is_active });
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const toggleContact = async (contact: EmergencyContact) => {
    if (!canManagePublicContent) return;
    try {
      await api.put(`${contentBasePath}/emergency-contacts/${contact.id}`, { is_active: !contact.is_active });
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-emerald-400">إدارة المحتوى</h1>
        <button onClick={() => setShowForm(!showForm)} className={`${tabs.length === 0 ? "hidden" : ""} px-4 py-2 bg-emerald-600 rounded-lg text-sm`}>
          {showForm ? "إلغاء" : "إضافة"}
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[
          { key: "projects", label: `المشاريع (${projects.length})` },
          { key: "facilities", label: `المرافق (${facilities.length})` },
          { key: "contacts", label: `أرقام الطوارئ (${contacts.length})` },
        ].map((item) => (
          <button key={item.key} onClick={() => { const nextTab = item.key as Tab; if ((nextTab === "projects" && !canManageProjects) || (nextTab !== "projects" && !canManagePublicContent)) return; setTab(nextTab); setShowForm(false); }} className={`${(item.key === "projects" && !canManageProjects) || (item.key !== "projects" && !canManagePublicContent) ? "hidden" : ""} px-4 py-2 rounded-lg text-sm ${tab === item.key ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>
            {item.label}
          </button>
        ))}
      </div>

      {tabs.length === 0 && (
        <div className="bg-slate-900 border border-slate-800 rounded-xl p-6 text-center text-slate-400">
          لا توجد لديك صلاحية لإدارة المحتوى حالياً.
        </div>
      )}

      {tab === "projects" && canManageProjects && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateProject} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={projectName} onChange={(event) => setProjectName(event.target.value)} placeholder="اسم المشروع" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <textarea value={projectDescription} onChange={(event) => setProjectDescription(event.target.value)} placeholder="الوصف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <input value={projectContractor} onChange={(event) => setProjectContractor(event.target.value)} placeholder="المقاول" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
                <select value={projectStatus} onChange={(event) => setProjectStatus(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                  {Object.entries(projectStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
                <input type="date" value={projectStartDate} onChange={(event) => setProjectStartDate(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
                <input type="date" value={projectEndDate} onChange={(event) => setProjectEndDate(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              </div>
              <div className="flex items-center gap-3">
                <input type="range" min="0" max="100" value={projectProgress} onChange={(event) => setProjectProgress(Number(event.target.value))} className="flex-1" />
                <span className="w-14 text-sm text-slate-300">{projectProgress}%</span>
              </div>
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء مشروع</button>
            </form>
          )}

          {projects.map((project) => (
            <div key={project.id} className="bg-slate-900 rounded-xl p-4 border border-slate-800">
              <div className="flex items-start justify-between gap-4 mb-3">
                <div>
                  <h3 className="font-medium">{project.name}</h3>
                  <p className="text-sm text-slate-400">{project.description || "-"}</p>
                  <p className="text-xs text-slate-500 mt-1">{project.contractor || "بدون مقاول"} · {projectStatusLabels[project.status] || project.status}</p>
                </div>
                <select value={project.status} onChange={(event) => updateProject(project, { status: event.target.value })} className="px-2 py-1 bg-slate-800 border border-slate-700 rounded text-xs">
                  {Object.entries(projectStatusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </div>
              <div className="flex items-center gap-3">
                <div className="flex-1 bg-slate-800 rounded-full h-2">
                  <div className="h-2 rounded-full bg-emerald-500" style={{ width: `${project.progress_percent}%` }} />
                </div>
                <span className="text-sm text-slate-300 w-12">{project.progress_percent}%</span>
                <input type="range" min="0" max="100" value={project.progress_percent} onChange={(event) => updateProject(project, { progress_percent: Number(event.target.value) })} className="w-28" />
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === "facilities" && canManagePublicContent && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateFacility} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={facilityName} onChange={(event) => setFacilityName(event.target.value)} placeholder="اسم المرفق" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <div className="grid grid-cols-1 md:grid-cols-1 gap-3">
                <select value={facilityType} onChange={(event) => setFacilityType(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                  {facilityTypes.map((type) => <option key={type} value={type}>{type}</option>)}
                </select>
              </div>
              <FacilityLocationPicker
                latitude={facilityLat}
                longitude={facilityLng}
                onChange={(latitude, longitude) => {
                  setFacilityLat(latitude);
                  setFacilityLng(longitude);
                }}
              />
              <input value={facilityHours} onChange={(event) => setFacilityHours(event.target.value)} placeholder="ساعات العمل" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
              <textarea value={facilityServices} onChange={(event) => setFacilityServices(event.target.value)} placeholder="الخدمات" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء مرفق</button>
            </form>
          )}

          <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-800 text-sm text-slate-500">
                  <th className="text-right p-3">الاسم</th>
                  <th className="text-right p-3">النوع</th>
                  <th className="text-right p-3">الموقع</th>
                  <th className="text-right p-3">الحالة</th>
                  <th className="text-right p-3">إجراء</th>
                </tr>
              </thead>
              <tbody>
                {facilities.map((facility) => (
                  <tr key={facility.id} className="border-b border-slate-800/50 text-sm">
                    <td className="p-3">{facility.name}</td>
                    <td className="p-3 text-slate-400">{facility.facility_type}</td>
                    <td className="p-3 text-slate-400">{facility.latitude}, {facility.longitude}</td>
                    <td className="p-3"><span className={`px-2 py-0.5 rounded text-xs ${facility.is_active !== false ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>{facility.is_active !== false ? "نشط" : "موقوف"}</span></td>
                    <td className="p-3"><button onClick={() => toggleFacility(facility)} className="px-2 py-1 bg-slate-700 rounded text-xs">{facility.is_active !== false ? "إيقاف" : "تفعيل"}</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {tab === "contacts" && canManagePublicContent && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateContact} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={contactName} onChange={(event) => setContactName(event.target.value)} placeholder="اسم الجهة" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <input value={contactPhone} onChange={(event) => setContactPhone(event.target.value)} placeholder="رقم الهاتف" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required dir="ltr" />
                <input value={contactAltPhone} onChange={(event) => setContactAltPhone(event.target.value)} placeholder="رقم بديل" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" dir="ltr" />
                <select value={contactCategory} onChange={(event) => setContactCategory(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                  {contactCategories.map((category) => <option key={category} value={category}>{category}</option>)}
                </select>
              </div>
              <textarea value={contactDescription} onChange={(event) => setContactDescription(event.target.value)} placeholder="الوصف" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm h-20" />
              <button type="submit" className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">إنشاء رقم</button>
            </form>
          )}

          <div className="bg-slate-900 rounded-xl border border-slate-800 overflow-hidden">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-800 text-sm text-slate-500">
                  <th className="text-right p-3">الاسم</th>
                  <th className="text-right p-3">الرقم</th>
                  <th className="text-right p-3">التصنيف</th>
                  <th className="text-right p-3">الحالة</th>
                  <th className="text-right p-3">إجراء</th>
                </tr>
              </thead>
              <tbody>
                {contacts.map((contact) => (
                  <tr key={contact.id} className="border-b border-slate-800/50 text-sm">
                    <td className="p-3">{contact.name}</td>
                    <td className="p-3 text-emerald-400 font-bold">{contact.phone}{contact.alt_phone ? ` / ${contact.alt_phone}` : ""}</td>
                    <td className="p-3 text-slate-400">{contact.category}</td>
                    <td className="p-3"><span className={`px-2 py-0.5 rounded text-xs ${contact.is_active !== false ? "bg-emerald-500/20 text-emerald-400" : "bg-red-500/20 text-red-400"}`}>{contact.is_active !== false ? "نشط" : "موقوف"}</span></td>
                    <td className="p-3"><button onClick={() => toggleContact(contact)} className="px-2 py-1 bg-slate-700 rounded text-xs">{contact.is_active !== false ? "إيقاف" : "تفعيل"}</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}
