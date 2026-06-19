export interface Report {
  id: string; title: string; description: string; category: string;
  location: { lat: number; lng: number; address?: string; city?: string } | null;
  imageUrl: string | null;
  afterImageUrl: string | null;
  status: string;
  priority?: string;
  slaDeadline: string | null; citizenId: string;
  citizen: { id: string; name: string; phone: string };
  departmentId: string | null;
  department: { id: string; name?: string; dept_name?: string; code?: string } | null;
  assignedToId: string | null;
  assignedTo: { id: string; name: string } | null;
  aiConfidence: number | null; aiReason: string | null; rating: number | null;
  notes: any[]; statusHistory: any[]; _count: { notes: number };
  createdAt: string; updatedAt: string;
}

export interface Suggestion {
  id: string; title: string; description: string;
  citizen: { id: string; name: string };
  department: { id: string; name?: string; dept_name?: string } | null;
  status: string;
  votes: number; _count: { votesRelation: number }; createdAt: string;
}

export interface Department {
  id: string; dept_name?: string; name?: string; description?: string; is_active?: boolean; code?: string; icon?: string;
  account?: { id: string; full_name?: string; name?: string } | null;
  manager?: { id: string; name: string } | null;
  categories_count?: number; reports_count?: number;
  _count?: { reports: number; projects: number };
}

export interface StaffUser {
  id: string; full_name?: string; name?: string; email: string; phone?: string; employee_number?: string;
  role?: { id: string; role_name: string } | "reception" | "department" | "admin" | "citizen";
  role_id?: string; dept_id?: string | null; is_active?: boolean; isActive?: boolean;
  department?: { id: string; dept_name?: string; name?: string } | null;
  managedDepartment?: { id: string; name: string } | null; created_at?: string; createdAt?: string;
}

export interface Role {
  id: string;
  role_name: "admin" | "reception" | "department" | "citizen" | string;
}

export interface EmergencyContact {
  id: string; name: string; number: string; icon: string; description: string | null;
}

export interface Facility {
  id: string; name: string; type: string; lat: number; lng: number; address: string;
}

export interface Project {
  id: string; name: string; description: string; progress: number;
  startDate: string; endDate: string | null;
  department: { id: string; name: string };
  location: { lat: number; lng: number; address?: string } | null;
}

export interface Notification {
  id: string;
  title: string;
  body: string;
  type: string;
  is_read?: boolean;
  isRead?: boolean;
  related_id?: string | number | null;
  related_type?: string | null;
  report?: { id: string; title: string; status: string } | null;
  created_at?: string;
  createdAt?: string;
}

export interface PaginatedResponse<T> {
  data: T[]; pagination: { page: number; limit: number; total: number; totalPages: number };
}

export interface AdminStats {
  totalReports: number;
  reportsByStatus: { status: string; _count: number }[];
  reportsByDept: { departmentId: string | null; _count: number }[];
  totalStaff: number; totalSuggestions: number; totalProjects: number; avgRating: number;
}
