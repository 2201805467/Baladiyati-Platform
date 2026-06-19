import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { api } from "../lib/api-client";

export default function ForgotPasswordPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    setMessage("");
    setError("");
    setLoading(true);
    try {
      const response = await api.post<{ message: string }>("/auth/forgot-password", { email });
      setMessage(response.message || "تم إرسال رمز التحقق إلى البريد الإلكتروني.");
    } catch (err: any) {
      setError(err.message || "حدث خطأ أثناء إرسال رمز التحقق.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4" dir="rtl">
      <div className="bg-slate-900 rounded-2xl p-8 border border-slate-800 w-full max-w-md">
        <h1 className="text-2xl font-bold text-emerald-400 mb-2 text-center">استرجاع كلمة المرور</h1>
        <p className="text-slate-500 text-sm mb-6 text-center">أدخل بريدك الإلكتروني لإرسال رمز التحقق.</p>
        <form onSubmit={handleSubmit} className="space-y-4">
          <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="البريد الإلكتروني" type="email" className="w-full px-4 py-3 bg-slate-800 border border-slate-700 rounded-xl text-sm text-white text-center" required />
          {message && <p className="text-emerald-400 text-sm text-center">{message}</p>}
          {error && <p className="text-red-400 text-sm text-center">{error}</p>}
          <button type="submit" disabled={loading} className="w-full py-3 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 rounded-xl text-sm font-medium">
            {loading ? "جاري الإرسال..." : "إرسال رمز التحقق"}
          </button>
          <button type="button" onClick={() => navigate("/login")} className="w-full py-2 text-slate-500 hover:text-white text-sm">العودة لتسجيل الدخول</button>
        </form>
      </div>
    </div>
  );
}
