<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\SecurityLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SecurityLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $logs = SecurityLog::with('user:id,full_name,email,employee_number,role_id')
            ->when($request->filled('user_id'), fn ($query) => $query->where('user_id', $request->integer('user_id')))
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('action'), fn ($query) => $query->where('action', 'like', '%'.$request->string('action')->toString().'%'))
            ->when($request->filled('date_from'), fn ($query) => $query->whereDate('created_at', '>=', $request->date('date_from')))
            ->when($request->filled('date_to'), fn ($query) => $query->whereDate('created_at', '<=', $request->date('date_to')))
            ->latest('created_at')
            ->paginate($request->integer('per_page', 15));

        return response()->json($logs);
    }
}
