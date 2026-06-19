import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../lib/auth";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(""); setLoading(true);
    try {
      await login(email, password);
      navigate("/");
    } catch (err: any) {
      setError(err.message || "فشل تسجيل الدخول");
    } finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4" dir="rtl">
      <div className="w-full max-w-md bg-slate-900 rounded-2xl p-8 border border-slate-800">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-emerald-400 mb-2">منصة بلديتي</h1>
          <p className="text-slate-400 text-sm">لوحة الإدارة</p>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-slate-300 mb-1">البريد الإلكتروني</label>
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)}
              className="w-full px-4 py-2.5 bg-slate-800 border border-slate-700 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
              placeholder="admin@baladiyati.ly" required />
          </div>
          <div>
            <label className="block text-sm text-slate-300 mb-1">كلمة المرور</label>
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
              className="w-full px-4 py-2.5 bg-slate-800 border border-slate-700 rounded-lg text-white placeholder-slate-500 focus:outline-none focus:border-emerald-500"
              placeholder="••••••" required />
          </div>
          {error && <p className="text-red-400 text-sm">{error}</p>}
          <button type="submit" disabled={loading}
            className="w-full py-2.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-lg font-medium transition-colors">
            {loading ? "جاري تسجيل الدخول..." : "تسجيل الدخول"}
          </button>
        </form>
        <div className="mt-4 text-center">
          <button onClick={() => navigate("/forgot-password")} className="text-sm text-emerald-400 hover:text-emerald-300 transition-colors">نسيت كلمة المرور؟</button>
        </div>
        <div className="mt-6 text-xs text-slate-500 text-center space-y-1">
          <p>حسابات تجريبية:</p>
          <p>admin@baladiyati.ly / admin123</p>
          <p>reception@baladiyati.ly / admin123</p>
          <p>department@baladiyati.ly / admin123</p>
        </div>
      </div>
    </div>
  );
}
