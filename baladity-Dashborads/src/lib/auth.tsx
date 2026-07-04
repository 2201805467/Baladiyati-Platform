import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import { api } from "./api-client";

const SESSION_TIMEOUT_MS = 30 * 60 * 1000;

interface User {
  id: number | string;
  full_name?: string;
  name?: string;
  email?: string;
  phone?: string;
  role?: string;
  roleData?: {
    id: number | string;
    role_name: string;
    permissions?: { id?: number | string; permission_name: string }[];
  };
  department?: { id: number | string; dept_name: string };
  dept_id?: number | string | null;
  departmentId?: number | string | null;
}

interface AuthContextType {
  user: User | null; token: string | null; isLoading: boolean;
  login: (email: string, password: string) => Promise<void>; logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const logout = useCallback(() => {
    const currentToken = api.getToken();
    if (currentToken) {
      api.post("/auth/logout", {}).catch(() => {
        // The local session must still end even if the server is unreachable.
      });
    }

    api.setToken(null); setToken(null); setUser(null);
    localStorage.removeItem("token");
  }, []);

  const normalizeUser = (raw: User & { role?: string | { id: number | string; role_name: string }; role_name?: string }): User => {
    const roleData = typeof raw.role === "object" ? raw.role : raw.roleData;
    return {
      ...raw,
      role: raw.role_name || roleData?.role_name || (typeof raw.role === "string" ? raw.role : undefined),
      roleData,
      name: raw.name || raw.full_name || "",
      departmentId: raw.departmentId || raw.dept_id || raw.department?.id || null,
    };
  };

  useEffect(() => {
    const saved = localStorage.getItem("token");
    if (saved) {
      api.setToken(saved);
      setToken(saved);
      api.get<{ user: User }>("/auth/me")
        .then((res) => setUser(normalizeUser(res.user)))
        .catch(() => logout())
        .finally(() => setIsLoading(false));
      return;
    }
    setIsLoading(false);
  }, [logout]);

  // Auto logout on inactivity
  useEffect(() => {
    if (!user) return;
    let timer: ReturnType<typeof setTimeout>;
    const reset = () => { clearTimeout(timer); timer = setTimeout(logout, SESSION_TIMEOUT_MS); };
    const events = ["mousemove", "keydown", "mousedown", "scroll", "touchstart"];
    events.forEach(e => window.addEventListener(e, reset));
    reset();
    return () => { clearTimeout(timer); events.forEach(e => window.removeEventListener(e, reset)); };
  }, [user, logout]);

  const login = async (email: string, password: string) => {
    const res = await api.post<{ access_token: string; token_type: string; user: User }>("/auth/login", {
      login: email,
      password,
      device_name: "baladiyati-dashboard",
    });
    api.setToken(res.access_token);
    setToken(res.access_token);
    setUser(normalizeUser(res.user));
  };

  return (
    <AuthContext.Provider value={{ user, token, isLoading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
