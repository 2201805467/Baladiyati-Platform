<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\PublicFacility;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PublicFacilityController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $facilities = PublicFacility::with('adder:id,full_name')
            ->when($request->filled('facility_type'), fn ($query) => $query->where('facility_type', $request->string('facility_type')))
            ->when($request->has('is_active'), fn ($query) => $query->where('is_active', $request->boolean('is_active')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(fn ($query) => $query
                    ->where('name', 'like', $search)
                    ->orWhere('services', 'like', $search));
            })
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($facilities);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'facility_type' => ['required', 'string', 'max:50'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'working_hours' => ['nullable', 'string', 'max:100'],
            'services' => ['nullable', 'string'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $facility = PublicFacility::create([
            ...$data,
            'added_by' => $request->user()->id,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Public facility created successfully.',
            'facility' => $facility->load('adder'),
        ], 201);
    }

    public function update(Request $request, PublicFacility $facility): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'facility_type' => ['sometimes', 'required', 'string', 'max:50'],
            'latitude' => ['sometimes', 'required', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'required', 'numeric', 'between:-180,180'],
            'working_hours' => ['nullable', 'string', 'max:100'],
            'services' => ['nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $facility->update($data);

        return response()->json([
            'message' => 'Public facility updated successfully.',
            'facility' => $facility->fresh()->load('adder'),
        ]);
    }
}
