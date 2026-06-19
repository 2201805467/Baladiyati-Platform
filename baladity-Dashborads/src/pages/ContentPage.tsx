import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

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

  useEffect(() => {
    loadAll();
  }, []);

  const pagedData = <T,>(response: any): T[] => Array.isArray(response) ? response : response.data || [];

  const loadAll = async () => {
    try {
      const response = await api.get<any>("/admin/projects?per_page=100");
      setProjects(pagedData<Project>(response));
    } catch (error) {
      console.error("loadProjects", error);
    }
    try {
      const response = await api.get<any>("/admin/facilities?per_page=100");
      setFacilities(pagedData<Facility>(response));
    } catch (error) {
      console.error("loadFacilities", error);
    }
    try {
      const response = await api.get<any>("/admin/emergency-contacts?per_page=100");
      setContacts(pagedData<EmergencyContact>(response));
    } catch (error) {
      console.error("loadContacts", error);
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
    try {
      await api.post("/admin/projects", {
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
    try {
      await api.post("/admin/facilities", {
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
    try {
      await api.post("/admin/emergency-contacts", {
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
    try {
      await api.put(`/admin/projects/${project.id}`, changes);
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const toggleFacility = async (facility: Facility) => {
    try {
      await api.put(`/admin/facilities/${facility.id}`, { is_active: !facility.is_active });
      loadAll();
    } catch (error: any) {
      alert(error.message);
    }
  };

  const toggleContact = async (contact: EmergencyContact) => {
    try {
      await api.put(`/admin/emergency-contacts/${contact.id}`, { is_active: !contact.is_active });
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
        <button onClick={() => setShowForm(!showForm)} className="px-4 py-2 bg-emerald-600 rounded-lg text-sm">
          {showForm ? "إلغاء" : "إضافة"}
        </button>
      </div>

      <div className="flex flex-wrap gap-2">
        {[
          { key: "projects", label: `المشاريع (${projects.length})` },
          { key: "facilities", label: `المرافق (${facilities.length})` },
          { key: "contacts", label: `أرقام الطوارئ (${contacts.length})` },
        ].map((item) => (
          <button key={item.key} onClick={() => { setTab(item.key as Tab); setShowForm(false); }} className={`px-4 py-2 rounded-lg text-sm ${tab === item.key ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-400"}`}>
            {item.label}
          </button>
        ))}
      </div>

      {tab === "projects" && (
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

      {tab === "facilities" && (
        <div className="space-y-4">
          {showForm && (
            <form onSubmit={handleCreateFacility} className="bg-slate-900 rounded-xl p-4 border border-slate-800 space-y-3">
              <input value={facilityName} onChange={(event) => setFacilityName(event.target.value)} placeholder="اسم المرفق" className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <select value={facilityType} onChange={(event) => setFacilityType(event.target.value)} className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required>
                  {facilityTypes.map((type) => <option key={type} value={type}>{type}</option>)}
                </select>
                <input value={facilityLat} onChange={(event) => setFacilityLat(event.target.value)} placeholder="خط العرض" type="number" step="any" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
                <input value={facilityLng} onChange={(event) => setFacilityLng(event.target.value)} placeholder="خط الطول" type="number" step="any" className="px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" required />
              </div>
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

      {tab === "contacts" && (
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
