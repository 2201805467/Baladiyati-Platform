<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\CurrentProject;
use App\Models\EmergencyContact;
use App\Models\PublicFacility;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PublicInfoController extends Controller
{
    public function projects(Request $request): JsonResponse
    {
        $projects = CurrentProject::with('area')
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('area_id'), fn ($query) => $query->where('area_id', $request->integer('area_id')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', $search)
                        ->orWhere('description', 'like', $search)
                        ->orWhere('contractor', 'like', $search);
                });
            })
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 15));

        return response()->json($projects);
    }

    public function facilities(Request $request): JsonResponse
    {
        $facilities = PublicFacility::query()
            ->where('is_active', true)
            ->when($request->filled('facility_type'), fn ($query) => $query->where('facility_type', $request->string('facility_type')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', $search)
                        ->orWhere('services', 'like', $search);
                });
            })
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($facilities);
    }

    public function emergencyContacts(Request $request): JsonResponse
    {
        $contacts = EmergencyContact::query()
            ->where('is_active', true)
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('name', 'like', $search)
                        ->orWhere('phone', 'like', $search)
                        ->orWhere('alt_phone', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->orderBy('category')
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($contacts);
    }
}
