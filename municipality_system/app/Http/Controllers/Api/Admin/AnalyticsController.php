<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\Rating;
use App\Models\Report;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AnalyticsController extends Controller
{
    public function reports(): JsonResponse
    {
        return response()->json([
            'total_reports' => Report::count(),
            'open_reports' => Report::whereNotIn('status', ['closed', 'resolved'])->count(),
            'closed_reports' => Report::where('status', 'closed')->count(),
            'average_rating' => round((float) Rating::avg('stars'), 2),
            'by_status' => Report::select('status', DB::raw('count(*) as total'))
                ->groupBy('status')
                ->orderBy('status')
                ->get(),
            'by_category' => Report::join('categories', 'reports.category_id', '=', 'categories.id')
                ->select('categories.category_name', DB::raw('count(*) as total'))
                ->groupBy('categories.id', 'categories.category_name')
                ->orderByDesc('total')
                ->get(),
        ]);
    }

    public function departments(): JsonResponse
    {
        $departments = Department::withCount([
            'reports',
            'reports as closed_reports_count' => fn ($query) => $query->where('status', 'closed'),
            'reports as open_reports_count' => fn ($query) => $query->whereNotIn('status', ['closed', 'resolved']),
        ])
            ->orderBy('dept_name')
            ->get();

        return response()->json([
            'departments' => $departments,
        ]);
    }
}
