import { useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useNavigate } from "react-router-dom";
import html2canvas from "html2canvas";
import jsPDF from "jspdf";
import * as XLSX from "xlsx";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Legend,
  Line,
  LineChart,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { api } from "../lib/api-client";
import { useAuth } from "../lib/auth";

interface DepartmentOption {
  id: string | number;
  dept_name?: string;
  name?: string;
}

interface DepartmentPerformance {
  department: { id: string | number; dept_name: string };
  total_reports: number;
  closed_reports: number;
  open_reports: number;
  completion_rate: number;
  average_first_response_seconds: number | null;
  chart_daily_reports: { date: string; received: number; closed: number }[];
}

interface DepartmentComparisonItem {
  id: string | number;
  dept_name: string;
  reports_count: number;
  closed_reports_count: number;
  open_reports_count: number;
  completion_rate: number;
  average_first_response_seconds: number | null;
}

interface DepartmentComparison {
  departments: DepartmentComparisonItem[];
  bar_chart: { department: string; received: number; closed: number }[];
  pie_chart: { department: string; total: number; percentage: number }[];
  leaderboard: DepartmentComparisonItem[];
  summary: {
    total_city_reports: number;
    closed_city_reports: number;
    city_completion_rate: number;
    average_closure_seconds: number | null;
    average_satisfaction: number;
  };
}

const pieColors = ["#10b981", "#38bdf8", "#f59e0b", "#f43f5e", "#8b5cf6", "#14b8a6", "#eab308"];
const today = new Date().toISOString().slice(0, 10);
const monthAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);

const formatDuration = (seconds?: number | null) => {
  if (seconds === null || seconds === undefined) return "-";
  if (seconds < 60) return `${Math.round(seconds)} ث`;
  if (seconds < 3600) return `${Math.round(seconds / 60)} د`;
  if (seconds < 86400) return `${(seconds / 3600).toFixed(1)} س`;
  return `${(seconds / 86400).toFixed(1)} يوم`;
};

const secondsToHours = (seconds?: number | null) => {
  if (seconds === null || seconds === undefined) return "-";
  return (seconds / 3600).toFixed(2);
};

const departmentName = (department: DepartmentOption) => department.dept_name || department.name || `قسم #${department.id}`;

