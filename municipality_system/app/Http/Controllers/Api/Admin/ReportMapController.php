<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Report;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ReportMapController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $reports = Report::with(['citizen', 'category', 'department', 'area', 'images'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('severity'), fn ($query) => $query->where('severity', $request->string('severity')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('report_number', 'like', $search)
                        ->orWhere('title', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->whereNotNull('latitude')
            ->whereNotNull('longitude')
            ->latest()
            ->paginate($request->integer('per_page', 200));

        return response()->json($reports);
    }

    public function show(Report $report): JsonResponse
    {
        return response()->json([
            'report' => $report->load([
                'citizen',
                'category.department',
                'department',
                'area',
                'images.uploader',
                'comments.user',
                'logs.actor',
                'rating',
            ]),
        ]);
    }
}
