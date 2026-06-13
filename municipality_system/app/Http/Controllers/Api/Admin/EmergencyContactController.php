<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\EmergencyContact;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class EmergencyContactController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $contacts = EmergencyContact::with('adder:id,full_name')
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->has('is_active'), fn ($query) => $query->where('is_active', $request->boolean('is_active')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(fn ($query) => $query
                    ->where('name', 'like', $search)
                    ->orWhere('phone', 'like', $search)
                    ->orWhere('alt_phone', 'like', $search)
                    ->orWhere('description', 'like', $search));
            })
            ->orderBy('category')
            ->orderBy('name')
            ->paginate($request->integer('per_page', 15));

        return response()->json($contacts);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:100'],
            'phone' => ['required', 'string', 'max:20'],
            'alt_phone' => ['nullable', 'string', 'max:20'],
            'category' => ['required', 'string', 'max:50'],
            'description' => ['nullable', 'string'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $contact = EmergencyContact::create([
            ...$data,
            'added_by' => $request->user()->id,
            'is_active' => $data['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Emergency contact created successfully.',
            'contact' => $contact->load('adder'),
        ], 201);
    }

    public function update(Request $request, EmergencyContact $emergencyContact): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:100'],
            'phone' => ['sometimes', 'required', 'string', 'max:20'],
            'alt_phone' => ['nullable', 'string', 'max:20'],
            'category' => ['sometimes', 'required', 'string', 'max:50'],
            'description' => ['nullable', 'string'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $emergencyContact->update($data);

        return response()->json([
            'message' => 'Emergency contact updated successfully.',
            'contact' => $emergencyContact->fresh()->load('adder'),
        ]);
    }
}