export default function AnalyticsPage() {
  const { user, isLoading } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState<"single" | "comparison">("comparison");
  const [departments, setDepartments] = useState<DepartmentOption[]>([]);
  const [departmentId, setDepartmentId] = useState<string>("");
  const [dateFrom, setDateFrom] = useState(monthAgo);
  const [dateTo, setDateTo] = useState(today);
  const [performance, setPerformance] = useState<DepartmentPerformance | null>(null);
  const [comparison, setComparison] = useState<DepartmentComparison | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!isLoading && !user) navigate("/login");
  }, [user, isLoading, navigate]);

  useEffect(() => {
    api
      .get<any>("/admin/departments?per_page=100")
      .then((response) => setDepartments(response.departments || response.data || []))
      .catch((error) => console.error("departments", error));
  }, []);

  const query = useMemo(() => {
    const params = new URLSearchParams();
    if (dateFrom) params.set("date_from", dateFrom);
    if (dateTo) params.set("date_to", dateTo);
    return params.toString();
  }, [dateFrom, dateTo]);

  const generateReport = async () => {
    setLoading(true);
    try {
      const comparisonResponse = await api.get<DepartmentComparison>(`/admin/analytics/departments?${query}`);
      setComparison(comparisonResponse);

      if (tab === "single" && departmentId) {
        const performanceResponse = await api.get<DepartmentPerformance>(
          `/admin/analytics/departments/${departmentId}?${query}`,
        );
        setPerformance(performanceResponse);
      } else {
        setPerformance(null);
      }
    } catch (error) {
      console.error("analytics", error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    generateReport();
  }, []);

  const exportPdf = async () => {
    if (tab === "single") {
      if (!performance) return;
      await exportDepartmentPdf(performance, dateFrom, dateTo);
      return;
    }

    if (!comparison) return;
    await exportComparisonPdf(comparison, dateFrom, dateTo);
  };

  const exportExcel = () => {
    if (tab === "single") {
      if (!performance) return;
      exportDepartmentExcel(performance, dateFrom, dateTo);
      return;
    }

    if (!comparison) return;
    exportComparisonExcel(comparison, dateFrom, dateTo);
  };

  if (isLoading) return <div className="animate-pulse text-emerald-400">جاري التحميل...</div>;

  return (
    <div className="space-y-6 p-6" dir="rtl">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold text-emerald-400">لوحة قيادة الأداء</h1>
          <p className="text-sm text-slate-500 mt-1">تقارير أداء الأقسام حسب الفترة الزمنية.</p>
        </div>
        <div className="flex gap-2">
          <button onClick={() => setTab("single")} className={`px-4 py-2 rounded-lg text-sm ${tab === "single" ? "bg-emerald-600" : "bg-slate-800 text-slate-400"}`}>أداء قسم</button>
          <button onClick={() => setTab("comparison")} className={`px-4 py-2 rounded-lg text-sm ${tab === "comparison" ? "bg-emerald-600" : "bg-slate-800 text-slate-400"}`}>مقارنة الأقسام</button>
        </div>
      </div>

      <section className="bg-slate-900 rounded-xl p-4 border border-slate-800">
        <div className={`grid grid-cols-1 gap-3 ${tab === "single" ? "md:grid-cols-5" : "md:grid-cols-4"}`}>
          {tab === "single" && (
            <label className="space-y-1">
              <span className="text-xs text-slate-400">القسم</span>
              <select value={departmentId} onChange={(event) => setDepartmentId(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm">
                <option value="">اختر القسم</option>
                {departments.map((department) => (
                  <option key={department.id} value={department.id}>{departmentName(department)}</option>
                ))}
              </select>
            </label>
          )}
          <label className="space-y-1">
            <span className="text-xs text-slate-400">تاريخ البدء</span>
            <input type="date" value={dateFrom} onChange={(event) => setDateFrom(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
          </label>
          <label className="space-y-1">
            <span className="text-xs text-slate-400">تاريخ الانتهاء</span>
            <input type="date" value={dateTo} onChange={(event) => setDateTo(event.target.value)} className="w-full px-3 py-2 bg-slate-800 border border-slate-700 rounded-lg text-sm" />
          </label>
          <button onClick={generateReport} disabled={loading} className="md:mt-5 px-4 py-2 bg-emerald-600 disabled:opacity-50 rounded-lg text-sm">توليد التقرير</button>
          <div className="md:mt-5 flex gap-2">
            <button onClick={exportPdf} disabled={loading} className="flex-1 px-3 py-2 bg-slate-800 disabled:opacity-50 rounded-lg text-sm">PDF</button>
            <button onClick={exportExcel} disabled={loading} className="flex-1 px-3 py-2 bg-slate-800 disabled:opacity-50 rounded-lg text-sm">Excel</button>
          </div>
        </div>
      </section>

      {loading && <div className="bg-slate-900 rounded-xl p-6 border border-slate-800 text-slate-400">جاري توليد التقرير...</div>}

      {tab === "single" ? <SingleDepartmentView performance={performance} /> : <ComparisonView comparison={comparison} />}
    </div>
  );
}

async function exportDepartmentPdf(performance: DepartmentPerformance, dateFrom: string, dateTo: string) {
  const html = `
    ${reportHeader(`تقرير أداء القسم - ${escapeHtml(performance.department.dept_name)}`, dateFrom, dateTo)}
    ${kpiCards([
      ["إجمالي البلاغات", String(performance.total_reports)],
      ["معدل الإنجاز", `${performance.completion_rate}%`],
      ["متوسط الاستجابة", `${secondsToHours(performance.average_first_response_seconds)} ساعة`],
    ])}
    <section class="report-section">
      <h2>الرسم البياني: تدفق البلاغات يومياً</h2>
      ${lineChartHtml(performance.chart_daily_reports)}
    </section>
    <section class="report-section">
      <h2>جدول تفصيلي يومي</h2>
      ${tableHtml(
        ["التاريخ", "بلاغات مستلمة", "بلاغات محلولة"],
        performance.chart_daily_reports.map((row) => [row.date, row.received, row.closed]),
      )}
    </section>
    ${reportFooter()}
  `;

  await renderReportPdf(html, `department-performance-${performance.department.id}.pdf`);
}

async function exportComparisonPdf(comparison: DepartmentComparison, dateFrom: string, dateTo: string) {
  const html = `
    ${reportHeader("تقرير الأداء العام لجميع الأقسام", dateFrom, dateTo)}
    ${kpiCards([
      ["إجمالي بلاغات المدينة", String(comparison.summary.total_city_reports)],
      ["متوسط الإغلاق العام", `${secondsToHours(comparison.summary.average_closure_seconds)} ساعة`],
      ["نسبة الرضا العامة", comparison.summary.average_satisfaction ? `${comparison.summary.average_satisfaction}/5` : "-"],
    ])}
    <section class="report-section">
      <h2>Bar Chart: مقارنة الأقسام</h2>
      ${barChartHtml(comparison.bar_chart)}
    </section>
    <section class="report-section">
      <h2>Pie Chart: توزيع البلاغات على الأقسام</h2>
      ${pieChartHtml(comparison.pie_chart)}
    </section>
    <section class="report-section">
      <h2>جدول الترتيب (Leaderboard)</h2>
      ${tableHtml(
        ["#", "القسم", "معدل الإنجاز", "سرعة الاستجابة"],
        comparison.leaderboard.map((department, index) => [
          index + 1,
          department.dept_name,
          `${department.completion_rate}%`,
          formatDuration(department.average_first_response_seconds),
        ]),
      )}
    </section>
    ${reportFooter()}
  `;

  await renderReportPdf(html, "departments-comparison.pdf");
}

function exportDepartmentExcel(performance: DepartmentPerformance, dateFrom: string, dateTo: string) {
  const rows = [
    ["اسم القسم", performance.department.dept_name],
    ["الفترة من", dateFrom],
    ["الفترة إلى", dateTo],
    ["تاريخ التصدير", today],
    [],
    ["إجمالي البلاغات المستلمة", performance.total_reports],
    ["عدد البلاغات المغلقة", performance.closed_reports],
    ["معدل الإنجاز %", performance.completion_rate],
    ["متوسط وقت الاستجابة (ساعة)", secondsToHours(performance.average_first_response_seconds)],
    [],
    ["التاريخ", "بلاغات مستلمة", "بلاغات محلولة"],
    ...performance.chart_daily_reports.map((row) => [row.date, row.received, row.closed]),
  ];

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, XLSX.utils.aoa_to_sheet(rows), "تقرير القسم");
  XLSX.writeFile(workbook, `department-performance-${performance.department.id}.xlsx`);
}

function exportComparisonExcel(comparison: DepartmentComparison, dateFrom: string, dateTo: string) {
  const workbook = XLSX.utils.book_new();

  XLSX.utils.book_append_sheet(
    workbook,
    XLSX.utils.aoa_to_sheet([
      ["المؤشر", "القيمة"],
      ["الفترة من", dateFrom],
      ["الفترة إلى", dateTo],
      ["إجمالي بلاغات المدينة", comparison.summary.total_city_reports],
      ["متوسط الإغلاق العام (ساعة)", secondsToHours(comparison.summary.average_closure_seconds)],
      ["نسبة الرضا العامة", comparison.summary.average_satisfaction ? `${comparison.summary.average_satisfaction}/5` : "-"],
    ]),
    "ملخص عام",
  );

  XLSX.utils.book_append_sheet(
    workbook,
    XLSX.utils.aoa_to_sheet([
      ["القسم", "بلاغات مستلمة", "بلاغات مغلقة", "معدل الإنجاز %", "متوسط وقت الاستجابة"],
      ...comparison.departments.map((department) => [
        department.dept_name,
        department.reports_count,
        department.closed_reports_count,
        `${department.completion_rate}%`,
        `${secondsToHours(department.average_first_response_seconds)} ساعة`,
      ]),
    ]),
    "مقارنة الأقسام",
  );

  XLSX.utils.book_append_sheet(
    workbook,
    XLSX.utils.aoa_to_sheet([
      ["الترتيب", "القسم", "معدل الإنجاز", "الترتيب حسب السرعة"],
      ...comparison.leaderboard.map((department, index) => [
        index + 1,
        department.dept_name,
        `${department.completion_rate}%`,
        index + 1,
      ]),
    ]),
    "Leaderboard",
  );

  XLSX.writeFile(workbook, "departments-comparison.xlsx");
}

async function renderReportPdf(html: string, filename: string) {
  const element = document.createElement("div");
  element.dir = "rtl";
  element.innerHTML = `<div class="baladiyati-report">${reportStyles()}${html}</div>`;
  element.style.position = "fixed";
  element.style.left = "-10000px";
  element.style.top = "0";
  element.style.width = "794px";
  element.style.background = "#ffffff";
  document.body.appendChild(element);

  try {
    const canvas = await html2canvas(element, {
      scale: 2,
      backgroundColor: "#ffffff",
      useCORS: true,
    });
    const pdf = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
    const imgData = canvas.toDataURL("image/png");
    const imgWidth = 210;
    const pageHeight = 297;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;
    let heightLeft = imgHeight;
    let position = 0;

    pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
    heightLeft -= pageHeight;

    while (heightLeft > 0) {
      position -= pageHeight;
      pdf.addPage();
      pdf.addImage(imgData, "PNG", 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;
    }

    pdf.save(filename);
  } finally {
    element.remove();
  }
}

function reportHeader(title: string, dateFrom: string, dateTo: string) {
  return `
    <header class="report-header">
      <div class="system-name">نظام بلديتي</div>
      <h1>${title}</h1>
      <p>الفترة: من ${escapeHtml(dateFrom)} إلى ${escapeHtml(dateTo)}</p>
      <p>تاريخ إصدار التقرير: ${today}</p>
    </header>
  `;
}

function kpiCards(cards: [string, string][]) {
  return `
    <section class="kpi-grid">
      ${cards.map(([label, value]) => `
        <div class="kpi-card">
          <span>${escapeHtml(label)}</span>
          <strong>${escapeHtml(value)}</strong>
        </div>
      `).join("")}
    </section>
  `;
}

function tableHtml(headers: string[], rows: Array<Array<string | number>>) {
  return `
    <table class="report-table">
      <thead>
        <tr>${headers.map((header) => `<th>${escapeHtml(header)}</th>`).join("")}</tr>
      </thead>
      <tbody>
        ${rows.map((row) => `<tr>${row.map((cell) => `<td>${escapeHtml(String(cell))}</td>`).join("")}</tr>`).join("")}
      </tbody>
    </table>
  `;
}

function lineChartHtml(rows: DepartmentPerformance["chart_daily_reports"]) {
  const maxValue = Math.max(1, ...rows.flatMap((row) => [row.received, row.closed]));
  const points = rows.length > 1 ? rows : [{ date: "", received: 0, closed: 0 }, ...rows];
  const width = 640;
  const height = 180;
  const padding = 24;
  const seriesPoints = (key: "received" | "closed") =>
    points
      .map((row, index) => {
        const x = padding + (index / Math.max(1, points.length - 1)) * (width - padding * 2);
        const y = height - padding - (row[key] / maxValue) * (height - padding * 2);
        return `${x},${y}`;
      })
      .join(" ");

  return `
    <svg class="chart-box" viewBox="0 0 ${width} ${height}">
      <rect x="1" y="1" width="${width - 2}" height="${height - 2}" fill="#ffffff" stroke="#cbd5e1" />
      <polyline points="${seriesPoints("received")}" fill="none" stroke="#38bdf8" stroke-width="4" />
      <polyline points="${seriesPoints("closed")}" fill="none" stroke="#10b981" stroke-width="4" />
    </svg>
    <div class="legend"><span><i class="blue"></i> مستلمة</span><span><i class="green"></i> محلولة</span></div>
  `;
}

function barChartHtml(rows: DepartmentComparison["bar_chart"]) {
  const maxValue = Math.max(1, ...rows.flatMap((row) => [row.received, row.closed]));
  return `
    <div class="bar-chart">
      ${rows.map((row) => `
        <div class="bar-group">
          <div class="bars">
            <span class="bar received" style="height:${Math.max(4, (row.received / maxValue) * 150)}px"></span>
            <span class="bar closed" style="height:${Math.max(4, (row.closed / maxValue) * 150)}px"></span>
          </div>
          <small>${escapeHtml(row.department)}</small>
        </div>
      `).join("")}
    </div>
    <div class="legend"><span><i class="blue"></i> مستلمة</span><span><i class="green"></i> مغلقة</span></div>
  `;
}

function pieChartHtml(rows: DepartmentComparison["pie_chart"]) {
  const total = rows.reduce((sum, row) => sum + row.total, 0);
  let currentAngle = -90;
  const slices = total > 0
    ? rows.map((row, index) => {
        const angle = (row.total / total) * 360;
        const path = describePieSlice(100, 100, 78, currentAngle, currentAngle + angle);
        currentAngle += angle;
        return `<path d="${path}" fill="${pieColors[index % pieColors.length]}" stroke="#ffffff" stroke-width="2"></path>`;
      }).join("")
    : `<circle cx="100" cy="100" r="78" fill="#e2e8f0"></circle>`;

  return `
    <div class="pie-wrap">
      <svg class="pie-svg" viewBox="0 0 200 200" aria-label="Pie Chart">
        ${slices}
      </svg>
      <div class="pie-list">
        ${rows.map((row, index) => `
          <div><i style="background:${pieColors[index % pieColors.length]}"></i>${escapeHtml(row.department)}: ${row.total} (${row.percentage}%)</div>
        `).join("")}
      </div>
    </div>
  `;
}

function describePieSlice(cx: number, cy: number, radius: number, startAngle: number, endAngle: number) {
  if (endAngle - startAngle >= 359.99) {
    return [
      `M ${cx} ${cy}`,
      `m ${-radius} 0`,
      `a ${radius} ${radius} 0 1 0 ${radius * 2} 0`,
      `a ${radius} ${radius} 0 1 0 ${-radius * 2} 0`,
      "Z",
    ].join(" ");
  }

  const start = polarToCartesian(cx, cy, radius, endAngle);
  const end = polarToCartesian(cx, cy, radius, startAngle);
  const largeArcFlag = endAngle - startAngle <= 180 ? "0" : "1";

  return [
    `M ${cx} ${cy}`,
    `L ${start.x} ${start.y}`,
    `A ${radius} ${radius} 0 ${largeArcFlag} 0 ${end.x} ${end.y}`,
    "Z",
  ].join(" ");
}

function polarToCartesian(cx: number, cy: number, radius: number, angleInDegrees: number) {
  const angleInRadians = (angleInDegrees * Math.PI) / 180;
  return {
    x: cx + radius * Math.cos(angleInRadians),
    y: cy + radius * Math.sin(angleInRadians),
  };
}

function reportFooter() {
  return `<footer class="report-footer">نظام بلديتي - صفحة التقرير</footer>`;
}

function reportStyles() {
  return `
    <style>
      .baladiyati-report{box-sizing:border-box;width:794px;min-height:1123px;padding:36px;font-family:Tahoma,Arial,sans-serif;color:#0f172a;background:#fff;direction:rtl}
      .report-header{background:#0f172a;color:white;text-align:center;border-radius:10px;padding:20px 16px;margin-bottom:22px}
      .system-name{font-size:20px;font-weight:800;margin-bottom:8px}
      .report-header h1{font-size:24px;line-height:1.5;margin:0 0 8px}
      .report-header p{font-size:14px;margin:4px 0;color:#dbeafe}
      .kpi-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:22px}
      .kpi-card{background:#f8fafc;border:1px solid #dbe3ee;border-radius:8px;padding:16px;text-align:center}
      .kpi-card span{display:block;color:#475569;font-size:14px;margin-bottom:10px}
      .kpi-card strong{display:block;color:#047857;font-size:26px}
      .report-section{border-top:1px solid #e2e8f0;padding-top:18px;margin-top:18px}
      .report-section h2{font-size:18px;margin:0 0 14px;color:#0f172a}
      .chart-box{width:100%;height:220px}
      .legend{display:flex;gap:18px;justify-content:center;margin-top:8px;color:#475569;font-size:13px}
      .legend i,.pie-list i{display:inline-block;width:11px;height:11px;border-radius:3px;margin-left:6px;vertical-align:middle}
      .legend .blue{background:#38bdf8}.legend .green{background:#10b981}
      .bar-chart{height:210px;border:1px solid #cbd5e1;border-radius:8px;padding:16px;display:flex;align-items:flex-end;gap:12px;justify-content:space-around}
      .bar-group{flex:1;min-width:46px;text-align:center}
      .bars{height:160px;display:flex;align-items:flex-end;justify-content:center;gap:4px}
      .bar{width:16px;border-radius:5px 5px 0 0;display:block}.bar.received{background:#38bdf8}.bar.closed{background:#10b981}
      .bar-group small{display:block;margin-top:8px;font-size:11px;color:#475569;word-break:break-word}
      .pie-wrap{display:flex;align-items:center;gap:28px;border:1px solid #cbd5e1;border-radius:8px;padding:18px}
      .pie-svg{width:170px;height:170px;flex:0 0 170px}
      .pie-list{display:grid;gap:8px;font-size:13px;color:#334155}
      .report-table{width:100%;border-collapse:collapse;font-size:13px}
      .report-table th{background:#10b981;color:white}
      .report-table th,.report-table td{border:1px solid #cbd5e1;padding:9px;text-align:center}
      .report-table tr:nth-child(even) td{background:#f8fafc}
      .report-footer{border-top:1px solid #e2e8f0;margin-top:24px;padding-top:12px;text-align:center;color:#64748b;font-size:12px}
    </style>
  `;
}

function escapeHtml(value: string) {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function SingleDepartmentView({ performance }: { performance: DepartmentPerformance | null }) {
  if (!performance) {
    return <div className="bg-slate-900 rounded-xl p-6 border border-slate-800 text-slate-500">اختر قسماً محدداً أو اضغط توليد التقرير.</div>;
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Metric title="إجمالي البلاغات المستلمة" value={performance.total_reports} color="text-emerald-400" />
        <Metric title="البلاغات المغلقة" value={performance.closed_reports} color="text-blue-400" />
        <Metric title="معدل الإنجاز" value={`${performance.completion_rate}%`} color="text-amber-400" />
        <Metric title="متوسط وقت الاستجابة" value={formatDuration(performance.average_first_response_seconds)} color="text-cyan-400" />
      </div>

      <ChartCard title={`البلاغات اليومية - ${performance.department.dept_name}`}>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={performance.chart_daily_reports}>
            <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
            <XAxis dataKey="date" stroke="#94a3b8" />
            <YAxis stroke="#94a3b8" allowDecimals={false} />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="received" name="مستلمة" stroke="#38bdf8" strokeWidth={2} />
            <Line type="monotone" dataKey="closed" name="محلولة" stroke="#10b981" strokeWidth={2} />
          </LineChart>
        </ResponsiveContainer>
      </ChartCard>
    </div>
  );
}

function ComparisonView({ comparison, compact = false }: { comparison: DepartmentComparison | null; compact?: boolean }) {
  if (!comparison) {
    return <div className="bg-slate-900 rounded-xl p-6 border border-slate-800 text-slate-500">اضغط توليد التقرير لعرض المقارنة.</div>;
  }

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Metric title="إجمالي بلاغات المدينة" value={comparison.summary.total_city_reports} color="text-emerald-400" />
        <Metric title="مغلق" value={comparison.summary.closed_city_reports} color="text-blue-400" />
        <Metric title="متوسط الإغلاق العام" value={formatDuration(comparison.summary.average_closure_seconds)} color="text-cyan-400" />
        <Metric title="نسبة الرضا العامة" value={comparison.summary.average_satisfaction ? `${comparison.summary.average_satisfaction}/5` : "-"} color="text-amber-400" />
      </div>

      {!compact && (
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
          <ChartCard title="مقارنة البلاغات حسب القسم">
            <ResponsiveContainer width="100%" height={320}>
              <BarChart data={comparison.bar_chart}>
                <CartesianGrid strokeDasharray="3 3" stroke="#334155" />
                <XAxis dataKey="department" stroke="#94a3b8" />
                <YAxis stroke="#94a3b8" allowDecimals={false} />
                <Tooltip />
                <Legend />
                <Bar dataKey="received" name="مستلمة" fill="#38bdf8" />
                <Bar dataKey="closed" name="مغلقة" fill="#10b981" />
              </BarChart>
            </ResponsiveContainer>
          </ChartCard>

          <ChartCard title="توزيع البلاغات على الأقسام">
            <ResponsiveContainer width="100%" height={320}>
              <PieChart>
                <Pie data={comparison.pie_chart} dataKey="total" nameKey="department" label>
                  {comparison.pie_chart.map((_, index) => (
                    <Cell key={index} fill={pieColors[index % pieColors.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </ChartCard>
        </div>
      )}

      <section className="bg-slate-900 rounded-xl p-4 border border-slate-800">
        <h2 className="font-bold mb-4">Leaderboard الأقسام</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="text-slate-400">
              <tr className="border-b border-slate-800">
                <th className="p-3 text-right">القسم</th>
                <th className="p-3">مستلمة</th>
                <th className="p-3">مغلقة</th>
                <th className="p-3">معدل الإنجاز</th>
                <th className="p-3">متوسط الاستجابة</th>
              </tr>
            </thead>
            <tbody>
              {comparison.leaderboard.map((department) => (
                <tr key={department.id} className="border-b border-slate-800/60">
                  <td className="p-3 font-medium">{department.dept_name}</td>
                  <td className="p-3 text-center">{department.reports_count}</td>
                  <td className="p-3 text-center">{department.closed_reports_count}</td>
                  <td className="p-3 text-center text-emerald-400">{department.completion_rate}%</td>
                  <td className="p-3 text-center">{formatDuration(department.average_first_response_seconds)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

function Metric({ title, value, color }: { title: string; value: string | number; color: string }) {
  return (
    <div className="bg-slate-900 rounded-xl p-4 border border-slate-800">
      <div className={`text-3xl font-bold ${color}`}>{value}</div>
      <div className="text-sm text-slate-500 mt-1">{title}</div>
    </div>
  );
}

function ChartCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="bg-slate-900 rounded-xl p-4 border border-slate-800">
      <h2 className="font-bold mb-4">{title}</h2>
      {children}
    </section>
  );
}
