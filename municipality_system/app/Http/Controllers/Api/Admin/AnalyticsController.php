<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\Rating;
use App\Models\Report;
use Carbon\CarbonPeriod;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AnalyticsController extends Controller
{
    public function reports(Request $request): JsonResponse|\Symfony\Component\HttpFoundation\StreamedResponse
    {
        $query = $this->reportDateFilter(Report::query(), $request);
        $reportIds = (clone $query)->pluck('id');

        $payload = [
            'total_reports' => (clone $query)->count(),
            'open_reports' => (clone $query)->whereNotIn('status', ['closed', 'resolved'])->count(),
            'closed_reports' => (clone $query)->where('status', 'closed')->count(),
            'average_rating' => round((float) Rating::whereIn('report_id', $reportIds)->avg('stars'), 2),
            'by_status' => (clone $query)
                ->select('status', DB::raw('count(*) as total'))
                ->groupBy('status')
                ->orderBy('status')
                ->get(),
            'by_category' => (clone $query)
                ->join('categories', 'reports.category_id', '=', 'categories.id')
                ->select('categories.category_name', DB::raw('count(*) as total'))
                ->groupBy('categories.id', 'categories.category_name')
                ->orderByDesc('total')
                ->get(),
        ];

        if ($request->string('format')->toString() === 'csv') {
            return $this->csv('reports-summary.csv', [
                ['metric', 'value'],
                ['total_reports', $payload['total_reports']],
                ['open_reports', $payload['open_reports']],
                ['closed_reports', $payload['closed_reports']],
                ['average_rating', $payload['average_rating']],
            ]);
        }

        return response()->json($payload);
    }

    public function departments(Request $request): JsonResponse|\Symfony\Component\HttpFoundation\StreamedResponse
    {
        $allReportsQuery = $this->reportDateFilter(Report::query(), $request);
        $allReportIds = (clone $allReportsQuery)->pluck('id');
        $totalCityReports = (clone $allReportsQuery)->count();
        $closedCityReports = (clone $allReportsQuery)->where('status', 'closed')->count();

        $departments = Department::query()
            ->orderBy('dept_name')
            ->get()
            ->map(function (Department $department) use ($request) {
                $query = $this->reportDateFilter($department->reports(), $request);
                $reports = (clone $query)->with('logs')->get();
                $total = $reports->count();
                $closed = $reports->where('status', 'closed')->count();
                $open = (clone $query)->whereNotIn('status', ['closed', 'resolved'])->count();
                $avgResponse = $this->averageFirstResponseSeconds($reports);

                return [
                    'id' => $department->id,
                    'dept_name' => $department->dept_name,
                    'reports_count' => $total,
                    'closed_reports_count' => $closed,
                    'open_reports_count' => $open,
                    'completion_rate' => $total > 0 ? round(($closed / $total) * 100, 2) : 0,
                    'average_first_response_seconds' => $avgResponse,
                ];
            })
            ->values();

        $leaderboard = $departments
            ->sort(function (array $a, array $b) {
                if ($a['completion_rate'] !== $b['completion_rate']) {
                    return $b['completion_rate'] <=> $a['completion_rate'];
                }

                $aResponse = $a['average_first_response_seconds'] ?? PHP_INT_MAX;
                $bResponse = $b['average_first_response_seconds'] ?? PHP_INT_MAX;

                return $aResponse <=> $bResponse;
            })
            ->values();

        if ($request->string('format')->toString() === 'csv') {
            return $this->csv('departments-comparison.csv', [
                ['department', 'total_reports', 'closed_reports', 'open_reports', 'completion_rate', 'average_first_response_seconds'],
                ...$departments->map(fn (array $department) => [
                    $department['dept_name'],
                    $department['reports_count'],
                    $department['closed_reports_count'],
                    $department['open_reports_count'],
                    $department['completion_rate'],
                    $department['average_first_response_seconds'],
                ])->all(),
            ]);
        }

        return response()->json([
            'departments' => $departments,
            'bar_chart' => $departments->map(fn (array $department) => [
                'department' => $department['dept_name'],
                'received' => $department['reports_count'],
                'closed' => $department['closed_reports_count'],
            ])->values(),
            'pie_chart' => $departments->map(fn (array $department) => [
                'department' => $department['dept_name'],
                'total' => $department['reports_count'],
                'percentage' => $totalCityReports > 0
                    ? round(($department['reports_count'] / $totalCityReports) * 100, 2)
                    : 0,
            ])->values(),
            'leaderboard' => $leaderboard,
            'summary' => [
                'total_city_reports' => $totalCityReports,
                'closed_city_reports' => $closedCityReports,
                'city_completion_rate' => $totalCityReports > 0 ? round(($closedCityReports / $totalCityReports) * 100, 2) : 0,
                'average_closure_seconds' => $this->averageClosureSeconds((clone $allReportsQuery)->where('status', 'closed')->get()),
                'average_satisfaction' => round((float) Rating::whereIn('report_id', $allReportIds)->avg('stars'), 2),
            ],
        ]);
    }

    public function departmentPerformance(Request $request, Department $department): JsonResponse|\Symfony\Component\HttpFoundation\StreamedResponse
    {
        $query = $this->reportDateFilter($department->reports(), $request);
        $reports = (clone $query)->with('logs')->get();
        $total = $reports->count();
        $closed = $reports->where('status', 'closed')->count();
        $dailyChart = $this->dailyReportChart($reports, $request);

        $payload = [
            'department' => [
                'id' => $department->id,
                'dept_name' => $department->dept_name,
            ],
            'total_reports' => $total,
            'closed_reports' => $closed,
            'open_reports' => $reports->whereNotIn('status', ['closed', 'resolved'])->count(),
            'completion_rate' => $total > 0 ? round(($closed / $total) * 100, 2) : 0,
            'average_first_response_seconds' => $this->averageFirstResponseSeconds($reports),
            'by_status' => $reports
                ->groupBy('status')
                ->map(fn ($items, string $status) => ['status' => $status, 'total' => $items->count()])
                ->values(),
            'chart_daily_reports' => $dailyChart,
        ];

        if ($request->string('format')->toString() === 'csv') {
            return $this->csv('department-performance-'.$department->id.'.csv', [
                ['metric', 'value'],
                ['department', $department->dept_name],
                ['total_reports', $payload['total_reports']],
                ['closed_reports', $payload['closed_reports']],
                ['open_reports', $payload['open_reports']],
                ['completion_rate', $payload['completion_rate']],
                ['average_first_response_seconds', $payload['average_first_response_seconds']],
            ]);
        }

        return response()->json($payload);
    }

    private function reportDateFilter($query, Request $request)
    {
        return $query
            ->when($request->filled('date_from'), fn ($query) => $query->whereDate('created_at', '>=', $request->date('date_from')))
            ->when($request->filled('date_to'), fn ($query) => $query->whereDate('created_at', '<=', $request->date('date_to')));
    }

    private function averageFirstResponseSeconds($reports): ?float
    {
        $seconds = $reports
            ->map(function (Report $report) {
                $firstAction = $report->logs
                    ->whereIn('action', ['opened_for_review', 'transferred', 'status_updated', 'comment_added'])
                    ->sortBy('created_at')
                    ->first();

                return $firstAction && $report->created_at && $firstAction->created_at
                    ? $report->created_at->diffInSeconds($firstAction->created_at)
                    : null;
            })
            ->filter(fn ($value) => $value !== null);

        return $seconds->isNotEmpty() ? round($seconds->avg(), 2) : null;
    }

    private function averageClosureSeconds($reports): ?float
    {
        $seconds = $reports
            ->map(fn (Report $report) => $report->closed_at && $report->created_at
                ? $report->created_at->diffInSeconds($report->closed_at)
                : null)
            ->filter(fn ($value) => $value !== null);

        return $seconds->isNotEmpty() ? round($seconds->avg(), 2) : null;
    }

    private function dailyReportChart($reports, Request $request)
    {
        $oldestReport = $reports->sortBy('created_at')->first();
        $newestReport = $reports->sortByDesc('created_at')->first();
        $dateFrom = $request->filled('date_from')
            ? $request->date('date_from')->toDateString()
            : $oldestReport?->created_at?->toDateString();
        $dateTo = $request->filled('date_to')
            ? $request->date('date_to')->toDateString()
            : $newestReport?->created_at?->toDateString();

        if (! $dateFrom || ! $dateTo) {
            return collect();
        }

        $receivedByDate = $reports->groupBy(fn (Report $report) => $report->created_at->toDateString());
        $closedByDate = $reports
            ->filter(fn (Report $report) => $report->status === 'closed' && $report->closed_at)
            ->groupBy(fn (Report $report) => $report->closed_at->toDateString());

        return collect(CarbonPeriod::create($dateFrom, $dateTo))
            ->map(function ($date) use ($receivedByDate, $closedByDate) {
                $key = $date->toDateString();

                return [
                    'date' => $key,
                    'received' => $receivedByDate->get($key, collect())->count(),
                    'closed' => $closedByDate->get($key, collect())->count(),
                ];
            })
            ->values();
    }

    private function csv(string $filename, array $rows): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        return response()->streamDownload(function () use ($rows) {
            $handle = fopen('php://output', 'w');

            foreach ($rows as $row) {
                fputcsv($handle, $row);
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv',
        ]);
    }
}
