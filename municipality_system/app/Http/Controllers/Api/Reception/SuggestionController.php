<?php

namespace App\Http\Controllers\Api\Reception;

use App\Http\Controllers\Controller;
use App\Models\Suggestion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SuggestionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $suggestions = Suggestion::with(['citizen:id,full_name', 'reviewer:id,full_name'])
            ->withCount([
                'votes as support_votes_count' => fn ($query) => $query->where('vote_type', 'support'),
                'votes as oppose_votes_count' => fn ($query) => $query->where('vote_type', 'oppose'),
            ])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('title', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($suggestions);
    }

    public function accept(Request $request, Suggestion $suggestion): JsonResponse
    {
        $suggestion->update([
            'status' => 'accepted',
            'rejection_reason' => null,
            'reviewed_by' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Suggestion accepted successfully.',
            'suggestion' => $suggestion->fresh()->load(['citizen', 'reviewer']),
        ]);
    }

    public function reject(Request $request, Suggestion $suggestion): JsonResponse
    {
        $data = $request->validate([
            'rejection_reason' => ['required', 'string', 'max:2000'],
        ]);

        $suggestion->update([
            'status' => 'rejected',
            'rejection_reason' => $data['rejection_reason'],
            'reviewed_by' => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'Suggestion rejected successfully.',
            'suggestion' => $suggestion->fresh()->load(['citizen', 'reviewer']),
        ]);
    }
}
